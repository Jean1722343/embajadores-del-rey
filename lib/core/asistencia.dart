import 'grados.dart';

/// Lo que se marca de un muchacho en una reunión.
class Registro {
  const Registro({
    this.presente = false,
    this.biblia = false,
    this.ofrenda = false,
    this.monto = 0,
  });

  final bool presente;
  final bool biblia;

  /// Si trajo ofrenda.
  final bool ofrenda;

  /// Cuánto ofrendó, en pesos. Cero si no se anotó la cantidad.
  final double monto;

  factory Registro.desdeMapa(Map<String, dynamic>? m) => Registro(
    presente: m?['presente'] == true,
    biblia: m?['biblia'] == true,
    ofrenda: m?['ofrenda'] == true,
    monto: (m?['monto'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> aMapa() => {
    'presente': presente,
    'biblia': biblia,
    'ofrenda': ofrenda,
    'monto': monto,
  };

  Registro copiar({bool? presente, bool? biblia, bool? ofrenda}) => Registro(
    presente: presente ?? this.presente,
    biblia: biblia ?? this.biblia,
    ofrenda: ofrenda ?? this.ofrenda,
    // Sin ofrenda no hay monto.
    monto: (ofrenda ?? this.ofrenda) ? monto : 0,
  );

  /// Anota la ofrenda con su cantidad; cero la quita.
  Registro conOfrenda(double cantidad) => Registro(
    presente: presente,
    biblia: biblia,
    ofrenda: cantidad > 0,
    monto: cantidad > 0 ? cantidad : 0,
  );
}

/// Un pase de lista en el que el muchacho aparece, con su fecha.
class Pase {
  const Pase(this.fecha, this.registro);
  final DateTime fecha;
  final Registro registro;
}

/// Resumen de asistencia de un muchacho en un rango de reuniones.
class ResumenAsistencia {
  const ResumenAsistencia({
    required this.reuniones,
    required this.asistencias,
    required this.biblias,
    required this.ofrendas,
    this.ofrendaTotal = 0,
    required this.faltasSeguidas,
    required this.mejorRachaAsistencias,
  });

  /// Reuniones en las que se le pasó lista.
  final int reuniones;
  final int asistencias;
  final int biblias;
  final int ofrendas;

  /// Suma de lo que ofrendó, en pesos.
  final double ofrendaTotal;

  /// Faltas consecutivas contando desde la reunión más reciente.
  final int faltasSeguidas;

  /// La racha más larga de asistencias consecutivas.
  final int mejorRachaAsistencias;

  int get faltas => reuniones - asistencias;

  /// Porcentaje de 0 a 100; sin reuniones todavía no hay porcentaje.
  double? get porcentaje =>
      reuniones == 0 ? null : asistencias * 100 / reuniones;

  static const vacio = ResumenAsistencia(
    reuniones: 0,
    asistencias: 0,
    biblias: 0,
    ofrendas: 0,
    faltasSeguidas: 0,
    mejorRachaAsistencias: 0,
  );
}

/// Calcula el resumen a partir de los pases de lista de un muchacho.
/// Si una misma fecha aparece dos veces (el muchacho estuvo en dos listas
/// el mismo día), cuenta como una sola reunión y basta una presencia.
ResumenAsistencia resumir(Iterable<Pase> pases) {
  final porDia = <DateTime, Registro>{};
  for (final p in pases) {
    final dia = DateTime(p.fecha.year, p.fecha.month, p.fecha.day);
    final previo = porDia[dia];
    porDia[dia] = previo == null
        ? p.registro
        : Registro(
            presente: previo.presente || p.registro.presente,
            biblia: previo.biblia || p.registro.biblia,
            ofrenda: previo.ofrenda || p.registro.ofrenda,
            monto: previo.monto > p.registro.monto
                ? previo.monto
                : p.registro.monto,
          );
  }
  if (porDia.isEmpty) return ResumenAsistencia.vacio;

  final dias = porDia.keys.toList()..sort();
  var asistencias = 0, biblias = 0, ofrendas = 0;
  var ofrendaTotal = 0.0;
  var racha = 0, mejorRacha = 0;
  for (final d in dias) {
    final r = porDia[d]!;
    if (r.presente) {
      asistencias++;
      racha++;
      if (racha > mejorRacha) mejorRacha = racha;
    } else {
      racha = 0;
    }
    if (r.biblia) biblias++;
    if (r.ofrenda) ofrendas++;
    ofrendaTotal += r.monto;
  }

  var faltasSeguidas = 0;
  for (final d in dias.reversed) {
    if (porDia[d]!.presente) break;
    faltasSeguidas++;
  }

  return ResumenAsistencia(
    reuniones: dias.length,
    asistencias: asistencias,
    biblias: biblias,
    ofrendas: ofrendas,
    ofrendaTotal: ofrendaTotal,
    faltasSeguidas: faltasSeguidas,
    mejorRachaAsistencias: mejorRacha,
  );
}

/// A partir de cuántas faltas seguidas se avisa al consejero.
const faltasParaAlerta = 2;

/// Meses completos transcurridos entre dos fechas.
int mesesEntre(DateTime desde, DateTime hasta) {
  var meses = (hasta.year - desde.year) * 12 + hasta.month - desde.month;
  if (hasta.day < desde.day) meses--;
  return meses < 0 ? 0 : meses;
}

/// Un requisito para el siguiente grado y si ya se cumple.
class RequisitoEvaluado {
  const RequisitoEvaluado(this.descripcion, this.detalle, this.cumplido);
  final String descripcion;
  final String detalle;
  final bool cumplido;
}

/// Evalúa lo que le falta a un muchacho para obtener [objetivo].
/// [resumen] debe abarcar las reuniones desde que entró a su grado actual.
List<RequisitoEvaluado> evaluarAvance({
  required Grado objetivo,
  required ResumenAsistencia resumen,
  required DateTime fechaIngresoGrado,
  required int metasCumplidas,
  required DateTime hoy,
}) {
  final req = objetivo.requisitosParaObtenerlo;
  final lista = <RequisitoEvaluado>[];

  final consecutivas = req.reunionesConsecutivas;
  if (consecutivas != null) {
    lista.add(
      RequisitoEvaluado(
        '$consecutivas reuniones consecutivas',
        'Mejor racha: ${resumen.mejorRachaAsistencias}',
        resumen.mejorRachaAsistencias >= consecutivas,
      ),
    );
  }

  final minimo = req.porcentajeMinimo;
  if (minimo != null) {
    final p = resumen.porcentaje;
    lista.add(
      RequisitoEvaluado(
        '$minimo % de asistencia',
        p == null
            ? 'Aún sin reuniones'
            : '${p.round()} % (${resumen.asistencias} de ${resumen.reuniones})',
        p != null && p >= minimo,
      ),
    );
  }

  final meses = req.mesesMinimos;
  if (meses != null) {
    final llevados = mesesEntre(fechaIngresoGrado, hoy);
    lista.add(
      RequisitoEvaluado(
        '$meses meses en el grado actual',
        'Lleva $llevados',
        llevados >= meses,
      ),
    );
  }

  if (req.llevaMetas) {
    lista.add(
      RequisitoEvaluado(
        '5 metas firmadas',
        '$metasCumplidas de ${Meta.values.length}',
        metasCumplidas >= Meta.values.length,
      ),
    );
  }

  return lista;
}
