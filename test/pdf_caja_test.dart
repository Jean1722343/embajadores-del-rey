import 'dart:io';
import 'dart:typed_data';

import 'package:embajadores/core/asistencia.dart';
import 'package:embajadores/core/caja.dart';
import 'package:embajadores/models/modelos.dart';
import 'package:embajadores/services/exportar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('el reporte de caja se genera con datos de ejemplo', () async {
    await initializeDateFormatting('es');
    ByteData datos(String ruta) =>
        ByteData.sublistView(File(ruta).readAsBytesSync());
    final recursos = RecursosPdf(
      texto: pw.Font.ttf(datos('assets/fuentes/Figtree-400.ttf')),
      negrita: pw.Font.ttf(datos('assets/fuentes/Figtree-700.ttf')),
      titulos: pw.Font.ttf(datos('assets/fuentes/Bricolage-800.ttf')),
      escudo: pw.MemoryImage(
        File('assets/emblema/escudo_4_embajador.png').readAsBytesSync(),
      ),
    );
    Lista lista(int dia, Map<String, double> ofrendas) => Lista(
      id: '$dia',
      reunionId: '$dia',
      grupoId: 'g',
      periodoId: 'p',
      fecha: DateTime(2026, 11, dia, 12),
      tomadaPor: 'u',
      tomadaPorNombre: 'Consejero',
      registros: {
        for (final e in ofrendas.entries)
          e.key: const Registro(presente: true).conOfrenda(e.value),
      },
    );
    Movimiento mov(int dia, double monto, String concepto, bool ingreso) =>
        Movimiento(
          id: '$dia$concepto',
          esIngreso: ingreso,
          monto: monto,
          concepto: concepto,
          fecha: DateTime(2026, 11, dia, 9),
          registradoPor: 'u',
          registradoPorNombre: ingreso ? 'Líder Prueba' : 'Consejero Prueba',
        );
    final caja = calcularCaja(
      [
        lista(1, {'a': 10, 'b': 20, 'c': 5}),
        lista(8, {'a': 10, 'b': 10}),
        lista(15, {'a': 20, 'c': 12.5}),
      ],
      [
        mov(2, 850, 'Venta de comida', true),
        mov(5, 320, 'Material para manualidades', false),
        mov(9, 500, 'Donación de la Unión Varonil', true),
        mov(12, 275.5, 'Convivio del capítulo', false),
        mov(14, 150, 'Premios de memorización', false),
      ],
    );
    final bytes = await generarCajaPdf(
      caja,
      'Guillermo Carey',
      recursos: recursos,
      generado: DateTime(2026, 11, 15),
    );
    expect(bytes.length, greaterThan(5000));
    final salida = Platform.environment['SALIDA_PDF'];
    if (salida != null) File(salida).writeAsBytesSync(bytes);
  });
}
