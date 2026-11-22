import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/compartir.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';

/// Lo que quedó listo para mandar y cuántas fotos no se pudieron bajar.
typedef _Preparadas = ({List<Evidencia> fotos, List<XFile> archivos});

/// Descarga las fotos elegidas en tamaño completo y abre el menú de Android
/// para mandarlas por WhatsApp o cualquier otra app. Devuelve si se
/// compartieron (falso si se canceló o no se pudo).
Future<bool> compartirEvidencias(
  BuildContext context,
  WidgetRef ref,
  Iterable<Evidencia> elegidas,
) async {
  final fotos = enOrdenParaCompartir(elegidas);
  if (fotos.isEmpty) return false;
  if (fotos.length > maximoAlCompartir) {
    avisar(
      context,
      'Se pueden compartir hasta $maximoAlCompartir fotos a la vez. '
      'Quita ${fotos.length - maximoAlCompartir} de la selección.',
    );
    return false;
  }
  final capitulo = ref.read(capituloProvider).value?.nombre ?? '';

  final listas = await showDialog<_Preparadas>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _Preparando(fotos),
  );
  // Null: se canceló mientras se preparaban.
  if (listas == null || !context.mounted) return false;

  final faltan = fotos.length - listas.fotos.length;
  if (listas.fotos.isEmpty) {
    avisar(
      context,
      fotos.length == 1
          ? 'No se pudo descargar la foto. Revisa tu conexión e inténtalo '
                'de nuevo.'
          : 'No se pudieron descargar las fotos. Revisa tu conexión e '
                'inténtalo de nuevo.',
    );
    return false;
  }
  if (faltan > 0) {
    final seguir = await confirmar(
      context,
      titulo: faltan == 1 ? 'Faltó una foto' : 'Faltaron $faltan fotos',
      texto:
          '${faltan == 1 ? 'Una foto no se pudo' : '$faltan fotos no se pudieron'} '
          'descargar; puede ser por la conexión. '
          '${listas.fotos.length == 1 ? '¿Compartir la que sí está lista?' : '¿Compartir las ${listas.fotos.length} que sí están listas?'}',
      aceptar: 'Compartir',
    );
    if (!seguir || !context.mounted) return false;
  }

  try {
    final texto = textoAlCompartir(
      listas.fotos,
      capitulo: capitulo,
      fecha: fechaLargaConAnio,
    );
    final resultado = await SharePlus.instance.share(
      ShareParams(
        files: listas.archivos,
        text: texto.isEmpty ? null : texto,
        subject: capitulo.isEmpty ? 'Fotos' : 'Fotos - $capitulo',
      ),
    );
    return resultado.status != ShareResultStatus.dismissed;
  } catch (_) {
    if (context.mounted) {
      avisar(context, 'No se pudo abrir el menú para compartir.');
    }
    return false;
  }
}

/// Carpeta temporal solo para lo que se comparte; se vacía en cada envío
/// para que las fotos no se queden acumuladas en el teléfono.
Future<Directory> _carpetaLimpia() async {
  final temporal = await getTemporaryDirectory();
  final carpeta = Directory('${temporal.path}/compartir');
  if (await carpeta.exists()) await carpeta.delete(recursive: true);
  return carpeta.create(recursive: true);
}

/// Diálogo que baja las fotos una por una y muestra cuántas van.
class _Preparando extends ConsumerStatefulWidget {
  const _Preparando(this.fotos);

  final List<Evidencia> fotos;

  @override
  ConsumerState<_Preparando> createState() => _PreparandoState();
}

class _PreparandoState extends ConsumerState<_Preparando> {
  int _hechas = 0;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  Future<void> _preparar() async {
    final repo = ref.read(repoProvider);
    final capId = ref.read(capIdProvider);
    final fotos = <Evidencia>[];
    final archivos = <XFile>[];
    // Tras el primer fallo de conexión ya no se espera al servidor por cada
    // foto: solo se toman las que el teléfono tiene guardadas.
    var soloGuardadas = false;
    try {
      final carpeta = await _carpetaLimpia();
      for (final (i, e) in widget.fotos.indexed) {
        // Si se canceló, el diálogo ya no existe.
        if (!mounted) return;
        Uint8List? bytes;
        if (capId != null) {
          try {
            bytes = await repo
                .fotoDeEvidencia(capId, e.id, soloGuardada: soloGuardadas)
                .timeout(const Duration(seconds: 25));
          } catch (_) {
            soloGuardadas = true;
          }
        }
        if (bytes != null) {
          final archivo = File('${carpeta.path}/${nombreDeArchivo(e, i + 1)}');
          await archivo.writeAsBytes(bytes, flush: true);
          fotos.add(e);
          archivos.add(XFile(archivo.path, mimeType: 'image/jpeg'));
        }
        if (!mounted) return;
        setState(() => _hechas = i + 1);
      }
    } catch (_) {
      // Sin espacio o sin acceso a la carpeta: se comparte lo que haya.
    }
    if (mounted) {
      Navigator.pop<_Preparadas>(context, (fotos: fotos, archivos: archivos));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.fotos.length;
    return AlertDialog(
      title: Text(total == 1 ? 'Preparando la foto' : 'Preparando las fotos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              // Con una sola foto no hay avance que mostrar.
              value: total == 1 ? null : _hechas / total,
              minHeight: 8,
              backgroundColor: Colores.nube,
              color: Colores.azul,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            total == 1
                ? 'Descargando en tamaño completo…'
                : '$_hechas de $total en tamaño completo',
            style: const TextStyle(color: Colores.textoSuave),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
