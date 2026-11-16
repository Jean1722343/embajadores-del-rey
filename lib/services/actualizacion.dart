import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/version.dart';

/// Repositorio público donde se publican las versiones de la app.
const repositorio = 'Jean1722343/embajadores-del-rey';

/// Una versión publicada más nueva que la instalada.
class Actualizacion {
  const Actualizacion({required this.version, required this.url});

  final String version;

  /// Enlace directo al APK.
  final String url;
}

/// Versión instalada, por ejemplo «1.1.0».
final versionInstaladaProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// Pregunta una vez, al abrir la app, si hay una versión más nueva.
final actualizacionProvider = FutureProvider<Actualizacion?>((ref) async {
  final instalada = await ref.watch(versionInstaladaProvider.future);
  return buscarActualizacion(instalada);
});

/// Consulta la última versión publicada en GitHub. Si no hay conexión, no
/// hay versiones o algo falla, devuelve null: la app sigue igual.
Future<Actualizacion?> buscarActualizacion(String instalada) async {
  final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final pedido = await cliente.getUrl(
      Uri.https('api.github.com', '/repos/$repositorio/releases/latest'),
    );
    pedido.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'embajadores-app');
    final respuesta = await pedido.close().timeout(const Duration(seconds: 10));
    if (respuesta.statusCode != 200) return null;
    final datos = jsonDecode(await respuesta.transform(utf8.decoder).join());
    return leerVersionPublicada(datos, instalada);
  } catch (_) {
    return null;
  } finally {
    cliente.close(force: true);
  }
}

/// Saca de la respuesta de GitHub la versión y el enlace del APK, solo si
/// es más nueva que la instalada.
Actualizacion? leerVersionPublicada(dynamic datos, String instalada) {
  if (datos is! Map) return null;
  final etiqueta = datos['tag_name'];
  if (etiqueta is! String || !esMasNueva(etiqueta, instalada)) return null;
  final archivos = datos['assets'];
  if (archivos is! List) return null;
  for (final a in archivos) {
    if (a is! Map) continue;
    final nombre = a['name'];
    final url = a['browser_download_url'];
    if (nombre is String && url is String && nombre.endsWith('.apk')) {
      return Actualizacion(
        version: etiqueta.replaceFirst(RegExp('^[vV]'), ''),
        url: url,
      );
    }
  }
  return null;
}
