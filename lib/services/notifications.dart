import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Temporizadores en segundo plano: mientras corren se ve un contador en la barra de notificaciones,
/// y al terminar llega un aviso programado en Android, que suena aunque la app esté cerrada o la pantalla apagada.
class TimerAlerts {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false, _asked = false;

  // Un id por temporizador: el contador visible y el aviso final.
  static const restRunning = 1, restDone = 2, cardioRunning = 3, cardioDone = 4;

  static const _icon = 'ic_stat_timer';

  /// Aviso al terminar: con sonido, vibración y visible sobre otras apps.
  static const _done = NotificationDetails(
    android: AndroidNotificationDetails(
      'timer_done',
      'Temporizador terminado',
      channelDescription: 'Avisa cuando termina el descanso o llegas a tu meta de cardio',
      icon: _icon,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: true,
    ),
  );

  static Future<bool> _init() async {
    if (!Platform.isAndroid) return false;
    if (_ready) return true;
    try {
      await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings(_icon)));
      _ready = true;
    } catch (e) {
      debugPrint('No se pudieron iniciar las notificaciones: $e');
    }
    return _ready;
  }

  /// Pide permiso de notificaciones (Android 13+) la primera vez que se usa un temporizador.
  static Future<void> _ensurePermission() async {
    if (_asked) return;
    _asked = true;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Contador en la barra: cuenta hacia atrás hasta [end], o hacia arriba desde [start].
  static Future<void> showRunning(int id, String title, String body, {DateTime? end, DateTime? start}) async {
    if (!await _init()) return;
    await _ensurePermission();
    final left = end?.difference(DateTime.now()).inMilliseconds;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'timer_running',
            'Temporizador en curso',
            channelDescription: 'Muestra el tiempo del descanso o del cardio mientras corre',
            icon: _icon,
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
            ongoing: true,
            onlyAlertOnce: true,
            channelShowBadge: false,
            // El sistema actualiza el reloj solo, sin despertar la app.
            usesChronometer: true,
            chronometerCountDown: end != null,
            when: (end ?? start ?? DateTime.now()).millisecondsSinceEpoch,
            timeoutAfter: left == null ? null : (left < 0 ? 0 : left),
          ),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar el temporizador: $e');
    }
  }

  /// Programa el aviso final a la hora exacta [at].
  static Future<void> scheduleDone(int id, DateTime at, String title, String body) async {
    if (!await _init()) return;
    await _ensurePermission();
    final when = at.isAfter(DateTime.now()) ? at : DateTime.now().add(const Duration(seconds: 1));
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: _done,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      // Sin permiso de alarma exacta: se programa aproximada (puede llegar unos segundos tarde).
      try {
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: _done,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
        );
      } catch (e) {
        debugPrint('No se pudo programar el aviso: $e');
      }
    }
  }

  static Future<void> cancel(List<int> ids) async {
    if (!await _init()) return;
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {}
    }
  }
}
