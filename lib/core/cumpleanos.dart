import '../models/modelos.dart';

/// Día en que se festeja un cumpleaños en [anio]. Quien nació un 29 de
/// febrero festeja el 28 en los años que no son bisiestos.
DateTime cumpleEn(DateTime nacimiento, int anio) {
  final bisiesto = anio % 4 == 0 && (anio % 100 != 0 || anio % 400 == 0);
  if (nacimiento.month == 2 && nacimiento.day == 29 && !bisiesto) {
    return DateTime(anio, 2, 28);
  }
  return DateTime(anio, nacimiento.month, nacimiento.day);
}

/// El siguiente cumpleaños contando desde [hoy] (hoy mismo cuenta).
DateTime proximoCumple(DateTime nacimiento, DateTime hoy) {
  final dia = DateTime(hoy.year, hoy.month, hoy.day);
  final este = cumpleEn(nacimiento, dia.year);
  return este.isBefore(dia) ? cumpleEn(nacimiento, dia.year + 1) : este;
}

/// Cumpleaños de un muchacho que cae dentro de los próximos días.
class Cumple {
  const Cumple({
    required this.alumno,
    required this.fecha,
    required this.faltan,
    required this.edad,
  });

  final Alumno alumno;
  final DateTime fecha;

  /// Días que faltan; 0 si es hoy.
  final int faltan;

  /// Los años que cumple ese día.
  final int edad;

  bool get esHoy => faltan == 0;
}

/// Cumpleaños de los muchachos entre hoy y los siguientes [dias] días,
/// del más cercano al más lejano.
List<Cumple> proximosCumples(
  List<Alumno> alumnos,
  DateTime hoy, {
  int dias = 14,
}) {
  final dia = DateTime(hoy.year, hoy.month, hoy.day);
  final lista = <Cumple>[];
  for (final a in alumnos) {
    final nacimiento = a.fechaNac;
    if (nacimiento == null) continue;
    final fecha = proximoCumple(nacimiento, dia);
    // Con fechas a medianoche local, redondear absorbe el cambio de horario.
    final faltan = (fecha.difference(dia).inHours / 24).round();
    if (faltan > dias) continue;
    lista.add(
      Cumple(
        alumno: a,
        fecha: fecha,
        faltan: faltan,
        edad: fecha.year - nacimiento.year,
      ),
    );
  }
  return lista..sort((a, b) {
    final porDia = a.faltan.compareTo(b.faltan);
    return porDia != 0 ? porDia : a.alumno.nombre.compareTo(b.alumno.nombre);
  });
}
