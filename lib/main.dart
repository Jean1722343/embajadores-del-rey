import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/manual.dart';
import 'features/tutorial.dart';
import 'firebase_options.dart';
import 'widgets/movimiento.dart';

Future<void> main() async {
  final motor = WidgetsFlutterBinding.ensureInitialized();
  // Android mantiene su pantalla de arranque hasta el primer cuadro de
  // Flutter. Se retiene ese cuadro hasta tener decodificado el escudo, para
  // que el relevo entre las dos pantallas no deje un hueco.
  motor.deferFirstFrame();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Caché local: se puede pasar lista sin señal y se sincroniza al volver.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    await initializeDateFormatting('es');
    await Preferencias.cargar();
    // Si el manual no carga, la app sigue: las metas se firman sin lista.
    await Manual.cargar().catchError((_) {});
    await Future.wait(imagenesDeArranque.map(_decodificar))
        .timeout(const Duration(seconds: 3), onTimeout: () => const []);
  } finally {
    motor.allowFirstFrame();
  }
  runApp(const ProviderScope(child: AppEmbajadores()));
}

/// Carga una imagen en la caché sin necesitar un BuildContext.
Future<void> _decodificar(ImageProvider imagen) {
  final listo = Completer<void>();
  final flujo = imagen.resolve(ImageConfiguration.empty);
  late final ImageStreamListener oyente;
  oyente = ImageStreamListener(
    (_, _) {
      if (!listo.isCompleted) listo.complete();
      flujo.removeListener(oyente);
    },
    onError: (_, _) {
      if (!listo.isCompleted) listo.complete();
    },
  );
  flujo.addListener(oyente);
  return listo.future;
}
