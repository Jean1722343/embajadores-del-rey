import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'grados.dart';

/// Lo que el manual pide para obtener un grado, además de lo que la app
/// calcula sola (asistencia, tiempo en el grado y reuniones consecutivas).
class RequisitosManual {
  const RequisitosManual({required this.generales, required this.metas});

  /// Requisitos que no pertenecen a ninguna meta.
  final List<String> generales;

  /// Requisitos de cada una de las cinco metas (de Paje a Embajador).
  final Map<Meta, List<String>> metas;

  static const vacio = RequisitosManual(generales: [], metas: {});

  List<String> de(Meta meta) => metas[meta] ?? const [];
}

/// Requisitos por grado tomados del manual oficial
/// (assets/manual/requisitos.json, extraído de embajadoresdelreymex.org).
abstract final class Manual {
  static Map<Grado, RequisitosManual> _porGrado = const {};

  static RequisitosManual para(Grado grado) =>
      _porGrado[grado] ?? RequisitosManual.vacio;

  /// Clave con que se guarda un requisito marcado como hecho.
  static String claveGeneral(int i) => 'general_$i';
  static String claveMeta(Meta meta, int i) => '${meta.id}_$i';

  static Future<void> cargar() async {
    final texto = await rootBundle.loadString('assets/manual/requisitos.json');
    _porGrado = leer(texto);
  }

  static Map<Grado, RequisitosManual> leer(String texto) {
    final grados = (jsonDecode(texto) as Map)['grados'] as Map? ?? const {};
    // «Haber alcanzado el grado anterior» no se lista: la app solo ofrece
    // el siguiente grado.
    List<String> lista(dynamic v) => [
      for (final x in (v as List? ?? const []))
        if (x is String &&
            x.trim().isNotEmpty &&
            !x.startsWith('Haber alcanzado el grado'))
          x.trim(),
    ];
    return {
      for (final g in Grado.values)
        if (grados[g.id] is Map)
          g: RequisitosManual(
            generales: lista(grados[g.id]['generales']),
            metas: {
              for (final m in Meta.values)
                if (lista((grados[g.id]['metas'] as Map?)?[m.id]).isNotEmpty)
                  m: lista((grados[g.id]['metas'] as Map?)?[m.id]),
            },
          ),
    };
  }
}
