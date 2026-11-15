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

/// Reporte de caja: encabezado con el escudo, resumen con el saldo
/// destacado y el libro de movimientos con entradas en verde y salidas
/// en rojo.
Future<Uint8List> generarCajaPdf(
  EstadoCaja caja,
  String capitulo, {
  required RecursosPdf recursos,
  DateTime? generado,
}) async {
  final hoy = generado ?? DateTime.now();
  final normal = pw.TextStyle(font: recursos.texto, fontSize: 10);
  final negrita = pw.TextStyle(font: recursos.negrita, fontSize: 10);
  pw.TextStyle grande(double t, PdfColor color) =>
      pw.TextStyle(font: recursos.titulos, fontSize: t, color: color);

  // Tarjeta de un total del resumen.
  pw.Widget total(
    String etiqueta,
    double monto,
    PdfColor color,
    String signo,
  ) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _filete, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(etiqueta, style: normal.copyWith(color: _gris)),
          pw.SizedBox(height: 3),
          pw.Text('$signo${_pesos.format(monto)}', style: grande(17, color)),
        ],
      ),
    ),
  );

  pw.Widget celda(
    String texto, {
    pw.TextStyle? estilo,
    pw.Alignment alineacion = pw.Alignment.centerLeft,
  }) => pw.Container(
    alignment: alineacion,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(texto, style: estilo ?? normal),
  );

  final entradas = caja.ofrendas + caja.ingresos;
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
        // Encabezado: bloque azul marino con el escudo y filete de oro.
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: const pw.BoxDecoration(
            color: _marino,
            border: pw.Border(bottom: pw.BorderSide(color: _oro, width: 4)),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 46,
                height: 46,
                padding: const pw.EdgeInsets.all(5),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.white,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Image(recursos.escudo),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Reporte de caja',
                      style: grande(22, PdfColors.white),
                    ),
                    pw.Text(
                      'Embajadores del Rey · Capítulo $capitulo',
                      style: normal.copyWith(
                        color: const PdfColor.fromInt(0xFFCBD3EA),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                _f.format(hoy),
                style: negrita.copyWith(color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        // Resumen: tres totales y el saldo, que es lo que más pesa.
        pw.Row(
          children: [
            total('Ofrendas de los muchachos', caja.ofrendas, _verde, '+ '),
            pw.SizedBox(width: 8),
            total('Otros ingresos', caja.ingresos, _verde, '+ '),
            pw.SizedBox(width: 8),
            total('Salidas', caja.egresos, _rojo, '- '),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: pw.BoxDecoration(
            color: _marino,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _oro, width: 2.5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SALDO EN CAJA', style: grande(13, _oro)),
                  pw.Text(
                    'Entradas ${_pesos.format(entradas)} menos salidas '
                    '${_pesos.format(caja.egresos)}',
                    style: normal.copyWith(
                      color: const PdfColor.fromInt(0xFFCBD3EA),
                    ),
                  ),
                ],
              ),
              pw.Text(
                _pesos.format(caja.saldo),
                style: grande(30, PdfColors.white),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Text('Movimientos', style: grande(14, _marino)),
        pw.SizedBox(height: 6),
        pw.Table(
          columnWidths: const {
            0: pw.FixedColumnWidth(80),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.6),
            3: pw.FixedColumnWidth(78),
            4: pw.FixedColumnWidth(78),
          },
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _filete, width: 0.5),
            bottom: pw.BorderSide(color: _filete, width: 0.5),
          ),
          children: [
            // El encabezado se repite en cada página.
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _marino),
              children: [
                for (final (titulo, derecha) in const [
                  ('Fecha', false),
                  ('Concepto', false),
                  ('Registró', false),
                  ('Entrada', true),
                  ('Salida', true),
                ])
                  celda(
                    titulo,
                    estilo: negrita.copyWith(color: PdfColors.white),
                    alineacion: derecha
                        ? pw.Alignment.centerRight
                        : pw.Alignment.centerLeft,
                  ),
              ],
            ),
            for (final (i, a) in caja.asientos.indexed)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i.isOdd ? _nube : PdfColors.white,
                ),
                children: [
                  celda(_f.format(a.fecha)),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(a.concepto, style: negrita),
                        pw.Text(
                          _tipo(a),
                          style: normal.copyWith(fontSize: 8, color: _gris),
                        ),
                      ],
                    ),
                  ),
                  celda(a.quien, estilo: normal.copyWith(color: _gris)),
                  celda(
                    a.entra ? '+ ${_pesos.format(a.monto)}' : '',
                    estilo: negrita.copyWith(color: _verde),
                    alineacion: pw.Alignment.centerRight,
                  ),
                  celda(
                    a.entra ? '' : '- ${_pesos.format(a.monto)}',
                    estilo: negrita.copyWith(color: _rojo),
                    alineacion: pw.Alignment.centerRight,
                  ),
                ],
              ),
            // Totales del libro.
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: _marino, width: 1.5),
                ),
              ),
              children: [
                celda(''),
                celda('Totales', estilo: negrita),
                celda(''),
                celda(
                  '+ ${_pesos.format(entradas)}',
                  estilo: negrita.copyWith(color: _verde),
                  alineacion: pw.Alignment.centerRight,
                ),
                celda(
                  '- ${_pesos.format(caja.egresos)}',
                  estilo: negrita.copyWith(color: _rojo),
                  alineacion: pw.Alignment.centerRight,
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _oro,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'Saldo en caja: ${_pesos.format(caja.saldo)}',
              style: grande(14, _marino),
            ),
          ),
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
