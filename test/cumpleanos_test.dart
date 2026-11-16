import 'package:embajadores/core/cumpleanos.dart';
import 'package:embajadores/core/grados.dart';
import 'package:embajadores/models/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

Alumno alumno(String nombre, DateTime? nacimiento) => Alumno(
  id: nombre,
  nombre: nombre,
  grado: Grado.paje,
  fechaIngresoGrado: DateTime(2026, 1, 1),
  fechaNac: nacimiento,
);

void main() {
  final hoy = DateTime(2026, 11, 15, 17, 30);

  test('el próximo cumpleaños es este año si aún no pasa, o el siguiente', () {
    expect(proximoCumple(DateTime(2015, 11, 20), hoy), DateTime(2026, 11, 20));
    expect(proximoCumple(DateTime(2015, 11, 15), hoy), DateTime(2026, 11, 15));
    expect(proximoCumple(DateTime(2015, 11, 14), hoy), DateTime(2027, 11, 14));
    expect(proximoCumple(DateTime(2015, 1, 2), hoy), DateTime(2027, 1, 2));
  });

  test(
    'quien nació un 29 de febrero festeja el 28 si el año no es bisiesto',
    () {
      final nacimiento = DateTime(2016, 2, 29);
      expect(cumpleEn(nacimiento, 2027), DateTime(2027, 2, 28));
      expect(cumpleEn(nacimiento, 2028), DateTime(2028, 2, 29));
      expect(proximoCumple(nacimiento, hoy), DateTime(2027, 2, 28));
    },
  );

  test('la lista trae solo los de los próximos días, del más cercano al más '
      'lejano, con la edad que cumplen', () {
    final lista = proximosCumples([
      alumno('Lejano', DateTime(2014, 3, 1)),
      alumno('En una semana', DateTime(2015, 11, 22)),
      alumno('Sin fecha', null),
      alumno('Hoy', DateTime(2016, 11, 15)),
      alumno('Ayer', DateTime(2016, 11, 14)),
      alumno('Mañana', DateTime(2013, 11, 16)),
    ], hoy);
    expect(lista.map((c) => c.alumno.nombre), [
      'Hoy',
      'Mañana',
      'En una semana',
    ]);
    expect(lista.map((c) => c.faltan), [0, 1, 7]);
    expect(lista.map((c) => c.edad), [10, 13, 11]);
    expect(lista.first.esHoy, isTrue);
  });

  test('un cumpleaños de enero aparece desde finales de diciembre', () {
    final lista = proximosCumples([
      alumno('Enero', DateTime(2015, 1, 3)),
    ], DateTime(2026, 12, 28));
    expect(lista.single.fecha, DateTime(2027, 1, 3));
    expect(lista.single.faltan, 6);
    expect(lista.single.edad, 12);
  });
}
