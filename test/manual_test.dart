import 'dart:io';

import 'package:embajadores/core/grados.dart';
import 'package:embajadores/core/manual.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final manual = Manual.leer(
    File('assets/manual/requisitos.json').readAsStringSync(),
  );

  test('de Paje a Embajador cada grado trae sus cinco metas', () {
    for (final g in [
      Grado.paje,
      Grado.escudero,
      Grado.caballero,
      Grado.embajador,
    ]) {
      for (final m in Meta.values) {
        expect(manual[g]!.de(m), isNotEmpty, reason: '${g.nombre} ${m.nombre}');
      }
    }
  });

  test('los demás grados traen requisitos generales y ninguna meta', () {
    for (final g in [
      Grado.aspirante,
      Grado.miembro,
      Grado.embajadorEnServicio,
      Grado.embajadorExtraordinario,
      Grado.embajadorPlenipotenciario,
    ]) {
      expect(manual[g]!.generales, isNotEmpty, reason: g.nombre);
      expect(manual[g]!.metas, isEmpty, reason: g.nombre);
    }
  });

  test('no se lista «haber alcanzado el grado anterior»', () {
    for (final r in manual.values) {
      expect(
        r.generales.where((t) => t.startsWith('Haber alcanzado')),
        isEmpty,
      );
    }
  });

  test('Paje pide memorizar Juan 3:16 en Mi Vida', () {
    expect(
      manual[Grado.paje]!.de(Meta.miVida).any((t) => t.contains('Juan 3:16')),
      isTrue,
    );
  });
}
