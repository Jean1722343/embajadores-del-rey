import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/fotos.dart';
import '../services/proveedores.dart';
import '../services/repo.dart';
import '../widgets/comunes.dart';
import '../widgets/movimiento.dart';
import 'compartir_fotos.dart';

/// Pregunta de dónde sacar la foto. La cámara ya la entrega reducida
/// (lado mayor de 1600 px) para que prepararla sea rápido.
Future<File?> elegirFoto(BuildContext context) async {
  final origen = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(PhosphorIconsBold.camera),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(PhosphorIconsFill.images),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (origen == null) return null;
  final foto = await ImagePicker().pickImage(
    source: origen,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  return foto == null ? null : File(foto.path);
}

/// Toma una foto, pide la fecha de la actividad y una descripción, y la
/// guarda como evidencia. [reunionId] es la fecha que se propone (aaaa-mm-dd);
/// se puede cambiar por la de una actividad pasada.
Future<void> agregarEvidencia(
  BuildContext context,
  WidgetRef ref, {
  required String reunionId,
  String? grupoId,
}) async {
  final archivo = await elegirFoto(context);
  if (archivo == null || !context.mounted) return;

  final descripcion = TextEditingController();
  var dia = DateTime.tryParse(reunionId) ?? DateTime.now();
  final guardar = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, actualizar) => AlertDialog(
        title: const Text('Evidencia'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  archivo,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              // Una foto de una actividad pasada se guarda con su fecha.
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final elegido = await elegirDiaDeActividad(c, dia);
                  if (elegido != null) actualizar(() => dia = elegido);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '¿Cuándo fue?',
                    suffixIcon: Icon(PhosphorIconsBold.calendar),
                  ),
                  child: Text(
                    fechaLargaConAnio(dia),
                    style: const TextStyle(
                      color: Colores.tinta,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descripcion,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 140,
                decoration: const InputDecoration(
                  labelText: '¿Qué se hizo? (opcional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 46)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  if (guardar != true || !context.mounted) return;

  final ok = await intentar(context, () async {
    final foto = await prepararFoto(archivo);
    ref
        .read(repoProvider)
        .guardarEvidencia(
          capId: ref.read(capIdProvider)!,
          reunionId: idDeFecha(dia),
          grupoId: grupoId,
          foto: foto,
          descripcion: descripcion.text,
          miNombre: ref.read(miNombreProvider),
        );
  });
  if (ok && context.mounted) avisar(context, 'Foto guardada.');
}

/// Calendario para elegir el día de una actividad: hoy o una fecha pasada.
Future<DateTime?> elegirDiaDeActividad(BuildContext context, DateTime inicial) {
  final hoy = DateTime.now();
  final primero = DateTime(hoy.year - 10);
  return showDatePicker(
    context: context,
    initialDate: inicial.isAfter(hoy) || inicial.isBefore(primero)
        ? hoy
        : inicial,
    firstDate: primero,
    lastDate: hoy,
    helpText: 'Fecha de la actividad',
  );
}

/// Galería de evidencias del capítulo, agrupada por el día de la actividad.
/// Con el botón de compartir (o dejando el dedo sobre una foto) se marcan
/// varias para mandarlas juntas por WhatsApp u otra app.
class PantallaEvidencias extends ConsumerStatefulWidget {
  const PantallaEvidencias({super.key});

  @override
  ConsumerState<PantallaEvidencias> createState() => _PantallaEvidenciasState();
}

class _PantallaEvidenciasState extends ConsumerState<PantallaEvidencias> {
  bool _eligiendo = false;

  /// Ids de las fotos marcadas.
  final _elegidas = <String>{};

  @override
  void initState() {
    super.initState();
    pestanaActual.addListener(_salir);
  }

  @override
  void dispose() {
    pestanaActual.removeListener(_salir);
    super.dispose();
  }

  /// Deja de seleccionar. También al cambiar de pestaña: si no, el botón
  /// de atrás quedaría atrapado por una selección que ya no se ve.
  void _salir() {
    if (!_eligiendo || !mounted) return;
    setState(() {
      _eligiendo = false;
      _elegidas.clear();
    });
  }

  void _alternar(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _eligiendo = true;
      if (!_elegidas.remove(id)) _elegidas.add(id);
    });
  }

  /// Marca todas las de [fotos], o las desmarca si ya lo estaban todas.
  void _alternarTodas(List<Evidencia> fotos) {
    final ids = fotos.map((e) => e.id);
    HapticFeedback.selectionClick();
    setState(() {
      if (_elegidas.containsAll(ids)) {
        _elegidas.removeAll(ids);
      } else {
        _elegidas.addAll(ids);
      }
    });
  }

  Future<void> _compartir(List<Evidencia> todas) async {
    final fotos = todas.where((e) => _elegidas.contains(e.id));
    final enviadas = await compartirEvidencias(context, ref, fotos);
    if (enviadas) _salir();
  }

  @override
  Widget build(BuildContext context) {
    final evidencias = ref.watch(evidenciasProvider(null));
    final todas = evidencias.value ?? const <Evidencia>[];
    // Una foto que otro borró mientras tanto deja de estar marcada.
    if (evidencias.hasValue) {
      final vivas = {for (final e in todas) e.id};
      _elegidas.removeWhere((id) => !vivas.contains(id));
    }
    final n = _elegidas.length;

    return PopScope(
      // Atrás cancela la selección en vez de salir de la app.
      canPop: !_eligiendo,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _salir();
      },
      child: Scaffold(
        appBar: _eligiendo
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancelar la selección',
                  icon: const Icon(PhosphorIconsBold.x),
                  onPressed: _salir,
                ),
                title: Text(switch (n) {
                  0 => 'Toca las fotos',
                  1 => '1 seleccionada',
                  _ => '$n seleccionadas',
                }),
                actions: [
                  TextButton(
                    onPressed: () => _alternarTodas(todas),
                    child: Text(
                      n > 0 && n == todas.length ? 'Ninguna' : 'Todas',
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              )
            : AppBar(
                title: const Text('Fotos y evidencias'),
                actions: [
                  if (todas.isNotEmpty)
                    IconButton(
                      tooltip: 'Seleccionar fotos para compartir',
                      icon: const Icon(PhosphorIconsBold.shareNetwork),
                      onPressed: () => setState(() => _eligiendo = true),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
        floatingActionButton: !_eligiendo
            ? FloatingActionButton.extended(
                onPressed: () => agregarEvidencia(
                  context,
                  ref,
                  reunionId: idDeFecha(DateTime.now()),
                ),
                icon: const Icon(PhosphorIconsBold.cameraPlus),
                label: const Text('Agregar foto'),
              )
            : n == 0
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _compartir(todas),
                icon: const Icon(PhosphorIconsBold.shareNetwork),
                label: Text(n == 1 ? 'Compartir 1 foto' : 'Compartir $n fotos'),
              ),
        body: evidencias.when(
          loading: () => const Cargando(),
          error: (e, _) => Vacio(
            icono: PhosphorIconsBold.cloudSlash,
            texto: mensajeDeError(e),
          ),
          data: (todas) {
            if (todas.isEmpty) {
              return const Vacio(
                icono: PhosphorIconsBold.images,
                texto:
                    'Aquí aparecerán las fotos de los que llegaron y de las '
                    'actividades de cada reunión. También puedes subir fotos '
                    'de actividades pasadas y ponerles su fecha.',
              );
            }
            // El id de la reunión es su fecha (aaaa-mm-dd).
            final porReunion = <String, List<Evidencia>>{};
            for (final e in todas) {
              (porReunion[e.reunionId] ??= []).add(e);
            }
            final dias = porReunion.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                for (final dia in dias) ...[
                  TituloSeccion(
                    fechaLargaConAnio(DateTime.tryParse(dia) ?? DateTime.now()),
                    // Marca de un toque todas las fotos de esa actividad.
                    accion: !_eligiendo
                        ? null
                        : TextButton(
                            onPressed: () => _alternarTodas(porReunion[dia]!),
                            child: Text(
                              _elegidas.containsAll(
                                    porReunion[dia]!.map((e) => e.id),
                                  )
                                  ? 'Quitar'
                                  : 'Todo el día',
                            ),
                          ),
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final e in porReunion[dia]!)
                        _Casilla(
                          evidencia: e,
                          eligiendo: _eligiendo,
                          elegida: _elegidas.contains(e.id),
                          alTocar: () => _eligiendo
                              ? _alternar(e.id)
                              : abrir(context, _VisorEvidencia(e)),
                          alMantener: () => _alternar(e.id),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Una foto de la galería. Al seleccionar muestra su marca en la esquina y
/// la foto elegida se encoge un poco dentro de su casilla.
class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.evidencia,
    required this.eligiendo,
    required this.elegida,
    required this.alTocar,
    required this.alMantener,
  });

  final Evidencia evidencia;
  final bool eligiendo;
  final bool elegida;
  final VoidCallback alTocar;
  final VoidCallback alMantener;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: eligiendo ? elegida : null,
    label: [
      'Foto del ${fechaLargaConAnio(evidencia.dia)}',
      if (evidencia.descripcion.isNotEmpty) evidencia.descripcion,
    ].join(', '),
    child: GestureDetector(
      onTap: alTocar,
      onLongPress: alMantener,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: elegida ? Colores.nube : Colores.blanco,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedPadding(
              duration: sinMovimiento(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              padding: EdgeInsets.all(elegida ? 9 : 0),
              // La miniatura viaja hasta el visor.
              child: Hero(
                tag: 'evidencia-${evidencia.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(elegida ? 8 : 12),
                  child: _Miniatura(evidencia),
                ),
              ),
            ),
          ),
          if (eligiendo)
            Positioned(
              top: 5,
              right: 5,
              child: ExcludeSemantics(
                child: elegida
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colores.blanco,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIconsFill.checkCircle,
                          color: Colores.azul,
                          size: 26,
                        ),
                      )
                    : Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colores.blanco, width: 2),
                        ),
                      ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Miniatura extends StatelessWidget {
  const _Miniatura(this.evidencia, {this.ajuste = BoxFit.cover});

  final Evidencia evidencia;
  final BoxFit ajuste;

  @override
  Widget build(BuildContext context) {
    final bytes = evidencia.miniatura;
    return bytes == null
        ? const ColoredBox(
            color: Colores.nube,
            child: Center(child: Icon(PhosphorIconsBold.imageBroken)),
          )
        : Image.memory(bytes, fit: ajuste, gaplessPlayback: true);
  }
}

class _VisorEvidencia extends ConsumerWidget {
  const _VisorEvidencia(this.evidencia);

  final Evidencia evidencia;

  /// Corrige cuándo fue la actividad y qué se hizo.
  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final descripcion = TextEditingController(text: evidencia.descripcion);
    var dia = evidencia.dia;
    final guardar = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, actualizar) => AlertDialog(
          title: const Text('Editar foto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final elegido = await elegirDiaDeActividad(c, dia);
                    if (elegido != null) actualizar(() => dia = elegido);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '¿Cuándo fue?',
                      suffixIcon: Icon(PhosphorIconsBold.calendar),
                    ),
                    child: Text(
                      fechaLargaConAnio(dia),
                      style: const TextStyle(
                        color: Colores.tinta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcion,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 140,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: '¿Qué se hizo? (opcional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 46)),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (guardar != true || !context.mounted) return;
    final ok = await intentar(
      context,
      () => ref
          .read(repoProvider)
          .editarEvidencia(
            ref.read(capIdProvider)!,
            evidencia.id,
            dia: dia,
            descripcion: descripcion.text,
          ),
    );
    if (ok && context.mounted) {
      avisar(context, 'Foto actualizada.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(sesionProvider).value?.uid;
    final puedeBorrar =
        ref.watch(esLiderProvider) || evidencia.subidaPor == uid;
    // Mientras llega la foto grande se muestra la miniatura ampliada.
    final grande = ref.watch(fotoEvidenciaProvider(evidencia.id)).value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(fechaCorta(evidencia.dia)),
        actions: [
          IconButton(
            tooltip: 'Compartir foto',
            icon: const Icon(PhosphorIconsBold.shareNetwork),
            onPressed: () => compartirEvidencias(context, ref, [evidencia]),
          ),
          // Quien la subió o el líder corrigen la fecha y la descripción.
          if (puedeBorrar)
            IconButton(
              tooltip: 'Editar fecha y descripción',
              icon: const Icon(PhosphorIconsBold.pencilSimple),
              onPressed: () => _editar(context, ref),
            ),
          if (puedeBorrar)
            IconButton(
              tooltip: 'Borrar foto',
              icon: const Icon(PhosphorIconsBold.trash),
              onPressed: () async {
                final si = await confirmar(
                  context,
                  titulo: 'Borrar foto',
                  texto: 'La foto se borrará para todo el capítulo.',
                  aceptar: 'Borrar',
                );
                if (!si || !context.mounted) return;
                final ok = await intentar(
                  context,
                  () => ref
                      .read(repoProvider)
                      .borrarEvidencia(ref.read(capIdProvider)!, evidencia),
                );
                if (ok && context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Hero(
                  tag: 'evidencia-${evidencia.id}',
                  child: grande == null
                      ? _Miniatura(evidencia, ajuste: BoxFit.contain)
                      : Image.memory(
                          grande,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                [
                  if (evidencia.descripcion.isNotEmpty) evidencia.descripcion,
                  'Subida por ${evidencia.subidaPorNombre}',
                ].join('\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
