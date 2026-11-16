import '../models/modelos.dart';

/// Todo lo que se pasó de lista en un día de reunión, sumando sus grupos.
class DiaDeLista {
  DiaDeLista(this.fecha, this.listas);

  /// El día, a medianoche.
  final DateTime fecha;

  /// Las listas de ese día, una por grupo.
  final List<Lista> listas;

  /// Muchachos a los que se les pasó lista.
  int get anotados => listas.fold(0, (n, l) => n + l.registros.length);

  int get presentes => listas.fold(0, (n, l) => n + l.presentes);

  int get ausentes => anotados - presentes;

  int get conBiblia => listas.fold(
    0,
    (n, l) => n + l.registros.values.where((r) => r.biblia).length,
  );

  double get ofrenda => listas.fold(0, (suma, l) => suma + l.ofrendaTotal);

  /// Porcentaje de asistencia del día, o null si no se anotó a nadie.
  double? get porcentaje => anotados == 0 ? null : presentes * 100 / anotados;
}

/// Agrupa las listas por día, del más reciente al más antiguo. Las listas
/// vacías (abiertas sin marcar a nadie) no cuentan.
List<DiaDeLista> diasDeLista(List<Lista> listas) {
  final porDia = <DateTime, List<Lista>>{};
  for (final l in listas) {
    if (l.registros.isEmpty) continue;
    final dia = DateTime(l.fecha.year, l.fecha.month, l.fecha.day);
    (porDia[dia] ??= []).add(l);
  }
  return [for (final e in porDia.entries) DiaDeLista(e.key, e.value)]
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
}
