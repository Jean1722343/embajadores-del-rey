import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/grados.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/actualizacion.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import 'biblioteca.dart';
import 'perfil.dart';
import 'reportes.dart';
import 'sin_capitulo.dart';
import 'tutorial.dart';

/// Pestaña "Capítulo": datos, administración y sesión.
class PantallaAdmin extends ConsumerWidget {
  const PantallaAdmin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capitulo = ref.watch(capituloProvider).value;
    final yo = ref.watch(yoProvider).value;
    final perfil = ref.watch(perfilProvider).value;
    final esLider = yo?.esLider ?? false;
    final miembros = ref.watch(miembrosProvider).value ?? const <Miembro>[];
    final otrosLideres = miembros
        .where((m) => m.esLider && m.activo && m.uid != yo?.uid)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Capítulo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Image.asset(
                    'assets/emblema/escudo_4_embajador.png',
                    height: 64,
                    cacheHeight: 192,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          capitulo?.nombre ?? '',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          [
                            capitulo?.iglesia ?? '',
                            capitulo?.ciudad ?? '',
                          ].where((s) => s.isNotEmpty).join(' · '),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // El perfil del usuario: su nombre y su foto.
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: FotoPersona(
                yo?.nombre ?? '',
                yo?.foto ?? perfil?.foto,
                radio: 24,
              ),
              title: Text(
                yo?.nombre ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${yo?.rol.nombre ?? ''} · Mi perfil'),
              trailing: const Icon(PhosphorIconsBold.pencilSimple),
              onTap: () => abrir(context, const PantallaMiPerfil()),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                // Líder y consejeros administran por igual.
                ...[
                  _Opcion(
                    PhosphorIconsBold.books,
                    'Biblioteca',
                    'La Orden, los grados y material para descargar',
                    () => abrir(context, const PantallaBiblioteca()),
                  ),
                  _Opcion(
                    PhosphorIconsBold.chartBar,
                    'Reportes de asistencia',
                    'Porcentajes, PDF y Excel',
                    () => abrir(context, const PantallaReportes()),
                  ),
                  _Opcion(
                    PhosphorIconsBold.calendarBlank,
                    'Periodos',
                    'Semestres o ciclos del capítulo',
                    () => abrir(context, const PantallaPeriodos()),
                  ),
                  _Opcion(
                    PhosphorIconsBold.circlesThree,
                    'Grupos',
                    'Qué grados pasan lista juntos y con quién',
                    () => abrir(context, const PantallaGrupos()),
                  ),
                ],
                _Opcion(
                  PhosphorIconsBold.identificationBadge,
                  'Consejeros',
                  esLider
                      ? 'Invitar y administrar accesos'
                      : 'Invitar y ver el equipo',
                  () => abrir(context, const PantallaConsejeros()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                if ((perfil?.capitulos.length ?? 0) > 1)
                  _Opcion(
                    PhosphorIconsBold.arrowsLeftRight,
                    'Cambiar de capítulo',
                    'Perteneces a ${perfil!.capitulos.length}',
                    () => _cambiarCapitulo(context, ref, perfil.capitulos),
                  ),
                _Opcion(
                  PhosphorIconsBold.key,
                  'Entrar a otro capítulo',
                  'Con un código de invitación',
                  () => abrir(context, const PantallaCodigo()),
                ),
                if (perfil?.superAdmin ?? false)
                  _Opcion(
                    PhosphorIconsBold.shieldCheck,
                    'Todos los capítulos',
                    'Super administrador',
                    () => abrir(context, const PantallaSuperAdmin()),
                  ),
                _Opcion(
                  PhosphorIconsBold.graduationCap,
                  'Ver el tutorial',
                  'Cómo se usa la app, en tres pasos',
                  () => abrir(
                    context,
                    Builder(
                      builder: (c) =>
                          PantallaTutorial(alTerminar: () => Navigator.pop(c)),
                    ),
                  ),
                ),
                if (esLider)
                  _Opcion(
                    PhosphorIconsBold.arrowCounterClockwise,
                    'Empezar de nuevo',
                    'Borra muchachos, listas, fotos, caja, grupos y periodos',
                    () => _empezarDeNuevo(context, ref, capitulo?.nombre ?? ''),
                  ),
                _Opcion(
                  PhosphorIconsBold.doorOpen,
                  'Abandonar este capítulo',
                  'Dejas de ser parte de ${capitulo?.nombre ?? 'él'}',
                  () => _abandonar(
                    context,
                    ref,
                    capitulo?.nombre ?? '',
                    unicoLider: esLider && otrosLideres == 0,
                  ),
                ),
                if (esLider)
                  _Opcion(
                    PhosphorIconsBold.trash,
                    'Borrar el capítulo',
                    'Lo elimina por completo, para todos',
                    () => _borrarCapitulo(context, ref, capitulo?.nombre ?? ''),
                  ),
                _Opcion(
                  PhosphorIconsBold.signOut,
                  'Cerrar sesión',
                  null,
                  () => ref.read(repoProvider).salir(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Creditos(),
        ],
      ),
    );
  }

  /// Pide escribir el nombre del capítulo para que un borrado no ocurra por
  /// un toque equivocado. Devuelve si se confirmó.
  Future<bool> _confirmarEscribiendo(
    BuildContext context, {
    required String titulo,
    required String texto,
    required String nombre,
    required String aceptar,
  }) async {
    final escrito = TextEditingController();
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto),
              const SizedBox(height: 14),
              Text('Para confirmar, escribe: $nombre'),
              const SizedBox(height: 8),
              TextField(controller: escrito, autofocus: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colores.rojo),
            onPressed: () => Navigator.pop(
              c,
              escrito.text.trim().toLowerCase() == nombre.trim().toLowerCase(),
            ),
            child: Text(aceptar),
          ),
        ],
      ),
    );
    if (si != true && context.mounted) {
      if (si == false && escrito.text.isNotEmpty) {
        avisar(context, 'El nombre no coincide; no se borró nada.');
      }
    }
    return si == true;
  }

  /// Borra todo el contenido del capítulo, pero conserva el capítulo.
  Future<void> _empezarDeNuevo(
    BuildContext context,
    WidgetRef ref,
    String nombre,
  ) async {
    final si = await _confirmarEscribiendo(
      context,
      titulo: 'Empezar de nuevo',
      texto:
          'Se borran para todos los muchachos, las listas, las fotos, '
          'la caja, los grupos y los periodos. Se conservan el capítulo y sus '
          'consejeros. No se puede deshacer.',
      nombre: nombre,
      aceptar: 'Borrar todo',
    );
    if (!si || !context.mounted) return;
    avisar(context, 'Borrando…');
    final ok = await intentar(
      context,
      () => ref.read(repoProvider).reiniciarCapitulo(ref.read(capIdProvider)!),
    );
    if (ok && context.mounted) {
      avisar(context, 'Capítulo en blanco. ¡A empezar!');
    }
  }

  /// Elimina el capítulo completo, con sus consejeros. Solo el líder.
  Future<void> _borrarCapitulo(
    BuildContext context,
    WidgetRef ref,
    String nombre,
  ) async {
    final si = await _confirmarEscribiendo(
      context,
      titulo: 'Borrar el capítulo',
      texto:
          'Se elimina el capítulo completo: los muchachos, las listas, las '
          'fotos, la caja, los grupos, los periodos y el acceso de todos los '
          'consejeros. Nadie podrá volver a abrirlo. No se puede deshacer.',
      nombre: nombre,
      aceptar: 'Borrar el capítulo',
    );
    if (!si || !context.mounted) return;
    avisar(context, 'Borrando el capítulo…');
    final mensajes = ScaffoldMessenger.of(context);
    final ok = await intentar(
      context,
      () => ref.read(repoProvider).borrarCapitulo(ref.read(capIdProvider)!),
    );
    if (ok) {
      mensajes
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Capítulo borrado.')));
    }
  }

  /// El usuario se sale del capítulo. El único líder no puede: dejaría al
  /// capítulo sin nadie que lo administre.
  Future<void> _abandonar(
    BuildContext context,
    WidgetRef ref,
    String nombre, {
    required bool unicoLider,
  }) async {
    if (unicoLider) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Eres el único líder'),
          content: const Text(
            'Si te vas, el capítulo se queda sin líder. Antes nombra líder a '
            'otro consejero (en Consejeros, con el menú de su nombre) o, si '
            'ya nadie lo va a usar, borra el capítulo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    final si = await confirmar(
      context,
      titulo: 'Abandonar $nombre',
      texto:
          'Dejarás de ver a sus muchachos, listas, fotos y caja. Lo que ya '
          'registraste se queda en el capítulo. Para volver necesitarás un '
          'código de invitación nuevo.',
      aceptar: 'Abandonar',
    );
    if (!si || !context.mounted) return;
    final mensajes = ScaffoldMessenger.of(context);
    final ok = await intentar(
      context,
      () => ref.read(repoProvider).abandonarCapitulo(ref.read(capIdProvider)!),
    );
    if (ok) {
      mensajes
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Saliste de $nombre.')));
    }
  }

  void _cambiarCapitulo(BuildContext context, WidgetRef ref, List<String> ids) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final id in ids)
                ListTile(
                  leading: const Icon(PhosphorIconsBold.shieldChevron),
                  title: Text(
                    ref.watch(capituloPorIdProvider(id)).value?.nombre ??
                        'Capítulo no disponible',
                  ),
                  selected: id == ref.watch(capIdProvider),
                  onTap: () {
                    ref.read(repoProvider).cambiarCapitulo(id);
                    Navigator.pop(c);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion(this.icono, this.titulo, this.detalle, this.alTocar);

  final IconData icono;
  final String titulo;
  final String? detalle;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icono, color: Colores.acento),
    title: Text(titulo),
    subtitle: detalle == null ? null : Text(detalle!),
    trailing: const Icon(PhosphorIconsBold.caretRight),
    onTap: alTocar,
  );
}

// ---------------------------------------------------------------- Periodos

class PantallaPeriodos extends ConsumerWidget {
  const PantallaPeriodos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodos = ref.watch(periodosProvider).value ?? const <Periodo>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Periodos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrir(context, _FormPeriodo(existentes: periodos)),
        icon: const Icon(PhosphorIconsBold.plus),
        label: const Text('Nuevo periodo'),
      ),
      body: periodos.isEmpty
          ? const Vacio(
              icono: PhosphorIconsBold.calendarBlank,
              texto:
                  'Un periodo es el semestre o ciclo en que trabajan. Los '
                  'grupos y los porcentajes se llevan por periodo.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final p in periodos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        title: Text(
                          p.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${fechaCorta(p.inicio)} – ${fechaCorta(p.fin)}',
                        ),
                        trailing: p.activo
                            ? const Chip(label: Text('Activo'))
                            : const Icon(PhosphorIconsBold.caretRight),
                        onTap: () => abrir(
                          context,
                          _FormPeriodo(existentes: periodos, periodo: p),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _FormPeriodo extends ConsumerStatefulWidget {
  const _FormPeriodo({required this.existentes, this.periodo});

  final List<Periodo> existentes;
  final Periodo? periodo;

  @override
  ConsumerState<_FormPeriodo> createState() => _FormPeriodoState();
}

class _FormPeriodoState extends ConsumerState<_FormPeriodo> {
  late final TextEditingController _nombre;
  late DateTime _inicio;
  late DateTime _fin;
  late bool _activo;

  @override
  void initState() {
    super.initState();
    final p = widget.periodo;
    final hoy = DateTime.now();
    // Por defecto, el semestre en curso.
    final primero = hoy.month <= 6;
    _inicio = p?.inicio ?? DateTime(hoy.year, primero ? 1 : 7, 1);
    _fin = p?.fin ?? DateTime(hoy.year, primero ? 6 : 12, primero ? 30 : 31);
    _activo = p?.activo ?? true;
    _nombre = TextEditingController(
      text:
          p?.nombre ??
          '${primero ? 'Enero – Junio' : 'Julio – Diciembre'} ${hoy.year}',
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _fechas() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 3),
      initialDateRange: DateTimeRange(start: _inicio, end: _fin),
      helpText: 'Inicio y fin del periodo',
    );
    if (r != null) {
      setState(() {
        _inicio = r.start;
        _fin = r.end;
      });
    }
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      avisar(context, 'Ponle nombre al periodo.');
      return;
    }
    final ok = await intentar(
      context,
      () => ref
          .read(repoProvider)
          .guardarPeriodo(
            ref.read(capIdProvider)!,
            Periodo(
              id: widget.periodo?.id ?? '',
              nombre: _nombre.text.trim(),
              inicio: _inicio,
              fin: _fin,
              activo: _activo,
            ),
            widget.existentes,
          ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.periodo == null ? 'Nuevo periodo' : 'Periodo'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _fechas,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fechas',
              suffixIcon: Icon(PhosphorIconsBold.calendar),
            ),
            child: Text('${fechaCorta(_inicio)} – ${fechaCorta(_fin)}'),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Periodo activo'),
          subtitle: const Text(
            'Es el que se usa para pasar lista. Solo puede haber uno.',
          ),
          value: _activo,
          onChanged: (v) => setState(() => _activo = v),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    ),
  );
}

// ------------------------------------------------------------------ Grupos

class PantallaGrupos extends ConsumerWidget {
  const PantallaGrupos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoActivoProvider);
    final grupos = ref.watch(gruposProvider).value ?? const <Grupo>[];
    final miembros = ref.watch(miembrosProvider).value ?? const <Miembro>[];
    final activos = ref.watch(alumnosActivosProvider);

    if (periodo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grupos')),
        body: Vacio(
          icono: PhosphorIconsBold.calendarX,
          texto: 'Primero crea un periodo activo.',
          boton: 'Crear periodo',
          alTocar: () => abrir(context, const PantallaPeriodos()),
        ),
      );
    }

    String consejeros(Grupo g) {
      final nombres = miembros
          .where((m) => g.consejeroIds.contains(m.uid))
          .map((m) => m.nombre);
      return nombres.isEmpty ? 'Sin consejero asignado' : nombres.join(', ');
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grupos'),
            Text(
              periodo.nombre,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colores.sobreAzul,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            abrir(context, _FormGrupo(periodoId: periodo.id, otros: grupos)),
        icon: const Icon(PhosphorIconsBold.plus),
        label: const Text('Nuevo grupo'),
      ),
      body: grupos.isEmpty
          ? const Vacio(
              icono: PhosphorIconsBold.circlesThree,
              texto:
                  'Un grupo junta uno o varios grados que pasan lista con '
                  'el mismo consejero. Puedes rearmarlos cada periodo.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final g in grupos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        isThreeLine: true,
                        title: Text(
                          g.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${g.grados.map((x) => x.nombre).join(' · ')}\n'
                          '${consejeros(g)} · '
                          '${alumnosDeGrupo(activos, g).length} muchachos',
                        ),
                        trailing: const Icon(PhosphorIconsBold.caretRight),
                        onTap: () => abrir(
                          context,
                          _FormGrupo(
                            periodoId: periodo.id,
                            grupo: g,
                            otros: grupos.where((x) => x.id != g.id).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _FormGrupo extends ConsumerStatefulWidget {
  const _FormGrupo({required this.periodoId, required this.otros, this.grupo});

  final String periodoId;
  final Grupo? grupo;

  /// Los demás grupos del periodo: sus grados ya están ocupados.
  final List<Grupo> otros;

  @override
  ConsumerState<_FormGrupo> createState() => _FormGrupoState();
}

class _FormGrupoState extends ConsumerState<_FormGrupo> {
  late final _nombre = TextEditingController(text: widget.grupo?.nombre);
  late final Set<Grado> _grados = {...?widget.grupo?.grados};
  late final Set<String> _consejeros = {...?widget.grupo?.consejeroIds};

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_grados.isEmpty) {
      avisar(context, 'Elige al menos un grado.');
      return;
    }
    final ordenados = Grado.values.where(_grados.contains).toList();
    final nombre = _nombre.text.trim().isEmpty
        ? ordenados.map((g) => g.nombre).join(' y ')
        : _nombre.text.trim();
    final ok = await intentar(
      context,
      () => ref
          .read(repoProvider)
          .guardarGrupo(
            ref.read(capIdProvider)!,
            Grupo(
              id: widget.grupo?.id ?? '',
              periodoId: widget.periodoId,
              nombre: nombre,
              grados: ordenados,
              consejeroIds: _consejeros.toList(),
            ),
          ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final miembros = (ref.watch(miembrosProvider).value ?? const <Miembro>[])
        .where((m) => m.activo)
        .toList();
    final ocupados = {for (final g in widget.otros) ...g.grados};

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupo == null ? 'Nuevo grupo' : 'Grupo'),
        actions: [
          if (widget.grupo != null && ref.watch(esLiderProvider))
            IconButton(
              tooltip: 'Borrar grupo',
              icon: const Icon(PhosphorIconsBold.trash),
              onPressed: () async {
                final si = await confirmar(
                  context,
                  titulo: 'Borrar grupo',
                  texto:
                      'Las listas ya tomadas se conservan y siguen '
                      'contando en los porcentajes.',
                  aceptar: 'Borrar',
                );
                if (!si || !context.mounted) return;
                final ok = await intentar(
                  context,
                  () => ref
                      .read(repoProvider)
                      .borrarGrupo(ref.read(capIdProvider)!, widget.grupo!.id),
                );
                if (ok && context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre del grupo',
              helperText: 'Si lo dejas vacío se usan los nombres de los grados',
            ),
          ),
          const TituloSeccion('Grados que lo forman'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final g in Grado.values)
                FilterChip(
                  label: Text(g.nombre),
                  selected: _grados.contains(g),
                  // Un grado solo puede estar en un grupo del periodo.
                  onSelected: ocupados.contains(g)
                      ? null
                      : (v) => setState(
                          () => v ? _grados.add(g) : _grados.remove(g),
                        ),
                ),
            ],
          ),
          if (ocupados.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Los grados en gris ya están en otro grupo.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          const TituloSeccion('Consejeros a cargo'),
          Card(
            child: Column(
              children: [
                for (final m in miembros)
                  CheckboxListTile(
                    value: _consejeros.contains(m.uid),
                    title: Text(m.nombre),
                    subtitle: Text(m.rol.nombre),
                    onChanged: (v) => setState(
                      () => v == true
                          ? _consejeros.add(m.uid)
                          : _consejeros.remove(m.uid),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Cualquier consejero del capítulo puede pasar la lista de este '
              'grupo si el encargado falta.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Consejeros

class PantallaConsejeros extends ConsumerWidget {
  const PantallaConsejeros({super.key});

  Future<void> _invitar(BuildContext context, WidgetRef ref, Rol rol) async {
    String? codigo;
    final ok = await intentar(context, () async {
      codigo = await ref
          .read(repoProvider)
          .crearInvitacion(ref.read(capIdProvider)!, rol);
    });
    if (!ok || codigo == null || !context.mounted) return;
    final capitulo = ref.read(capituloProvider).value?.nombre ?? '';
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Código para ${rol.nombre.toLowerCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              codigo!,
              style: const TextStyle(
                fontSize: 34,
                letterSpacing: 6,
                fontWeight: FontWeight.w700,
                color: Colores.acento,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vale 7 días. Quien lo use entra a tu capítulo, así que '
              'compártelo solo con la persona indicada.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            icon: const Icon(PhosphorIconsBold.shareNetwork),
            label: const Text('Compartir'),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text:
                    'Te invito como ${rol.nombre.toLowerCase()} del capítulo '
                    '$capitulo de Embajadores del Rey. Abre la app, toca '
                    '"Tengo un código" y escribe: $codigo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final miembros = ref.watch(miembrosProvider).value ?? const <Miembro>[];
    final esLider = ref.watch(esLiderProvider);
    final uid = ref.watch(sesionProvider).value?.uid;
    final invitaciones =
        ref.watch(invitacionesProvider).value ?? const <Invitacion>[];
    final repo = ref.read(repoProvider);
    final capId = ref.watch(capIdProvider)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Consejeros')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FilledButton.icon(
            onPressed: () => _invitar(context, ref, Rol.consejero),
            icon: const Icon(PhosphorIconsBold.userPlus),
            label: const Text('Invitar consejero'),
          ),
          // Solo un líder puede nombrar a otro líder.
          if (esLider) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _invitar(context, ref, Rol.lider),
              icon: const Icon(PhosphorIconsBold.shieldChevron),
              label: const Text('Invitar a otro líder'),
            ),
          ],
          if (invitaciones.isNotEmpty) ...[
            const TituloSeccion('Códigos vigentes'),
            Card(
              child: Column(
                children: [
                  for (final i in invitaciones)
                    ListTile(
                      leading: const Icon(PhosphorIconsBold.key),
                      title: Text(
                        i.codigo,
                        style: const TextStyle(
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${i.rol.nombre} · vence ${fechaCorta(i.expiraEn)}',
                      ),
                      trailing: TextButton(
                        onPressed: () => intentar(
                          context,
                          () => repo.anularInvitacion(i.codigo),
                        ),
                        child: const Text('Anular'),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const TituloSeccion('Equipo'),
          Card(
            child: Column(
              children: [
                for (final m in miembros)
                  ListTile(
                    leading: FotoPersona(m.nombre, m.foto),
                    title: Text(m.nombre + (m.uid == uid ? ' (tú)' : '')),
                    // Cada quien edita su propio perfil desde aquí.
                    onTap: m.uid == uid
                        ? () => abrir(context, const PantallaMiPerfil())
                        : null,
                    subtitle: Text(
                      m.activo ? m.rol.nombre : '${m.rol.nombre} · sin acceso',
                    ),
                    // Nadie se quita a sí mismo el acceso ni el liderazgo,
                    // para que el capítulo no se quede sin líder.
                    trailing: !esLider || m.uid == uid
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (v) => intentar(
                              context,
                              () => switch (v) {
                                'rol' => repo.cambiarMiembro(
                                  capId,
                                  m.uid,
                                  rol: m.esLider ? Rol.consejero : Rol.lider,
                                ),
                                _ => repo.cambiarMiembro(
                                  capId,
                                  m.uid,
                                  activo: !m.activo,
                                ),
                              },
                            ),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rol',
                                child: Text(
                                  m.esLider
                                      ? 'Dejar como consejero'
                                      : 'Hacer líder',
                                ),
                              ),
                              PopupMenuItem(
                                value: 'acceso',
                                child: Text(
                                  m.activo
                                      ? 'Quitar acceso'
                                      : 'Devolver acceso',
                                ),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------- Super administrador

class PantallaSuperAdmin extends ConsumerWidget {
  const PantallaSuperAdmin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capitulos = ref.watch(todosLosCapitulosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Todos los capítulos')),
      body: capitulos.when(
        loading: () => const Cargando(),
        error: (e, _) => Vacio(
          icono: PhosphorIconsBold.cloudSlash,
          texto: mensajeDeError(e),
        ),
        data: (lista) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${lista.length} capítulos registrados'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final c in lista)
                    SwitchListTile(
                      title: Text(c.nombre),
                      subtitle: Text(
                        [
                          c.iglesia,
                          c.ciudad,
                          c.estado,
                          if (c.suspendido) 'SUSPENDIDO',
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                      value: !c.suspendido,
                      onChanged: (activo) async {
                        if (!activo) {
                          final si = await confirmar(
                            context,
                            titulo: 'Suspender ${c.nombre}',
                            texto:
                                'Nadie de ese capítulo podrá entrar hasta '
                                'que lo reactives.',
                            aceptar: 'Suspender',
                          );
                          if (!si || !context.mounted) return;
                        }
                        await intentar(
                          context,
                          () => ref.read(repoProvider).suspender(c.id, !activo),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Créditos de la app.
class Creditos extends ConsumerWidget {
  const Creditos({super.key});

  /// Perfil de LinkedIn del autor. Se abre en el navegador o en la app de LinkedIn.
  static const linkedin = 'https://www.linkedin.com/in/jeanpaulgc';

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      const Text(
        'Hecho por',
        style: TextStyle(fontSize: 12.5, color: Colores.textoSuave),
      ),
      const SizedBox(height: 2),
      Text('Jean Paul Gallegos Cruz', style: titulo(17)),
      if (linkedin.isNotEmpty)
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(linkedin),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(PhosphorIconsBold.linkedinLogo, size: 20),
          label: const Text('LinkedIn'),
        ),
      const SizedBox(height: 6),
      const Text(
        'Para los capítulos de Embajadores del Rey',
        style: TextStyle(fontSize: 12.5, color: Colores.textoSuave),
      ),
      if (ref.watch(versionInstaladaProvider).value case final version?)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Versión $version',
            style: const TextStyle(fontSize: 12, color: Colores.textoSuave),
          ),
        ),
    ],
  );
}
