import 'dart:io';

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
class PantallaEvidencias extends ConsumerWidget {
  const PantallaEvidencias({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidencias = ref.watch(evidenciasProvider(null));
    return Scaffold(
      appBar: AppBar(title: const Text('Fotos y evidencias')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => agregarEvidencia(
          context,
          ref,
          reunionId: idDeFecha(DateTime.now()),
        ),
        icon: const Icon(PhosphorIconsBold.cameraPlus),
        label: const Text('Agregar foto'),
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
          final dias = porReunion.keys.toList()..sort((a, b) => b.compareTo(a));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              for (final dia in dias) ...[
                TituloSeccion(
                  fechaLargaConAnio(DateTime.tryParse(dia) ?? DateTime.now()),
                ),
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final e in porReunion[dia]!)
                      GestureDetector(
                        onTap: () => abrir(context, _VisorEvidencia(e)),
                        // La miniatura viaja hasta el visor.
                        child: Hero(
                          tag: 'evidencia-${e.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _Miniatura(e),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
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
          // Solo quien la subió le corrige el día (así lo permite la regla).
          if (evidencia.subidaPor == uid)
            IconButton(
              tooltip: 'Cambiar la fecha',
              icon: const Icon(PhosphorIconsBold.calendar),
              onPressed: () async {
                final dia = await elegirDiaDeActividad(context, evidencia.dia);
                if (dia == null || !context.mounted) return;
                final ok = await intentar(
                  context,
                  () => ref
                      .read(repoProvider)
                      .cambiarDiaEvidencia(
                        ref.read(capIdProvider)!,
                        evidencia.id,
                        dia,
                      ),
                );
                if (ok && context.mounted) {
                  avisar(context, 'Fecha cambiada a ${fechaCorta(dia)}.');
                  Navigator.pop(context);
                }
              },
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
