import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import 'package:url_launcher/url_launcher.dart';

import '../core/asistencia.dart';
import '../core/grados.dart';
import '../core/manual.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/fotos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import '../widgets/movimiento.dart';
import 'evidencias.dart';

/// Lista de muchachos del capítulo, con búsqueda y filtro por grado.
class PantallaAlumnos extends ConsumerStatefulWidget {
  const PantallaAlumnos({super.key});
  @override
  ConsumerState<PantallaAlumnos> createState() => _PantallaAlumnosState();
}

class _PantallaAlumnosState extends ConsumerState<PantallaAlumnos> {
  String _busqueda = '';
  Grado? _grado;
  bool _verBajas = false;

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(alumnosProvider);
    final resumenes = ref.watch(resumenesPeriodoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Muchachos'),
        actions: [
          PopupMenuButton<bool>(
            onSelected: (v) => setState(() => _verBajas = v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: !_verBajas,
                child: Text(_verBajas ? 'Ver activos' : 'Ver dados de baja'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrir(context, const PantallaFormAlumno()),
        icon: const Icon(PhosphorIconsBold.userPlus),
        label: const Text('Agregar'),
      ),
      body: todos.when(
        loading: () => const Cargando(),
        error: (e, _) => Vacio(
          icono: PhosphorIconsBold.cloudSlash,
          texto: mensajeDeError(e),
        ),
        data: (lista) {
          final base = lista.where((a) => a.activo != _verBajas).toList();
          final gradosUsados = Grado.values
              .where((g) => base.any((a) => a.grado == g))
              .toList();
          final visibles = base
              .where(
                (a) =>
                    (_grado == null || a.grado == _grado) &&
                    a.nombre.toLowerCase().contains(_busqueda.toLowerCase()),
              )
              .toList();
          if (lista.isEmpty) {
            return const Vacio(
              icono: PhosphorIconsBold.usersThree,
              texto:
                  'Aún no hay muchachos. Agrega al primero con el botón '
                  'de abajo.',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre',
                    prefixIcon: Icon(PhosphorIconsBold.magnifyingGlass),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Todos (${base.length})'),
                        selected: _grado == null,
                        onSelected: (_) => setState(() => _grado = null),
                      ),
                    ),
                    for (final g in gradosUsados)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(g.nombre),
                          selected: _grado == g,
                          onSelected: (_) => setState(() => _grado = g),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: visibles.isEmpty
                    ? const Vacio(
                        icono: PhosphorIconsBold.magnifyingGlassMinus,
                        texto: 'Nadie coincide con esa búsqueda.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: visibles.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final a = visibles[i];
                          return ListTile(
                            tileColor: Colors.transparent,
                            leading: FotoAlumno(a, heroe: 'lista-${a.id}'),
                            title: Text(
                              a.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(a.grado.nombre),
                            trailing: PildoraPorcentaje(
                              resumenes[a.id]?.porcentaje,
                            ),
                            onTap: () => abrir(
                              context,
                              PantallaPerfilAlumno(
                                a.id,
                                heroe: 'lista-${a.id}',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Alta y edición de un muchacho.
class PantallaFormAlumno extends ConsumerStatefulWidget {
  const PantallaFormAlumno({super.key, this.alumno});

  final Alumno? alumno;

  @override
  ConsumerState<PantallaFormAlumno> createState() => _PantallaFormAlumnoState();
}

class _PantallaFormAlumnoState extends ConsumerState<PantallaFormAlumno> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.alumno?.nombre);
  late final _tutor = TextEditingController(text: widget.alumno?.tutorNombre);
  late final _tel = TextEditingController(text: widget.alumno?.tutorTel);
  late final _tutor2 = TextEditingController(text: widget.alumno?.tutor2Nombre);
  late final _tel2 = TextEditingController(text: widget.alumno?.tutor2Tel);
  late final _domicilio = TextEditingController(text: widget.alumno?.domicilio);
  late final _notas = TextEditingController(text: widget.alumno?.notas);
  late Grado _grado = widget.alumno?.grado ?? Grado.nuevo;
  late DateTime _ingreso = widget.alumno?.fechaIngresoGrado ?? DateTime.now();
  late DateTime? _nacimiento = widget.alumno?.fechaNac;
  File? _foto;
  bool _ocupado = false;

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _tutor,
      _tel,
      _tutor2,
      _tel2,
      _domicilio,
      _notas,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _fecha(DateTime inicial, {required int desdeAnio}) =>
      showDatePicker(
        context: context,
        initialDate: inicial,
        firstDate: DateTime(desdeAnio),
        lastDate: DateTime.now(),
      );

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _ocupado = true);
    final repo = ref.read(repoProvider);
    final capId = ref.read(capIdProvider)!;
    final previo = widget.alumno;
    final ok = await intentar(context, () async {
      final id = await repo.guardarAlumno(
        capId,
        Alumno(
          id: previo?.id ?? '',
          nombre: _nombre.text.trim(),
          grado: _grado,
          fechaIngresoGrado: _ingreso,
          fechaNac: _nacimiento,
          tutorNombre: _tutor.text.trim(),
          tutorTel: _tel.text.trim(),
          tutor2Nombre: _tutor2.text.trim(),
          tutor2Tel: _tel2.text.trim(),
          domicilio: _domicilio.text.trim(),
          notas: _notas.text.trim(),
          foto: previo?.foto,
          activo: previo?.activo ?? true,
        ),
      );
      if (_foto != null) {
        // Foto de perfil pequeña: cabe dentro del documento del muchacho.
        final lista = await prepararFoto(_foto!, lado: 256, ladoMini: 256);
        repo.guardarFotoAlumno(capId, id, lista.miniatura);
      }
    });
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final previo = widget.alumno;
    final hoy = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text(previo == null ? 'Nuevo muchacho' : 'Editar datos'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: () async {
                  final f = await elegirFoto(context);
                  if (f != null) setState(() => _foto = f);
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    if (_foto != null)
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: FileImage(_foto!),
                      )
                    else if (previo != null)
                      FotoAlumno(previo, radio: 48)
                    else
                      const CircleAvatar(
                        radius: 48,
                        backgroundColor: Colores.nube,
                        child: Icon(
                          PhosphorIconsFill.user,
                          size: 48,
                          color: Colores.acento,
                        ),
                      ),
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colores.oro,
                      child: Icon(
                        PhosphorIconsBold.camera,
                        size: 18,
                        color: Colores.texto,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Escribe el nombre' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Grado>(
              initialValue: _grado,
              decoration: const InputDecoration(labelText: 'Grado'),
              items: [
                for (final g in Grado.values)
                  DropdownMenuItem(value: g, child: Text(g.nombre)),
              ],
              onChanged: (g) => setState(() => _grado = g ?? _grado),
            ),
            const SizedBox(height: 12),
            _CampoFecha(
              etiqueta: 'En este grado desde',
              fecha: _ingreso,
              alTocar: () async {
                final f = await _fecha(_ingreso, desdeAnio: hoy.year - 10);
                if (f != null) setState(() => _ingreso = f);
              },
            ),
            const SizedBox(height: 12),
            _CampoFecha(
              etiqueta: 'Fecha de nacimiento',
              fecha: _nacimiento,
              alTocar: () async {
                final f = await _fecha(
                  _nacimiento ?? DateTime(hoy.year - 10),
                  desdeAnio: hoy.year - 25,
                );
                if (f != null) setState(() => _nacimiento = f);
              },
            ),
            const SizedBox(height: 12),
            const TituloSeccion('Familia'),
            TextFormField(
              controller: _tutor,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Papá, mamá o tutor',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Su teléfono',
                helperText: '10 dígitos',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tutor2,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Segundo contacto (opcional)',
                hintText: 'El otro papá, un abuelo, un tío…',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tel2,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono del segundo contacto',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _domicilio,
              textCapitalization: TextCapitalization.words,
              keyboardType: TextInputType.streetAddress,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Domicilio',
                hintText: 'Calle, número, colonia',
              ),
            ),
            const TituloSeccion('Otros datos'),
            TextFormField(
              controller: _notas,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas',
                hintText: 'Alergias, observaciones…',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _ocupado ? null : _guardar,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.etiqueta,
    required this.fecha,
    required this.alTocar,
  });

  final String etiqueta;
  final DateTime? fecha;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: alTocar,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        suffixIcon: const Icon(PhosphorIconsBold.calendarBlank, size: 20),
      ),
      child: Text(fecha == null ? 'Sin fecha' : fechaCorta(fecha!)),
    ),
  );
}

/// Perfil del muchacho: asistencia, avance de grado, metas y tutor.
class PantallaPerfilAlumno extends ConsumerWidget {
  const PantallaPerfilAlumno(this.alumnoId, {super.key, this.heroe});

  final String alumnoId;

  /// Etiqueta de la foto en la lista de origen, para que viaje al perfil.
  final String? heroe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alumnos = ref.watch(alumnosProvider).value ?? const <Alumno>[];
    final a = alumnos.where((x) => x.id == alumnoId).firstOrNull;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Vacio(
          icono: PhosphorIconsBold.userMinus,
          texto: 'Este muchacho ya no está en la lista.',
        ),
      );
    }
    final hoy = DateTime.now();
    final esLider = ref.watch(esLiderProvider);
    final capId = ref.watch(capIdProvider)!;
    final repo = ref.read(repoProvider);
    final delPeriodo =
        ref.watch(resumenesPeriodoProvider)[a.id] ?? ResumenAsistencia.vacio;
    final edad = a.edad(hoy);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(PhosphorIconsBold.pencilSimple),
            onPressed: () => abrir(context, PantallaFormAlumno(alumno: a)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'baja') {
                await intentar(
                  context,
                  () => repo.darDeBaja(capId, a.id, !a.activo),
                );
              } else {
                final si = await confirmar(
                  context,
                  titulo: 'Borrar a ${a.nombre}',
                  texto:
                      'Se borran sus datos. Si solo dejó de venir, mejor '
                      'dalo de baja para conservar su historial.',
                  aceptar: 'Borrar',
                );
                if (!si || !context.mounted) return;
                final ok = await intentar(
                  context,
                  () => repo.borrarAlumno(capId, a.id),
                );
                if (ok && context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'baja',
                child: Text(a.activo ? 'Dar de baja' : 'Reactivar'),
              ),
              if (esLider)
                const PopupMenuItem(value: 'borrar', child: Text('Borrar')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Row(
            children: [
              FotoAlumno(a, radio: 40, heroe: heroe),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nombre,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      [
                        a.grado.nombre,
                        if (edad != null) '$edad años',
                        if (!a.activo) 'Dado de baja',
                      ].join(' · '),
                    ),
                  ],
                ),
              ),
              InsigniaGrado(a.grado, alto: 86),
            ],
          ),
          const TituloSeccion('Asistencia del periodo'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          delPeriodo.reuniones == 0
                              ? 'Aún no se le ha pasado lista'
                              : '${delPeriodo.asistencias} asistencias y '
                                    '${delPeriodo.faltas} faltas en '
                                    '${delPeriodo.reuniones} reuniones',
                        ),
                      ),
                      PildoraPorcentaje(delPeriodo.porcentaje),
                    ],
                  ),
                  if (delPeriodo.reuniones > 0) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Dato('Biblia', '${delPeriodo.biblias}'),
                        _Dato(
                          'Ofrenda',
                          delPeriodo.ofrendaTotal > 0
                              ? dinero(delPeriodo.ofrendaTotal)
                              : '${delPeriodo.ofrendas}',
                        ),
                        _Dato(
                          'Mejor racha',
                          '${delPeriodo.mejorRachaAsistencias}',
                        ),
                        _Dato(
                          'Faltas seguidas',
                          '${delPeriodo.faltasSeguidas}',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Se muestra si el siguiente grado tiene algo que controlar: lo que
          // calcula la app o los requisitos del manual.
          if (a.grado.siguiente != null &&
              (!a.grado.siguiente!.requisitosParaObtenerlo.sinControl ||
                  Manual.para(a.grado.siguiente!).generales.isNotEmpty))
            _Avance(alumno: a, objetivo: a.grado.siguiente!),
          if (a.tieneDatosDeFamilia) ...[
            const TituloSeccion('Familia y domicilio'),
            _Contacto(nombre: a.tutorNombre, telefono: a.tutorTel),
            _Contacto(nombre: a.tutor2Nombre, telefono: a.tutor2Tel),
            if (a.domicilio.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Domicilio',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colores.textoSuave,
                        ),
                      ),
                      Text(
                        a.domicilio,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _lanzar(
                          context,
                          Uri.https('www.google.com', '/maps/search/', {
                            'api': '1',
                            'query': a.domicilio,
                          }),
                        ),
                        icon: const Icon(PhosphorIconsBold.mapPin),
                        label: const Text('Ver en el mapa'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (a.notas.isNotEmpty) ...[
            const TituloSeccion('Notas'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(width: double.infinity, child: Text(a.notas)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de un contacto de la familia, con llamada y WhatsApp.
class _Contacto extends StatelessWidget {
  const _Contacto({required this.nombre, required this.telefono});

  final String nombre;
  final String telefono;

  @override
  Widget build(BuildContext context) {
    if (nombre.isEmpty && telefono.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nombre.isNotEmpty)
                Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (telefono.isNotEmpty) ...[
                Text(telefono),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _lanzar(
                          context,
                          Uri(scheme: 'tel', path: _digitos(telefono)),
                        ),
                        icon: const Icon(PhosphorIconsBold.phone),
                        label: const Text('Llamar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _lanzar(
                          context,
                          Uri.parse('https://wa.me/${_paraWhatsApp(telefono)}'),
                        ),
                        icon: const Icon(PhosphorIconsBold.whatsappLogo),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _digitos(String tel) => tel.replaceAll(RegExp(r'\D'), '');

/// Número con lada de país; a los de 10 dígitos se les antepone México (52).
String _paraWhatsApp(String tel) {
  final d = _digitos(tel);
  return d.length == 10 ? '52$d' : d;
}

Future<void> _lanzar(BuildContext context, Uri uri) async {
  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) avisar(context, 'No se pudo abrir.');
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(valor, style: titulo(22)),
      Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

/// Requisitos y metas para obtener el siguiente grado.
class _Avance extends ConsumerWidget {
  const _Avance({required this.alumno, required this.objetivo});

  final Alumno alumno;
  final Grado objetivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = DateTime.now();
    final ingreso = alumno.fechaIngresoGrado;
    // Fechas redondeadas al día para que la consulta no cambie en cada
    // redibujado.
    final Rango rango = (
      desde: DateTime(ingreso.year, ingreso.month, ingreso.day),
      hasta: DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59),
    );
    final listas = ref.watch(listasProvider(rango)).value ?? const [];
    final resumen =
        resumirPorAlumno(listas)[alumno.id] ?? ResumenAsistencia.vacio;
    final avance =
        ref
            .watch(avanceProvider((alumnoId: alumno.id, objetivo: objetivo)))
            .value ??
        Avance.vacio(objetivo);
    final requisitos = evaluarAvance(
      objetivo: objetivo,
      resumen: resumen,
      fechaIngresoGrado: ingreso,
      metasCumplidas: avance.cumplidas,
      hoy: hoy,
    );
    final manual = Manual.para(objetivo);
    final generalesHechos = [
      for (var i = 0; i < manual.generales.length; i++)
        if (avance.hechos.contains(Manual.claveGeneral(i))) i,
    ].length;
    final listo =
        requisitos.every((r) => r.cumplido) &&
        generalesHechos == manual.generales.length;
    final repo = ref.read(repoProvider);
    final capId = ref.read(capIdProvider)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion('Camino a ${objetivo.nombre}'),
        Card(
          child: Column(
            children: [
              for (final r in requisitos)
                ListTile(
                  dense: true,
                  leading: Icon(
                    r.cumplido
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsBold.xCircle,
                    color: r.cumplido ? Colores.verde : Colores.rojo,
                  ),
                  title: Text(r.descripcion),
                  trailing: Text(r.detalle),
                ),
              // Requisitos del manual que no pertenecen a ninguna meta.
              if (manual.generales.isNotEmpty) ...[
                const Divider(height: 1),
                const _Subtitulo('Requisitos del manual'),
                for (final (i, texto) in manual.generales.indexed)
                  _CasillaRequisito(
                    texto: texto,
                    hecho: avance.hechos.contains(Manual.claveGeneral(i)),
                    alCambiar: (v) => repo.marcarRequisito(
                      capId,
                      alumno.id,
                      objetivo,
                      Manual.claveGeneral(i),
                      v,
                    ),
                  ),
              ],
              if (objetivo.requisitosParaObtenerlo.llevaMetas) ...[
                const Divider(height: 1),
                const _Subtitulo('Las cinco metas'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final m in Meta.values)
                        Expanded(
                          child: _SelloMeta(
                            meta: m,
                            firma: avance.metas[m],
                            hechos: [
                              for (var i = 0; i < manual.de(m).length; i++)
                                if (avance.hechos.contains(
                                  Manual.claveMeta(m, i),
                                ))
                                  i,
                            ].length,
                            total: manual.de(m).length,
                            alTocar: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => _HojaMeta(
                                alumno: alumno,
                                objetivo: objetivo,
                                meta: m,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Toca una meta para ver sus requisitos y firmarla',
                    style: TextStyle(fontSize: 12.5, color: Colores.textoSuave),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(12),
                child: BotonOro(
                  icono: PhosphorIconsBold.medal,
                  texto: 'Graduar a ${objetivo.nombre}',
                  alTocar: () async {
                    final si = await confirmar(
                      context,
                      titulo: 'Graduar a ${objetivo.nombre}',
                      texto: listo
                          ? '${alumno.nombre} cumple los requisitos que lleva '
                                'la app. Confirma que la comisión revisora ya lo '
                                'aprobó.'
                          : 'A ${alumno.nombre} todavía le faltan requisitos. '
                                '¿Graduarlo de todos modos?',
                      aceptar: 'Graduar',
                    );
                    if (!si || !context.mounted) return;
                    final ok = await intentar(
                      context,
                      () => repo.graduar(capId, alumno.id, objetivo),
                    );
                    if (ok && context.mounted) {
                      celebrar(context);
                      avisar(
                        context,
                        '${alumno.nombre} ahora es ${objetivo.nombre}.',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Una de las cinco metas, como sello: apagado si falta, de oro si ya la
/// firmó un consejero.
class _SelloMeta extends StatelessWidget {
  const _SelloMeta({
    required this.meta,
    required this.firma,
    required this.hechos,
    required this.total,
    this.alTocar,
  });

  final Meta meta;
  final FirmaMeta? firma;

  /// Requisitos del manual cumplidos y totales de esta meta.
  final int hechos;
  final int total;
  final VoidCallback? alTocar;

  static const _iconos = {
    Meta.miVida: PhosphorIconsFill.heart,
    Meta.miHogar: PhosphorIconsFill.house,
    Meta.miCapitulo: PhosphorIconsFill.shieldChevron,
    Meta.miIglesia: PhosphorIconsFill.church,
    Meta.miComunidad: PhosphorIconsFill.globeHemisphereWest,
  };

  @override
  Widget build(BuildContext context) {
    final firmada = firma != null;
    return Pulsable(
      alTocar: alTocar,
      child: Semantics(
        button: true,
        label: '${meta.nombre}: ${firmada ? 'firmada' : 'sin firmar'}',
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              width: firmada ? 52 : 48,
              height: firmada ? 52 : 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: firmada ? Colores.oro : Colores.nube,
                border: Border.all(
                  color: firmada ? Colores.oro : Colores.borde,
                  width: 1.5,
                ),
              ),
              child: Icon(
                _iconos[meta],
                size: 24,
                color: firmada ? Colores.tinta : Colores.textoApagado,
              ),
            ),
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: Text(
                meta.nombre.replaceFirst('Mi ', ''),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: firmada ? Colores.azul : Colores.textoSuave,
                ),
              ),
            ),
            // Avance de los requisitos del manual de esta meta.
            if (total > 0)
              ExcludeSemantics(
                child: Text(
                  firmada ? 'Firmada' : '$hechos de $total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: firmada || hechos == total
                        ? Colores.verde
                        : Colores.textoApagado,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colores.textoSuave,
        ),
      ),
    ),
  );
}

/// Un requisito del manual que el consejero marca cuando el muchacho lo
/// cumple.
class _CasillaRequisito extends StatelessWidget {
  const _CasillaRequisito({
    required this.texto,
    required this.hecho,
    required this.alCambiar,
  });

  final String texto;
  final bool hecho;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    dense: true,
    controlAffinity: ListTileControlAffinity.leading,
    value: hecho,
    onChanged: (v) {
      HapticFeedback.selectionClick();
      alCambiar(v ?? false);
    },
    title: Text(
      texto,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.35,
        color: hecho ? Colores.textoSuave : Colores.tinta,
      ),
    ),
  );
}

/// Hoja de una meta: sus requisitos según el manual y la firma del
/// consejero, que se habilita cuando están todos cumplidos.
class _HojaMeta extends ConsumerWidget {
  const _HojaMeta({
    required this.alumno,
    required this.objetivo,
    required this.meta,
  });

  final Alumno alumno;
  final Grado objetivo;
  final Meta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avance =
        ref
            .watch(avanceProvider((alumnoId: alumno.id, objetivo: objetivo)))
            .value ??
        Avance.vacio(objetivo);
    final requisitos = Manual.para(objetivo).de(meta);
    final hechos = [
      for (var i = 0; i < requisitos.length; i++)
        if (avance.hechos.contains(Manual.claveMeta(meta, i))) i,
    ].length;
    final firma = avance.metas[meta];
    final completa = hechos == requisitos.length;
    final repo = ref.read(repoProvider);
    final capId = ref.read(capIdProvider)!;

    Future<void> firmar(bool valor) async {
      final ok = await intentar(
        context,
        () => repo.firmarMeta(
          capId,
          alumno.id,
          objetivo,
          meta,
          valor,
          ref.read(miNombreProvider),
        ),
      );
      if (ok && valor && context.mounted) {
        celebrar(context);
        Navigator.pop(context);
      }
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.nombre, style: titulo(26)),
                  const SizedBox(height: 2),
                  Text(
                    '${alumno.nombre} · camino a ${objetivo.nombre}',
                    style: const TextStyle(color: Colores.textoSuave),
                  ),
                  if (requisitos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    BarraAvance(
                      hechos / requisitos.length,
                      color: completa ? Colores.verde : Colores.azul,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$hechos de ${requisitos.length} requisitos',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colores.textoSuave,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (requisitos.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'El manual no trae en la app la lista de esta meta. Revisa '
                  'el cuadernillo del muchacho y firma cuando la cumpla.',
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (i, texto) in requisitos.indexed)
                      _CasillaRequisito(
                        texto: texto,
                        hecho: avance.hechos.contains(
                          Manual.claveMeta(meta, i),
                        ),
                        alCambiar: (v) => repo.marcarRequisito(
                          capId,
                          alumno.id,
                          objetivo,
                          Manual.claveMeta(meta, i),
                          v,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: firma != null
                  ? Column(
                      children: [
                        Text(
                          'Firmada por ${firma.nombre}'
                          '${firma.fecha == null ? '' : ' el ${fechaCorta(firma.fecha!)}'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colores.verde,
                          ),
                        ),
                        TextButton(
                          onPressed: () => firmar(false),
                          child: const Text('Quitar la firma'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        BotonOro(
                          texto: 'Firmar meta',
                          icono: PhosphorIconsBold.pencilSimple,
                          alTocar: completa ? () => firmar(true) : null,
                        ),
                        if (!completa)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Se firma cuando estén todos los requisitos.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colores.textoSuave,
                              ),
                            ),
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
