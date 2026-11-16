import 'package:embajadores/core/asistencia.dart';
import 'package:embajadores/core/historial.dart';
import 'package:embajadores/models/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

Lista lista(int dia, String grupo, Map<String, Registro> registros) => Lista(
  id: '$dia-$grupo',
  reunionId: '2026-11-$dia',
  grupoId: grupo,
  periodoId: 'p',
  fecha: DateTime(2026, 11, dia, 12),
  tomadaPor: 'u',
  tomadaPorNombre: 'Consejero',
  registros: registros,
);

void main() {
  const presente = Registro(presente: true);
  const falto = Registro();

  test('junta los grupos de un mismo día y ordena del más reciente', () {
    final dias = diasDeLista([
      lista(1, 'g1', {'a': presente, 'b': falto}),
      lista(8, 'g1', {'a': presente}),
      lista(8, 'g2', {
        'c': const Registro(presente: true, biblia: true).conOfrenda(15),
        'd': falto,
        'e': const Registro(presente: true, biblia: true),
      }),
    ]);
    expect(dias.map((d) => d.fecha), [
      DateTime(2026, 11, 8),
      DateTime(2026, 11, 1),
    ]);
    final ocho = dias.first;
    expect(ocho.listas.length, 2);
    expect(ocho.anotados, 4);
    expect(ocho.presentes, 3);
    expect(ocho.ausentes, 1);
    expect(ocho.conBiblia, 2);
    expect(ocho.ofrenda, 15);
    expect(ocho.porcentaje, 75);
    expect(dias.last.porcentaje, 50);
  });

  test('una lista abierta sin marcar a nadie no aparece en el historial', () {
    expect(diasDeLista([lista(15, 'g1', {})]), isEmpty);
  });
}
