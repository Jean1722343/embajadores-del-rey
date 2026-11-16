import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/asistencia.dart';
import '../core/caja.dart';
import '../models/modelos.dart';

/// Datos ya calculados de un reporte de asistencia.
class Reporte {
  Reporte({
    required this.capitulo,
    required this.titulo,
    required this.desde,
    required this.hasta,
    required this.alumnos,
    required this.resumenes,
    required this.listas,
  });

  final String capitulo;

  /// Nombre del grupo o "Todos los grupos".
  final String titulo;
  final DateTime desde;
  final DateTime hasta;
  final List<Alumno> alumnos;
  final Map<String, ResumenAsistencia> resumenes;
  final List<Lista> listas;

  ResumenAsistencia de(Alumno a) => resumenes[a.id] ?? ResumenAsistencia.vacio;

  /// Días con pase de lista, en orden.
  List<DateTime> get dias {
    final ids = alumnos.map((a) => a.id).toSet();
    final dias = <DateTime>{};
    for (final l in listas) {
      if (l.registros.keys.any(ids.contains)) {
        dias.add(DateTime(l.fecha.year, l.fecha.month, l.fecha.day));
      }
    }
    return dias.toList()..sort();
  }

  /// Promedio de los porcentajes de quienes ya tienen reuniones.
  double? get promedio {
    final p = alumnos.map((a) => de(a).porcentaje).nonNulls.toList();
    return p.isEmpty ? null : p.reduce((a, b) => a + b) / p.length;
  }

  /// Si el muchacho estuvo presente ese día; null si no se le pasó lista.
  bool? presente(Alumno a, DateTime dia) {
    bool? r;
    for (final l in listas) {
      if (l.fecha.year == dia.year &&
          l.fecha.month == dia.month &&
          l.fecha.day == dia.day) {
        final reg = l.registros[a.id];
        if (reg != null) r = (r ?? false) || reg.presente;
      }
    }
    return r;
  }
}

final _f = DateFormat('d MMM yyyy', 'es');
final _dia = DateFormat('d/MM', 'es');

String _nombreArchivo(Reporte r, String extension) =>
    'asistencia_${DateFormat('yyyyMMdd').format(r.desde)}_'
    '${DateFormat('yyyyMMdd').format(r.hasta)}.$extension';

String _pct(double? p) => p == null ? '-' : '${p.round()} %';

Future<Uint8List> generarPdf(Reporte r) async {
  final doc = pw.Document();
  const azul = PdfColor.fromInt(0xFF12234F);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${c.pageNumber} de ${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (c) => [
        pw.Text(
          'Embajadores del Rey',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: azul,
          ),
        ),
        pw.Text(
          'Capítulo ${r.capitulo}',
          style: const pw.TextStyle(fontSize: 13),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Lista de asistencia: ${r.titulo}\n'
          'Del ${_f.format(r.desde)} al ${_f.format(r.hasta)} - '
          '${r.dias.length} reuniones - promedio ${_pct(r.promedio)}',
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: azul),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: {for (var i = 2; i <= 6; i++) i: pw.Alignment.center},
          headers: const [
            'Nombre',
            'Grado',
            'Asistencias',
            'Faltas',
            '%',
            'Biblia',
            'Ofrenda',
          ],
          data: [
            for (final a in r.alumnos)
              [
                a.nombre,
                a.grado.nombre,
                '${r.de(a).asistencias}',
                '${r.de(a).faltas}',
                _pct(r.de(a).porcentaje),
                '${r.de(a).biblias}',
                '${r.de(a).ofrendas}',
              ],
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> compartirPdf(Reporte r) async => Printing.sharePdf(
  bytes: await generarPdf(r),
  filename: _nombreArchivo(r, 'pdf'),
);

/// Libro con dos hojas: el resumen y el detalle día por día.
List<int> generarExcel(Reporte r) {
  final libro = Excel.createExcel();
  final hojaInicial = libro.getDefaultSheet();

  final resumen = libro['Resumen'];
  resumen.appendRow([TextCellValue('Capítulo ${r.capitulo} - ${r.titulo}')]);
  resumen.appendRow([
    TextCellValue('Del ${_f.format(r.desde)} al ${_f.format(r.hasta)}'),
  ]);
  resumen.appendRow([]);
  resumen.appendRow([
    for (final t in const [
      'Nombre',
      'Grado',
      'Reuniones',
      'Asistencias',
      'Faltas',
      'Porcentaje',
      'Biblia',
      'Ofrenda',
      'Ofrenda en pesos',
      'Faltas seguidas',
      'Tutor',
      'Teléfono',
      'Segundo contacto',
      'Teléfono 2',
      'Domicilio',
    ])
      TextCellValue(t),
  ]);
  for (final a in r.alumnos) {
    final s = r.de(a);
    resumen.appendRow([
      TextCellValue(a.nombre),
      TextCellValue(a.grado.nombre),
      IntCellValue(s.reuniones),
      IntCellValue(s.asistencias),
      IntCellValue(s.faltas),
      s.porcentaje == null
          ? TextCellValue('')
          : DoubleCellValue(double.parse(s.porcentaje!.toStringAsFixed(1))),
      IntCellValue(s.biblias),
      IntCellValue(s.ofrendas),
      DoubleCellValue(s.ofrendaTotal),
      IntCellValue(s.faltasSeguidas),
      TextCellValue(a.tutorNombre),
      TextCellValue(a.tutorTel),
      TextCellValue(a.tutor2Nombre),
      TextCellValue(a.tutor2Tel),
      TextCellValue(a.domicilio),
    ]);
  }

  final dias = r.dias;
  final detalle = libro['Detalle'];
  detalle.appendRow([
    TextCellValue('Nombre'),
    for (final d in dias) TextCellValue(_dia.format(d)),
  ]);
  for (final a in r.alumnos) {
    detalle.appendRow([
      TextCellValue(a.nombre),
      for (final d in dias)
        TextCellValue(switch (r.presente(a, d)) {
          true => 'P',
          false => 'F',
          null => '',
        }),
    ]);
  }

  libro.setDefaultSheet('Resumen');
  if (hojaInicial != null && hojaInicial != 'Resumen') {
    libro.delete(hojaInicial);
  }
  return libro.save()!;
}

Future<void> compartirExcel(Reporte r) async {
  final carpeta = await getTemporaryDirectory();
  final archivo = File('${carpeta.path}/${_nombreArchivo(r, 'xlsx')}');
  await archivo.writeAsBytes(generarExcel(r), flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(archivo.path)],
      subject: 'Asistencia - ${r.capitulo}',
    ),
  );
}

// ------------------------------------------------------------------- Caja

final _pesos = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

String _tipo(Asiento a) => switch (a.tipo) {
  TipoAsiento.ofrenda => 'Ofrenda',
  TipoAsiento.ingreso => 'Ingreso',
  TipoAsiento.egreso => 'Salida',
};

/// Fuentes y escudo para el PDF. En la app se cargan de los recursos; en
/// las pruebas, de los archivos.
class RecursosPdf {
  const RecursosPdf({
    required this.texto,
    required this.negrita,
    required this.titulos,
    required this.escudo,
  });

  final pw.Font texto;
  final pw.Font negrita;
  final pw.Font titulos;
  final pw.MemoryImage escudo;

  static Future<RecursosPdf> cargar() async {
    Future<ByteData> leer(String ruta) => rootBundle.load(ruta);
    return RecursosPdf(
      texto: pw.Font.ttf(await leer('assets/fuentes/Figtree-400.ttf')),
      negrita: pw.Font.ttf(await leer('assets/fuentes/Figtree-700.ttf')),
      titulos: pw.Font.ttf(await leer('assets/fuentes/Bricolage-800.ttf')),
      escudo: pw.MemoryImage(
        (await leer('assets/emblema/escudo_4_embajador.png')).buffer
            .asUint8List(),
      ),
    );
  }
}

const _marino = PdfColor.fromInt(0xFF12234F);
const _oro = PdfColor.fromInt(0xFFF2B705);
const _verde = PdfColor.fromInt(0xFF1B7F45);
const _rojo = PdfColor.fromInt(0xFFC0392B);
const _gris = PdfColor.fromInt(0xFF51597A);
const _nube = PdfColor.fromInt(0xFFEDF0F7);
const _filete = PdfColor.fromInt(0xFFD3D9E8);

/// Reporte de caja hecho solo de tablas: resumen, ofrendas por reunión,
/// otros ingresos, salidas y el libro completo con el saldo corrido.
/// Entradas en verde y salidas en rojo.
Future<Uint8List> generarCajaPdf(
  EstadoCaja caja,
  String capitulo, {
  required RecursosPdf recursos,
  DateTime? generado,
}) async {
  final hoy = generado ?? DateTime.now();
  final normal = pw.TextStyle(font: recursos.texto, fontSize: 9.5);
  final negrita = pw.TextStyle(font: recursos.negrita, fontSize: 9.5);
  final cabecera = negrita.copyWith(color: PdfColors.white, fontSize: 9);
  pw.TextStyle grande(double t, PdfColor color) =>
      pw.TextStyle(font: recursos.titulos, fontSize: t, color: color);

  const borde = pw.BorderSide(color: _filete, width: 0.7);
  const rejilla = pw.TableBorder(
    top: borde,
    bottom: borde,
    left: borde,
    right: borde,
    horizontalInside: borde,
    verticalInside: borde,
  );

  pw.Widget celda(String texto, {pw.TextStyle? estilo, bool derecha = false}) =>
      pw.Container(
        alignment: derecha ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: pw.Text(texto, style: estilo ?? normal),
      );

  String entrada(double m) => '+ ${_pesos.format(m)}';
  String salida(double m) => '- ${_pesos.format(m)}';
  final verde = negrita.copyWith(color: _verde);
  final rojo = negrita.copyWith(color: _rojo);

  /// Una tabla con su título, encabezado que se repite en cada página,
  /// filas alternadas y, si se da, una fila final de total.
  /// [columnas]: (título, ancho, alineada a la derecha).
  List<pw.Widget> tabla(
    String titulo,
    List<(String, pw.TableColumnWidth, bool)> columnas,
    List<List<pw.Widget>> filas, {
    List<pw.Widget>? total,
    String vacia = 'Sin movimientos',
  }) => [
    pw.SizedBox(height: 14),
    pw.Text(titulo, style: grande(12.5, _marino)),
    pw.SizedBox(height: 5),
    pw.Table(
      border: rejilla,
      columnWidths: {for (final (i, c) in columnas.indexed) i: c.$2},
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _marino),
          children: [
            for (final c in columnas)
              celda(c.$1, estilo: cabecera, derecha: c.$3),
          ],
        ),
        if (filas.isEmpty)
          pw.TableRow(
            children: [
              celda(vacia, estilo: normal.copyWith(color: _gris)),
              for (var i = 1; i < columnas.length; i++) celda(''),
            ],
          ),
        for (final (i, f) in filas.indexed)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? _nube : PdfColors.white,
            ),
            children: f,
          ),
        if (total != null)
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE2E7F3),
            ),
            children: total,
          ),
      ],
    ),
  ];

  final entradas = caja.ofrendas + caja.ingresos;
  // Del más antiguo al más reciente, como se lleva un libro.
  final cronologico = caja.asientos.reversed.toList();
  List<Asiento> deTipo(TipoAsiento t) =>
      cronologico.where((a) => a.tipo == t).toList();
  final ofrendas = deTipo(TipoAsiento.ofrenda);
  final ingresos = deTipo(TipoAsiento.ingreso);
  final egresos = deTipo(TipoAsiento.egreso);

  const fecha = pw.FixedColumnWidth(72);
  const monto = pw.FixedColumnWidth(82);

  // Tabla de entradas o salidas registradas a mano.
  List<pw.Widget> tablaMovimientos(
    String titulo,
    List<Asiento> asientos,
    double suma, {
    required bool entra,
    required String vacia,
  }) => tabla(
    titulo,
    [
      ('Fecha', fecha, false),
      (
        entra ? 'Cómo se consiguió' : 'Para qué fue',
        const pw.FlexColumnWidth(3),
        false,
      ),
      ('Registró', const pw.FlexColumnWidth(1.7), false),
      ('Monto', monto, true),
    ],
    [
      for (final a in asientos)
        [
          celda(_f.format(a.fecha)),
          celda(a.concepto),
          celda(a.quien),
          celda(
            entra ? entrada(a.monto) : salida(a.monto),
            estilo: entra ? verde : rojo,
            derecha: true,
          ),
        ],
    ],
    total: [
      celda(''),
      celda('Total', estilo: negrita),
      celda(''),
      celda(
        entra ? entrada(suma) : salida(suma),
        estilo: entra ? verde : rojo,
        derecha: true,
      ),
    ],
    vacia: vacia,
  );

  var corrido = 0.0;
  final doc = pw.Document(title: 'Reporte de caja - $capitulo');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 34),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Embajadores del Rey · Capítulo $capitulo',
            style: normal.copyWith(fontSize: 8.5, color: _gris),
          ),
          pw.Text(
            'Página ${c.pageNumber} de ${c.pagesCount}',
            style: normal.copyWith(fontSize: 8.5, color: _gris),
          ),
        ],
      ),
      build: (c) => [
        // Membrete: el escudo, el título y la fecha, sobre un filete de oro.
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _oro, width: 3)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 44,
                height: 44,
                child: pw.Image(recursos.escudo),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Reporte de caja', style: grande(21, _marino)),
                    pw.Text(
                      'Embajadores del Rey · Capítulo $capitulo',
                      style: normal.copyWith(color: _gris),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Fecha del reporte',
                    style: normal.copyWith(fontSize: 8.5, color: _gris),
                  ),
                  pw.Text(_f.format(hoy), style: negrita),
                ],
              ),
            ],
          ),
        ),

        // 1. Resumen: de dónde salió el dinero, en qué se fue y qué queda.
        ...tabla(
          'Resumen',
          [
            ('Concepto', const pw.FlexColumnWidth(3), false),
            ('Movimientos', const pw.FixedColumnWidth(82), true),
            ('Monto', const pw.FixedColumnWidth(110), true),
          ],
          [
            [
              celda('Ofrendas de los muchachos'),
              celda('${ofrendas.length}', derecha: true),
              celda(entrada(caja.ofrendas), estilo: verde, derecha: true),
            ],
            [
              celda('Otros ingresos'),
              celda('${ingresos.length}', derecha: true),
              celda(entrada(caja.ingresos), estilo: verde, derecha: true),
            ],
            [
              celda('Total de entradas', estilo: negrita),
              celda('${ofrendas.length + ingresos.length}', derecha: true),
              celda(entrada(entradas), estilo: verde, derecha: true),
            ],
            [
              celda('Total de salidas', estilo: negrita),
              celda('${egresos.length}', derecha: true),
              celda(salida(caja.egresos), estilo: rojo, derecha: true),
            ],
          ],
        ),
        // El saldo cierra el resumen como una fila más, la que más pesa.
        pw.Table(
          border: const pw.TableBorder(
            bottom: pw.BorderSide(color: _oro, width: 3),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(192),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _marino),
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 9,
                  ),
                  child: pw.Text(
                    'SALDO EN CAJA',
                    style: grande(12.5, PdfColors.white),
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 7,
                  ),
                  child: pw.Text(
                    _pesos.format(caja.saldo),
                    style: grande(17, _oro),
                  ),
                ),
              ],
            ),
          ],
        ),

        // 2. Ofrendas, un renglón por día de reunión.
        ...tabla(
          'Ofrendas por reunión',
          [
            ('Fecha', fecha, false),
            ('Reunión', const pw.FlexColumnWidth(3), false),
            ('Listas', const pw.FixedColumnWidth(60), true),
            ('Monto', monto, true),
          ],
          [
            for (final a in ofrendas)
              [
                celda(_f.format(a.fecha)),
                celda(a.concepto),
                celda('${a.listas.length}', derecha: true),
                celda(entrada(a.monto), estilo: verde, derecha: true),
              ],
          ],
          total: [
            celda(''),
            celda('Total', estilo: negrita),
            celda(''),
            celda(entrada(caja.ofrendas), estilo: verde, derecha: true),
          ],
          vacia: 'Sin ofrendas registradas',
        ),

        // 3 y 4. Lo que se registró a mano.
        ...tablaMovimientos(
          'Otros ingresos',
          ingresos,
          caja.ingresos,
          entra: true,
          vacia: 'Sin otros ingresos',
        ),
        ...tablaMovimientos(
          'Salidas',
          egresos,
          caja.egresos,
          entra: false,
          vacia: 'Sin salidas',
        ),

        // 5. El libro: todo junto, en orden, con el saldo después de cada
        // movimiento.
        ...tabla(
          'Libro de movimientos',
          [
            ('Fecha', fecha, false),
            ('Concepto', const pw.FlexColumnWidth(3), false),
            ('Tipo', const pw.FixedColumnWidth(52), false),
            ('Entrada', const pw.FixedColumnWidth(74), true),
            ('Salida', const pw.FixedColumnWidth(74), true),
            ('Saldo', const pw.FixedColumnWidth(78), true),
          ],
          [
            for (final a in cronologico)
              [
                celda(_f.format(a.fecha)),
                celda(a.concepto),
                celda(_tipo(a), estilo: normal.copyWith(color: _gris)),
                celda(
                  a.entra ? entrada(a.monto) : '',
                  estilo: verde,
                  derecha: true,
                ),
                celda(
                  a.entra ? '' : salida(a.monto),
                  estilo: rojo,
                  derecha: true,
                ),
                celda(
                  _pesos.format(corrido += a.conSigno),
                  estilo: negrita,
                  derecha: true,
                ),
              ],
          ],
          total: [
            celda(''),
            celda('Totales', estilo: negrita),
            celda(''),
            celda(entrada(entradas), estilo: verde, derecha: true),
            celda(salida(caja.egresos), estilo: rojo, derecha: true),
            celda(_pesos.format(caja.saldo), estilo: negrita, derecha: true),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> compartirCajaPdf(EstadoCaja caja, String capitulo) async =>
    Printing.sharePdf(
      bytes: await generarCajaPdf(
        caja,
        capitulo,
        recursos: await RecursosPdf.cargar(),
      ),
      filename: 'caja_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );

/// Libro con el resumen y todos los movimientos de la caja.
List<int> generarCajaExcel(EstadoCaja caja, String capitulo) {
  final libro = Excel.createExcel();
  final hojaInicial = libro.getDefaultSheet();
  final hoja = libro['Caja'];
  hoja.appendRow([TextCellValue('Capítulo $capitulo - Caja')]);
  hoja.appendRow([]);
  for (final (etiqueta, monto) in [
    ('Ofrendas de los muchachos', caja.ofrendas),
    ('Otros ingresos', caja.ingresos),
    ('Salidas', caja.egresos),
    ('Saldo en caja', caja.saldo),
  ]) {
    hoja.appendRow([TextCellValue(etiqueta), DoubleCellValue(monto)]);
  }
  hoja.appendRow([]);
  hoja.appendRow([
    for (final t in const ['Fecha', 'Tipo', 'Concepto', 'Pesos', 'Registró'])
      TextCellValue(t),
  ]);
  for (final a in caja.asientos) {
    hoja.appendRow([
      TextCellValue(_f.format(a.fecha)),
      TextCellValue(_tipo(a)),
      TextCellValue(a.concepto),
      DoubleCellValue(a.conSigno),
      TextCellValue(a.quien),
    ]);
  }
  libro.setDefaultSheet('Caja');
  if (hojaInicial != null && hojaInicial != 'Caja') libro.delete(hojaInicial);
  return libro.save()!;
}

Future<void> compartirCajaExcel(EstadoCaja caja, String capitulo) async {
  final carpeta = await getTemporaryDirectory();
  final archivo = File(
    '${carpeta.path}/caja_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
  );
  await archivo.writeAsBytes(generarCajaExcel(caja, capitulo), flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(archivo.path)], subject: 'Caja - $capitulo'),
  );
}
