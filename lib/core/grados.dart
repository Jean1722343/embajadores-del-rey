/// Grados de la Orden de los Embajadores del Rey, en el orden del manual
/// (https://www.embajadoresdelreymex.org/el-manual-y-sus-proyectos).
enum Grado {
  /// Muchacho recién llegado, que todavía no es Aspirante.
  nuevo('nuevo', 'Nuevo ingreso'),
  aspirante('aspirante', 'Aspirante'),
  miembro('miembro', 'Miembro'),
  paje('paje', 'Paje'),
  escudero('escudero', 'Escudero'),
  caballero('caballero', 'Caballero'),
  embajador('embajador', 'Embajador'),
  embajadorEnServicio('embajadorEnServicio', 'Embajador en Servicio'),
  embajadorExtraordinario(
    'embajadorExtraordinario',
    'Embajador Extraordinario',
  ),
  embajadorPlenipotenciario(
    'embajadorPlenipotenciario',
    'Embajador Plenipotenciario',
  );

  const Grado(this.id, this.nombre);

  /// Valor que se guarda en la base de datos.
  final String id;
  final String nombre;

  static Grado desdeId(String? id) =>
      values.firstWhere((g) => g.id == id, orElse: () => Grado.aspirante);

  Grado? get siguiente => index + 1 < values.length ? values[index + 1] : null;

  /// Cuántas piezas del escudo lleva ganadas: 0 sin escudo, 1 escudo azul
  /// (Paje), 2 franja E.R. (Escudero), 3 corona (Caballero) y 4 laurel
  /// (Embajador en adelante).
  int get etapaEscudo => (index - Grado.paje.index + 1).clamp(0, 4);

  /// Imagen del escudo según lo ganado: escudo azul (Paje), franja E.R.
  /// (Escudero), corona (Caballero) y laurel (Embajador en adelante).
  /// Aspirante y Miembro todavía no tienen escudo.
  String? get escudo {
    switch (this) {
      case Grado.nuevo:
      case Grado.aspirante:
      case Grado.miembro:
        return null;
      case Grado.paje:
        return 'assets/emblema/escudo_1_paje.png';
      case Grado.escudero:
        return 'assets/emblema/escudo_2_escudero.png';
      case Grado.caballero:
        return 'assets/emblema/escudo_3_caballero.png';
      default:
        return 'assets/emblema/escudo_4_embajador.png';
    }
  }

  /// Lo que se pide para OBTENER este grado, viniendo del anterior.
  /// Los meses mínimos se cuentan en el grado anterior.
  RequisitosGrado get requisitosParaObtenerlo {
    switch (this) {
      case Grado.nuevo:
        return const RequisitosGrado();
      case Grado.aspirante:
        // Para ser considerado Aspirante: 4 reuniones consecutivas.
        return const RequisitosGrado(reunionesConsecutivas: 4);
      case Grado.miembro:
        // 75 % desde que se le consideró Aspirante.
        return const RequisitosGrado(porcentajeMinimo: 75);
      case Grado.paje:
      case Grado.escudero:
      case Grado.caballero:
      case Grado.embajador:
        return const RequisitosGrado(
          porcentajeMinimo: 75,
          mesesMinimos: 6,
          llevaMetas: true,
        );
      case Grado.embajadorEnServicio:
        return const RequisitosGrado(mesesMinimos: 4);
      default:
        // Extraordinario y Plenipotenciario avanzan por proyectos que
        // aprueba el Promotor Nacional; la app no los controla.
        return const RequisitosGrado();
    }
  }
}

/// Lo que el manual pide para obtener un grado.
class RequisitosGrado {
  const RequisitosGrado({
    this.porcentajeMinimo,
    this.mesesMinimos,
    this.reunionesConsecutivas,
    this.llevaMetas = false,
  });

  final int? porcentajeMinimo;
  final int? mesesMinimos;
  final int? reunionesConsecutivas;
  final bool llevaMetas;

  bool get sinControl =>
      porcentajeMinimo == null &&
      mesesMinimos == null &&
      reunionesConsecutivas == null &&
      !llevaMetas;
}

/// Las cinco metas en que se divide cada grado de Paje a Embajador.
enum Meta {
  miVida('miVida', 'Mi Vida'),
  miHogar('miHogar', 'Mi Hogar'),
  miCapitulo('miCapitulo', 'Mi Capítulo'),
  miIglesia('miIglesia', 'Mi Iglesia'),
  miComunidad('miComunidad', 'Mi Comunidad');

  const Meta(this.id, this.nombre);
  final String id;
  final String nombre;
}
