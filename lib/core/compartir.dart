import '../models/modelos.dart';

/// Cuántas fotos se mandan de una sola vez. WhatsApp no recibe más de cien
/// en un envío, y cada una hay que descargarla antes.
const maximoAlCompartir = 100;

/// Las fotos en el orden en que pasaron: por día de la actividad y, dentro
/// del día, por el momento en que se subieron.
List<Evidencia> enOrdenParaCompartir(Iterable<Evidencia> fotos) =>
    fotos.toList()..sort((a, b) {
      final porDia = a.dia.compareTo(b.dia);
      return porDia != 0 ? porDia : a.fecha.compareTo(b.fecha);
    });

/// Nombre del archivo que recibe quien abre la foto fuera de la app:
/// «embajadores_2026-11-08_03.jpg». [numero] empieza en 1.
String nombreDeArchivo(Evidencia e, int numero) {
  final d = e.dia;
  final dia =
      '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';
  return 'embajadores_${dia}_${'$numero'.padLeft(2, '0')}.jpg';
}

/// Texto que acompaña a las fotos: la descripción si todas comparten una
/// sola, y debajo el capítulo con el día si todas son de la misma actividad.
String textoAlCompartir(
  List<Evidencia> fotos, {
  required String capitulo,
  required String Function(DateTime) fecha,
}) {
  if (fotos.isEmpty) return '';
  final descripciones = {
    for (final e in fotos)
      if (e.descripcion.trim().isNotEmpty) e.descripcion.trim(),
  };
  final dias = {
    for (final e in fotos) DateTime(e.dia.year, e.dia.month, e.dia.day),
  };
  final pie = [
    if (capitulo.trim().isNotEmpty) capitulo.trim(),
    if (dias.length == 1) fecha(dias.single),
  ].join(' · ');
  return [
    if (descripciones.length == 1) descripciones.single,
    if (pie.isNotEmpty) pie,
  ].join('\n');
}
