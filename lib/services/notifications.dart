import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Temporizadores en segundo plano: mientras corren se ve un contador en la barra de notificaciones,
/// y al terminar llega un aviso programado en Android, que suena aunque la app esté cerrada o la pantalla apagada.
/// Con la app a la vista el aviso lo da la propia pantalla, así que el programado solo existe mientras está oculta.
class TimerAlerts {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<bool>? _ready;
  static bool _asked = false, _visible = true;

  /// Avisos finales pedidos por las pantallas: id → (hora, título, texto).
  static final _pending = <int, (DateTime, String, String)>{};

  // Un id por temporizador: el contador visible y el aviso final.
  static const restRunning = 1, restDone = 2, cardioRunning = 3, cardioDone = 4, plankRunning = 5, plankDone = 6;

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

  /// Se inicia una sola vez aunque varias llamadas lleguen a la vez. Llamarlo al abrir la app
  /// limpia lo que haya dejado una sesión anterior.
  static Future<bool> init() => _ready ??= _start();

  static Future<bool> _start() async {
    if (!Platform.isAndroid) return false;
    try {
      await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings(_icon)));
      // Al arrancar no hay temporizadores vivos: lo que quede (contador fijo en la barra o aviso pendiente)
      // es de una sesión que el sistema o el usuario cerraron.
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('No se pudieron iniciar las notificaciones: $e');
      return false;
    }
    AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    return true;
  }

  /// La app deja de verse: se programan los avisos que falten.
  static void _onHide() {
    _visible = false;
    final now = DateTime.now();
    _pending.removeWhere((_, p) => !p.$1.isAfter(now));
    _pending.forEach((id, p) => _schedule(id, p.$1, p.$2, p.$3));
  }

  /// La app vuelve a verse: la pantalla avisa sola, así que se quitan los programados que aún no sonaron.
  static Future<void> _onShow() async {
    _visible = true;
    final now = DateTime.now();
    _pending.removeWhere((_, p) => !p.$1.isAfter(now));
    for (final id in _pending.keys.toList()) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {}
    }
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
    if (!await init()) return;
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
            // 0 significaría "nunca se quita": si ya terminó, se quita casi de inmediato.
            timeoutAfter: left == null ? null : (left < 1 ? 1 : left),
          ),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar el temporizador: $e');
    }
  }

  /// Aviso final a la hora exacta [at]. Solo se programa en Android mientras la app está oculta.
  static Future<void> scheduleDone(int id, DateTime at, String title, String body) async {
    if (!await init()) return;
    await _ensurePermission();
    _pending[id] = (at, title, body);
    if (!_visible) await _schedule(id, at, title, body);
  }

  static Future<void> _schedule(int id, DateTime at, String title, String body) async {
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
    if (!await init()) return;
    for (final id in ids) {
      _pending.remove(id);
      try {
        await _plugin.cancel(id: id);
      } catch (_) {}
    }
  }
}
