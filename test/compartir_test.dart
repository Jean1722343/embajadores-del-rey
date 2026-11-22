import 'package:embajadores/core/compartir.dart';
import 'package:embajadores/models/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

Evidencia foto(
  String id,
  String dia, {
  int hora = 10,
  String descripcion = '',
}) => Evidencia(
  id: id,
  reunionId: dia,
  grupoId: null,
  miniatura: null,
  descripcion: descripcion,
  subidaPor: 'u',
  subidaPorNombre: 'Consejero',
  fecha: DateTime(2026, 11, 20, hora),
);

String fecha(DateTime d) => '${d.day}/${d.month}/${d.year}';

void main() {
  test('ordena por día de la actividad y luego por hora de subida', () {
    final orden = enOrdenParaCompartir([
      foto('c', '2026-11-08', hora: 12),
      foto('a', '2026-11-01', hora: 18),
      foto('b', '2026-11-08', hora: 9),
    ]);
    expect(orden.map((e) => e.id), ['a', 'b', 'c']);
  });

  test('el archivo lleva el día de la actividad y su número', () {
    expect(
      nombreDeArchivo(foto('a', '2026-03-07'), 3),
      'embajadores_2026-03-07_03.jpg',
    );
    expect(
      nombreDeArchivo(foto('a', '2026-11-08'), 100),
      'embajadores_2026-11-08_100.jpg',
    );
  });

  test('un id de reunión raro no rompe el nombre del archivo', () {
    // Sin fecha válida se usa el día en que se subió.
    expect(
      nombreDeArchivo(foto('a', '../x'), 1),
      'embajadores_2026-11-20_01.jpg',
    );
  });

  group('texto que acompaña a las fotos', () {
    test('mismo día: capítulo y fecha', () {
      expect(
        textoAlCompartir(
          [foto('a', '2026-11-08'), foto('b', '2026-11-08')],
          capitulo: 'William Carey',
          fecha: fecha,
        ),
        'William Carey · 8/11/2026',
      );
    });

    test('varios días: solo el capítulo', () {
      expect(
        textoAlCompartir(
          [foto('a', '2026-11-01'), foto('b', '2026-11-08')],
          capitulo: 'William Carey',
          fecha: fecha,
        ),
        'William Carey',
      );
    });

    test('una sola descripción entre todas va arriba', () {
      expect(
        textoAlCompartir(
          [
            foto('a', '2026-11-08', descripcion: ' Campamento '),
            foto('b', '2026-11-08'),
            foto('c', '2026-11-08', descripcion: 'Campamento'),
          ],
          capitulo: 'William Carey',
          fecha: fecha,
        ),
        'Campamento\nWilliam Carey · 8/11/2026',
      );
    });

    test('descripciones distintas no se ponen', () {
      expect(
        textoAlCompartir(
          [
            foto('a', '2026-11-08', descripcion: 'Juegos'),
            foto('b', '2026-11-08', descripcion: 'Devocional'),
          ],
          capitulo: '',
          fecha: fecha,
        ),
        '8/11/2026',
      );
    });

    test('sin fotos no hay texto', () {
      expect(textoAlCompartir([], capitulo: 'X', fecha: fecha), '');
    });
  });
}
