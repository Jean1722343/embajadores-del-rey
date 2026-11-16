import 'package:embajadores/core/version.dart';
import 'package:embajadores/services/actualizacion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compara versiones por números, no por letras', () {
    expect(esMasNueva('1.1.0', '1.0.0'), isTrue);
    expect(esMasNueva('v1.10.0', '1.9.3'), isTrue);
    expect(esMasNueva('2.0', '1.9.9'), isTrue);
    expect(esMasNueva('1.0.0', '1.0.0'), isFalse);
    expect(esMasNueva('1.0.0+7', '1.0.0+2'), isFalse);
    expect(esMasNueva('1.0.9', '1.1.0'), isFalse);
    expect(esMasNueva('cualquier cosa', '1.0.0'), isFalse);
  });

  Map<String, dynamic> publicada(String etiqueta, List<String> archivos) => {
    'tag_name': etiqueta,
    'assets': [
      for (final a in archivos)
        {'name': a, 'browser_download_url': 'https://ejemplo.test/$a'},
    ],
  };

  test('ofrece la versión publicada solo si es más nueva y trae un APK', () {
    final nueva = leerVersionPublicada(
      publicada('v1.2.0', ['notas.txt', 'EmbajadoresDelRey.apk']),
      '1.1.0',
    );
    expect(nueva?.version, '1.2.0');
    expect(nueva?.url, 'https://ejemplo.test/EmbajadoresDelRey.apk');

    expect(
      leerVersionPublicada(publicada('v1.1.0', ['app.apk']), '1.1.0'),
      isNull,
    );
    expect(
      leerVersionPublicada(publicada('v1.0.0', ['app.apk']), '1.1.0'),
      isNull,
    );
    expect(
      leerVersionPublicada(publicada('v1.2.0', ['notas.txt']), '1.1.0'),
      isNull,
    );
    expect(leerVersionPublicada('no es un mapa', '1.1.0'), isNull);
    expect(leerVersionPublicada({'message': 'Not Found'}, '1.1.0'), isNull);
  });
}
