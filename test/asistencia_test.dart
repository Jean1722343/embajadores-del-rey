import 'package:embajadores/core/asistencia.dart';
import 'package:embajadores/core/grados.dart';
import 'package:flutter_test/flutter_test.dart';

Pase pase(int dia, {bool presente = true, bool biblia = false}) => Pase(
  DateTime(2027, 1, dia, 12),
  Registro(presente: presente, biblia: biblia),
);

void main() {
  group('resumir', () {
    test('sin pases no hay porcentaje', () {
      final r = resumir(const []);
      expect(r.reuniones, 0);
      expect(r.porcentaje, isNull);
    });

    test('cuenta asistencias, faltas y porcentaje', () {
      final r = resumir([
        pase(3),
        pase(10, presente: false),
        pase(17, biblia: true),
        pase(24),
      ]);
      expect(r.reuniones, 4);
      expect(r.asistencias, 3);
      expect(r.faltas, 1);
      expect(r.porcentaje, 75);
      expect(r.biblias, 1);
    });

    test('las faltas seguidas se cuentan desde la reunión más reciente', () {
      // Desordenado a propósito: debe ordenar por fecha.
      final r = resumir([
        pase(24, presente: false),
        pase(3),
        pase(17, presente: false),
        pase(10),
      ]);
      expect(r.faltasSeguidas, 2);
      expect(r.mejorRachaAsistencias, 2);
    });

    test('si vino a la última reunión no hay faltas seguidas', () {
      final r = resumir([pase(3, presente: false), pase(10)]);
      expect(r.faltasSeguidas, 0);
    });

    test('dos listas el mismo día cuentan como una reunión', () {
      final r = resumir([pase(3, presente: false), pase(3), pase(10)]);
      expect(r.reuniones, 2);
      expect(r.asistencias, 2);
    });
  });

  test('mesesEntre cuenta meses completos', () {
    expect(mesesEntre(DateTime(2027, 1, 15), DateTime(2027, 7, 14)), 5);
    expect(mesesEntre(DateTime(2027, 1, 15), DateTime(2027, 7, 15)), 6);
    expect(mesesEntre(DateTime(2027, 7, 1), DateTime(2027, 1, 1)), 0);
  });

  group('evaluarAvance', () {
    final cuatroSeguidas = resumir([pase(3), pase(10), pase(17), pase(24)]);

    test('Aspirante pide 4 reuniones consecutivas; Miembro, 75 %', () {
      List<RequisitoEvaluado> evaluar(Grado objetivo) => evaluarAvance(
        objetivo: objetivo,
        resumen: cuatroSeguidas,
        fechaIngresoGrado: DateTime(2027, 1, 1),
        metasCumplidas: 0,
        hoy: DateTime(2027, 2, 1),
      );
      final aspirante = evaluar(Grado.aspirante);
      expect(aspirante.single.descripcion, contains('4 reuniones'));
      expect(aspirante.single.cumplido, isTrue);
      final miembro = evaluar(Grado.miembro);
      expect(miembro.single.descripcion, contains('75'));
      expect(miembro.single.cumplido, isTrue);
    });

    test('Escudero pide 75 %, 6 meses como Paje y las 5 metas', () {
      List<RequisitoEvaluado> evaluar(DateTime hoy, int metas) => evaluarAvance(
        objetivo: Grado.escudero,
        resumen: cuatroSeguidas,
        fechaIngresoGrado: DateTime(2027, 1, 1),
        metasCumplidas: metas,
        hoy: hoy,
      );

      final aMedias = evaluar(DateTime(2027, 4, 1), 3);
      expect(aMedias.map((r) => r.cumplido), [true, false, false]);

      final listo = evaluar(DateTime(2027, 7, 1), 5);
      expect(listo.every((r) => r.cumplido), isTrue);
    });

    test('con menos de 75 % no se cumple la asistencia', () {
      final reqs = evaluarAvance(
        objetivo: Grado.paje,
        resumen: resumir([pase(3), pase(10, presente: false)]),
        fechaIngresoGrado: DateTime(2026, 1, 1),
        metasCumplidas: 5,
        hoy: DateTime(2027, 2, 1),
      );
      expect(reqs.first.cumplido, isFalse);
    });
  });

  test('el escudo se completa con el grado', () {
    expect(Grado.nuevo.siguiente, Grado.aspirante);
    expect(Grado.aspirante.escudo, isNull);
    expect(Grado.miembro.etapaEscudo, 0);
    expect(Grado.caballero.etapaEscudo, 3);
    expect(Grado.paje.escudo, contains('paje'));
    expect(Grado.embajadorPlenipotenciario.escudo, contains('embajador'));
    expect(Grado.embajadorPlenipotenciario.siguiente, isNull);
  });
}
