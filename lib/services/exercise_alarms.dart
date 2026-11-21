import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:timezone/timezone.dart' as tz;

class ExerciseAlarms {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<bool>? _ready;
  static bool _asked = false;
  static final _running = <int, (DateTime, String)>{};

  static const _icon = 'ic_stat_timer';

  static const _alarm = NotificationDetails(
    android: AndroidNotificationDetails(
      'exercise_alarm',
      'Alarma de ejercicio',
      channelDescription: 'Notificaciones de alarmas programadas para entrenar',
      icon: _icon,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: true,
    ),
  );

  static const _runningNotification = NotificationDetails(
    android: AndroidNotificationDetails(
      'exercise_alarm_running',
      'Alarma en curso',
      channelDescription: 'Muestra la cuenta regresiva de alarmas de ejercicio',
      icon: _icon,
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      ongoing: true,
      onlyAlertOnce: true,
      channelShowBadge: false,
      usesChronometer: true,
      chronometerCountDown: true,
      autoCancel: true,
    ),
  );

  static Future<bool> init() => _ready ??= _start();

  static Future<bool> _start() async {
    if (!Platform.isAndroid) return false;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings(_icon)),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
      await _loadAndScheduleAlarms();
    } catch (e) {
      debugPrint('No se pudieron inicializar las alarmas: $e');
      return false;
    }
    return true;
  }

  static Future<void> _handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final alarmId = int.tryParse(payload);
      if (alarmId == null) return;

      // Cancelar notificaciones pendientes de esta alarma
      await cancelAlarm(alarmId);

      // Buscar la siguiente alarma
      await _scheduleNextAlarm();
    } catch (e) {
      debugPrint('Error al manejar respuesta de notificación: $e');
    }
  }

  static Future<void> _scheduleNextAlarm() async {
    try {
      final alarms = await Db.getAlarms();
      final now = DateTime.now();
      DateTime? nextAlarmTime;
      String? nextAlarmName;
      int? nextAlarmId;

      // Buscar la próxima alarma
      for (final alarm in alarms) {
        final enabled = (alarm['enabled'] as int?) ?? 1;
        if (enabled == 0) continue;

        final alarmTime = alarm['alarm_time'] as String;
        final daysStr = alarm['days'] as String?;
        final name = alarm['name'] as String;
        final alarmId = alarm['id'] as int;

        final parts = alarmTime.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        // Calcular próxima ocurrencia de esta alarma
        var alarmDateTime = DateTime(now.year, now.month, now.day, hour, minute);

        // Si ya pasó hoy, buscar mañana o próximo día válido
        if (alarmDateTime.isBefore(now)) {
          final daysList = Db.parseDays(daysStr);

          if (daysList.isEmpty) {
            // Sin días específicos: próximo día a la misma hora
            alarmDateTime = alarmDateTime.add(const Duration(days: 1));
          } else {
            // Con días específicos: buscar el próximo día válido
            var searchDate = now.add(const Duration(days: 1));
            var found = false;
            for (var i = 0; i < 7; i++) {
              if (daysList.contains(searchDate.weekday)) {
                alarmDateTime = DateTime(
                  searchDate.year,
                  searchDate.month,
                  searchDate.day,
                  hour,
                  minute,
                );
                found = true;
                break;
              }
              searchDate = searchDate.add(const Duration(days: 1));
            }
            if (!found) continue;
          }
        }

        // Comparar y encontrar la más próxima
        if (nextAlarmTime == null || alarmDateTime.isBefore(nextAlarmTime)) {
          nextAlarmTime = alarmDateTime;
          nextAlarmName = name;
          nextAlarmId = alarmId;
        }
      }

      // Si encontramos una próxima alarma, programar notificación solo si es HOY y faltan ≤30 min
      if (nextAlarmTime != null && nextAlarmName != null && nextAlarmId != null) {
        final timeUntilAlarm = nextAlarmTime.difference(now);
        final isToday = nextAlarmTime.year == now.year &&
            nextAlarmTime.month == now.month &&
            nextAlarmTime.day == now.day;

        // Solo programar si es HOY y faltan 30 minutos o menos
        if (isToday && timeUntilAlarm.inMinutes <= 30 && timeUntilAlarm.isNegative == false) {
          final before30Id = nextAlarmId * 1000 + 1;
          final before30Time = nextAlarmTime.subtract(const Duration(minutes: 30));

          if (before30Time.isAfter(now) || before30Time.difference(now).inSeconds > -5) {
            await _scheduleNotification(
              before30Id,
              before30Time,
              'Próxima alarma en ${timeUntilAlarm.inMinutes} minutos',
              'Tu entrenamiento "$nextAlarmName" comienza en ${timeUntilAlarm.inMinutes} minutos',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error al programar próxima alarma: $e');
    }
  }

  static Future<void> _ensurePermission() async {
    if (_asked) return;
    _asked = true;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> _loadAndScheduleAlarms() async {
    try {
      final alarms = await Db.getAlarms();
      final now = DateTime.now();

      for (final alarm in alarms) {
        final enabled = (alarm['enabled'] as int?) ?? 1;
        if (enabled == 0) continue;

        final alarmTime = alarm['alarm_time'] as String;
        final daysStr = alarm['days'] as String?;
        final name = alarm['name'] as String;
        final alarmId = alarm['id'] as int;

        final daysList = Db.parseDays(daysStr);
        final shouldAlarmToday = daysList.isEmpty || daysList.contains(now.weekday);

        if (shouldAlarmToday) {
          await _scheduleAlarmNotifications(alarmId, alarmTime, name);
        }
      }
    } catch (e) {
      debugPrint('Error al cargar alarmas: $e');
    }
  }

  static Future<void> _scheduleAlarmNotifications(int alarmId, String alarmTime, String name) async {
    final parts = alarmTime.split(':');
    if (parts.length != 2) return;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = DateTime.now();
    var alarmDateTime = DateTime(now.year, now.month, now.day, hour, minute);

    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }

    // Mostrar contador en la barra de notificaciones
    final runnerId = alarmId * 1000;
    _running[alarmId] = (alarmDateTime, name);

    final timeUntilAlarm = alarmDateTime.difference(now);
    if (timeUntilAlarm.isNegative) return;

    try {
      await _plugin.show(
        id: runnerId,
        title: 'Alarma: $name',
        body: 'Falta ${timeUntilAlarm.inMinutes} min',
        notificationDetails: _runningNotification,
        payload: alarmId.toString(),
      ).then((_) {
        // Ahora programar las notificaciones
        _scheduleAlarmNotificationsWithDetails(alarmId, alarmDateTime, name);
      });
    } catch (e) {
      debugPrint('Error al mostrar contador: $e');
      _scheduleAlarmNotificationsWithDetails(alarmId, alarmDateTime, name);
    }
  }

  static Future<void> _scheduleAlarmNotificationsWithDetails(int alarmId, DateTime alarmDateTime, String name) async {
    final now = DateTime.now();

    // Notificación 15 minutos antes
    final before15Id = alarmId * 100 + 1;
    final before15Time = alarmDateTime.subtract(const Duration(minutes: 15));
    if (before15Time.isAfter(now)) {
      await _scheduleNotification(
        before15Id,
        before15Time,
        'Preparación',
        'Casi es hora de hacer ejercicio preparate',
      );
    }

    // Notificación a la hora exacta CON BOTONES
    final exactId = alarmId * 100 + 2;
    if (alarmDateTime.isAfter(now)) {
      await _scheduleNotificationWithActions(
        exactId,
        alarmDateTime,
        'Alarma de ejercicio',
        'Es hora de hacer ejercicio',
        alarmId,
      );
    }

    // Notificación 5 minutos después con botón de posponer
    final after5Id = alarmId * 100 + 3;
    final after5Time = alarmDateTime.add(const Duration(minutes: 5));
    await _scheduleNotificationWithAction(
      after5Id,
      after5Time,
      'Vas tarde para hacer ejercicio',
      'Posponer 10 minutos',
      alarmId,
    );
  }

  static Future<void> _scheduleNotificationWithActions(
    int id,
    DateTime at,
    String title,
    String body,
    int alarmId,
  ) async {
    final when = at.isAfter(DateTime.now()) ? at : DateTime.now().add(const Duration(seconds: 1));
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'exercise_alarm',
            'Alarma de ejercicio',
            channelDescription: 'Notificaciones de alarmas programadas para entrenar',
            icon: _icon,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            autoCancel: true,
            actions: [
              AndroidNotificationAction(
                'snooze_${alarmId}_5',
                '⏰ Posponer 5 min',
                cancelNotification: false,
              ),
              AndroidNotificationAction(
                'cancel_$alarmId',
                '✕ Cancelar',
                cancelNotification: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
        payload: alarmId.toString(),
      );
    } catch (e) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: _alarm,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
          payload: alarmId.toString(),
        );
      } catch (e) {
        debugPrint('No se pudo programar la alarma con acciones: $e');
      }
    }
  }

  static Future<void> _scheduleNotificationWithAction(
    int id,
    DateTime at,
    String body,
    String actionLabel,
    int alarmId,
  ) async {
    final when = at.isAfter(DateTime.now()) ? at : DateTime.now().add(const Duration(seconds: 1));
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'exercise_alarm',
            'Alarma de ejercicio',
            channelDescription: 'Notificaciones de alarmas programadas para entrenar',
            icon: _icon,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            autoCancel: true,
            actions: [
              AndroidNotificationAction(
                'snooze_$alarmId',
                actionLabel,
                cancelNotification: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: 'Vas tarde para hacer ejercicio',
        body: body,
      );
    } catch (e) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: _alarm,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Vas tarde para hacer ejercicio',
          body: body,
        );
      } catch (e) {
        debugPrint('No se pudo programar la alarma con acción: $e');
      }
    }
  }

  static Future<void> _scheduleNotification(int id, DateTime at, String title, String body) async {
    final when = at.isAfter(DateTime.now()) ? at : DateTime.now().add(const Duration(seconds: 1));
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: _alarm,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: _alarm,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
        );
      } catch (e) {
        debugPrint('No se pudo programar la alarma: $e');
      }
    }
  }

  static Future<void> scheduleAlarm(int alarmId, String alarmTime, String name) async {
    if (!await init()) return;
    await _ensurePermission();
    await _scheduleAlarmNotifications(alarmId, alarmTime, name);
  }

  static Future<void> cancelAlarm(int alarmId) async {
    if (!await init()) return;
    final runnerId = alarmId * 1000;
    final before15Id = alarmId * 100 + 1;
    final exactId = alarmId * 100 + 2;
    final after5Id = alarmId * 100 + 3;
    final before30NextId = alarmId * 1000 + 1;
    _running.remove(alarmId);
    try {
      await _plugin.cancel(id: runnerId);
      await _plugin.cancel(id: before15Id);
      await _plugin.cancel(id: exactId);
      await _plugin.cancel(id: after5Id);
      await _plugin.cancel(id: before30NextId);
    } catch (_) {}
  }

  static Future<void> refreshAlarms() async {
    if (!await init()) return;
    try {
      await _plugin.cancelAll();
      await _loadAndScheduleAlarms();
    } catch (e) {
      debugPrint('Error al refrescar alarmas: $e');
    }
  }
}
