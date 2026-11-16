import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/cumpleanos.dart';
import '../models/modelos.dart';

/// Avisos de cumpleaños. Cada teléfono programa los suyos con la lista de
/// muchachos que ya tiene sincronizada, así que no hace falta un servidor
/// ni conexión el día del cumpleaños.
abstract final class Avisos {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;
  static String? _ultimaFirma;

  /// Hora local a la que llega el aviso.
  static const hora = 8;

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'cumpleanos',
      'Cumpleaños',
      channelDescription: 'Avisa cuando un muchacho del capítulo cumple años',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_aviso',
    ),
  );

  static Future<bool> _iniciar() async {
    if (_listo) return true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_aviso'),
        ),
      );
      _listo = true;
    } catch (_) {
      // Sin avisos la app funciona igual.
    }
    return _listo;
  }

  /// Pide permiso para mostrar notificaciones (Android 13 o más reciente).
  static Future<void> pedirPermiso() async {
    if (!await _iniciar()) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Deja programado un aviso anual por cada muchacho con fecha de
  /// nacimiento. Se llama cada vez que cambia la lista de muchachos.
  static Future<void> programarCumples(
    List<Alumno> alumnos,
    String capitulo,
  ) async {
    final conFecha = alumnos.where((a) => a.fechaNac != null).take(200).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final firma = [
      capitulo,
      for (final a in conFecha)
        '${a.id}|${a.nombre}|${a.fechaNac!.month}-${a.fechaNac!.day}',
    ].join(';');
    if (firma == _ultimaFirma) return;
    if (!await _iniciar()) return;
    try {
      await _plugin.cancelAll();
      final ahora = DateTime.now();
      for (final (i, a) in conFecha.indexed) {
        var dia = proximoCumple(a.fechaNac!, ahora);
        var momento = DateTime(dia.year, dia.month, dia.day, hora);
        // Si hoy es su cumpleaños y ya pasó la hora, el siguiente es en un año.
        if (!momento.isAfter(ahora)) {
          dia = cumpleEn(a.fechaNac!, dia.year + 1);
          momento = DateTime(dia.year, dia.month, dia.day, hora);
        }
        await _plugin.zonedSchedule(
          id: i + 1,
          title: 'Hoy cumple años ${a.nombre} 🎂',
          body: capitulo.isEmpty
              ? 'Felicítalo de parte del capítulo.'
              : 'Felicítalo de parte del capítulo $capitulo.',
          // El mismo instante expresado en UTC: no hace falta saber el
          // nombre de la zona horaria del teléfono.
          scheduledDate: tz.TZDateTime.from(momento, tz.UTC),
          notificationDetails: _detalles,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // Se repite cada año en el mismo día y hora.
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      }
      _ultimaFirma = firma;
    } catch (_) {
      // Si el sistema no deja programar, se intenta en el siguiente cambio.
    }
  }

  /// Quita todos los avisos (al cerrar sesión o salir del capítulo).
  static Future<void> cancelar() async {
    _ultimaFirma = null;
    if (!await _iniciar()) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
