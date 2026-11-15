import '../models/modelos.dart';

enum TipoAsiento { ofrenda, ingreso, egreso }

/// Un renglón del libro de la caja.
class Asiento {
  const Asiento({
    required this.tipo,
    required this.fecha,
    required this.concepto,
    required this.monto,
    this.movimiento,
    this.listas = const [],
    this.quien = '',
  });

  final TipoAsiento tipo;
  final DateTime fecha;
  final String concepto;

  /// Siempre positivo; el tipo dice si entra o sale.
  final double monto;

  /// El movimiento registrado a mano, si el asiento viene de uno.
  final Movimiento? movimiento;

  /// Las listas de donde salen las ofrendas de ese día.
  final List<Lista> listas;

  /// Quién registró el movimiento.
  final String quien;

  bool get entra => tipo != TipoAsiento.egreso;
  double get conSigno => entra ? monto : -monto;
}

/// Estado de la caja: totales y libro, del más reciente al más antiguo.
class EstadoCaja {
  const EstadoCaja({
    required this.ofrendas,
    required this.ingresos,
    required this.egresos,
    required this.asientos,
  });

  final double ofrendas;
  final double ingresos;
  final double egresos;
  final List<Asiento> asientos;

  double get saldo => ofrendas + ingresos - egresos;

  /// Cómo ha ido el saldo: parte de cero y agrega un punto por cada
  /// asiento, del más antiguo al más reciente.
  List<double> get historialSaldo {
    var saldo = 0.0;
    return [0, for (final a in asientos.reversed) saldo += a.conSigno];
  }

  static const vacio = EstadoCaja(
    ofrendas: 0,
    ingresos: 0,
    egresos: 0,
    asientos: [],
  );

  /// Solo los asientos entre dos fechas (incluidas), con sus totales.
  EstadoCaja entre(DateTime desde, DateTime hasta) => _de(
    asientos
        .where((a) => !a.fecha.isBefore(desde) && !a.fecha.isAfter(hasta))
        .toList(),
  );

  static EstadoCaja _de(List<Asiento> asientos) {
    double suma(TipoAsiento t) => asientos
        .where((a) => a.tipo == t)
        .fold(0, (total, a) => total + a.monto);
    return EstadoCaja(
      ofrendas: suma(TipoAsiento.ofrenda),
      ingresos: suma(TipoAsiento.ingreso),
      egresos: suma(TipoAsiento.egreso),
      asientos: asientos,
    );
  }
}

/// Arma el libro de la caja: las ofrendas de cada día de reunión (sumando
/// todas las listas de ese día) más las entradas y salidas registradas.
EstadoCaja calcularCaja(List<Lista> listas, List<Movimiento> movimientos) {
  final porDia = <DateTime, List<Lista>>{};
  for (final l in listas) {
    if (l.ofrendaTotal <= 0) continue;
    final dia = DateTime(l.fecha.year, l.fecha.month, l.fecha.day);
    (porDia[dia] ??= []).add(l);
  }
  final asientos = <Asiento>[
    for (final e in porDia.entries)
      Asiento(
        tipo: TipoAsiento.ofrenda,
        fecha: e.key,
        concepto: 'Ofrendas de la reunión',
        monto: e.value.fold(0, (total, l) => total + l.ofrendaTotal),
        listas: e.value,
      ),
    for (final m in movimientos)
      Asiento(
        tipo: m.esIngreso ? TipoAsiento.ingreso : TipoAsiento.egreso,
        fecha: m.fecha,
        concepto: m.concepto,
        monto: m.monto,
        movimiento: m,
        quien: m.registradoPorNombre,
      ),
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  return EstadoCaja._de(asientos);
}
