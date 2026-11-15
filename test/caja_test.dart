import 'package:embajadores/core/asistencia.dart';
import 'package:embajadores/core/caja.dart';
import 'package:embajadores/models/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

Lista lista(int dia, String grupo, Map<String, double> ofrendas) => Lista(
  id: '$dia-$grupo',
  reunionId: '$dia',
  grupoId: grupo,
  periodoId: 'p',
  fecha: DateTime(2027, 1, dia, 12),
  tomadaPor: 'u',
  tomadaPorNombre: 'Consejero',
  registros: {
    for (final e in ofrendas.entries)
      e.key: const Registro(presente: true).conOfrenda(e.value),
  },
);

Movimiento mov(int dia, double monto, {bool ingreso = true}) => Movimiento(
  id: '$dia-$monto',
  esIngreso: ingreso,
  monto: monto,
  concepto: ingreso ? 'Venta' : 'Material',
  fecha: DateTime(2027, 1, dia, 9),
  registradoPor: 'u',
  registradoPorNombre: 'Líder',
);

void main() {
  test('Registro: la ofrenda guarda su cantidad y cero la quita', () {
    final r = const Registro(presente: true).conOfrenda(20);
    expect(r.ofrenda, isTrue);
    expect(r.monto, 20);
    expect(Registro.desdeMapa(r.aMapa()).monto, 20);
    expect(r.conOfrenda(0).ofrenda, isFalse);
    // Al quitar la ofrenda con copiar se va también la cantidad.
    expect(r.copiar(ofrenda: false).monto, 0);
    // Listas viejas: ofrenda marcada sin cantidad.
    expect(Registro.desdeMapa({'ofrenda': true}).monto, 0);
  });

  test('la caja suma ofrendas e ingresos y resta salidas', () {
    final caja = calcularCaja(
      [
        lista(3, 'g1', {'a': 10, 'b': 5}),
        lista(3, 'g2', {'c': 20}),
        lista(10, 'g1', {'a': 10, 'b': 0}),
      ],
      [mov(5, 300), mov(8, 120, ingreso: false)],
    );
    expect(caja.ofrendas, 45);
    expect(caja.ingresos, 300);
    expect(caja.egresos, 120);
    expect(caja.saldo, 225);
  });

  test('las ofrendas de un mismo día forman un solo renglón', () {
    final caja = calcularCaja([
      lista(3, 'g1', {'a': 10}),
      lista(3, 'g2', {'c': 20}),
      lista(10, 'g1', {'a': 0}),
    ], const []);
    expect(caja.asientos, hasLength(1));
    expect(caja.asientos.single.monto, 30);
    expect(caja.asientos.single.listas, hasLength(2));
  });

  test('el libro va del más reciente al más antiguo y se puede acotar', () {
    final caja = calcularCaja(
      [
        lista(3, 'g1', {'a': 10}),
      ],
      [mov(5, 300), mov(8, 120, ingreso: false)],
    );
    expect(caja.asientos.map((a) => a.fecha.day), [8, 5, 3]);
    final enero4a9 = caja.entre(DateTime(2027, 1, 4), DateTime(2027, 1, 9, 23));
    expect(enero4a9.ofrendas, 0);
    expect(enero4a9.saldo, 180);
  });

  test('el historial del saldo parte de cero y termina en el saldo', () {
    final caja = calcularCaja(
      [
        lista(3, 'g1', {'a': 10}),
      ],
      [mov(5, 300), mov(8, 120, ingreso: false)],
    );
    expect(caja.historialSaldo, [0, 10, 310, 190]);
    expect(caja.historialSaldo.last, caja.saldo);
  });

  test('sin movimientos la caja está en cero', () {
    expect(calcularCaja(const [], const []).saldo, 0);
  });
}
