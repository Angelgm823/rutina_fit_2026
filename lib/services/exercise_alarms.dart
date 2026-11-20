import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:timezone/timezone.dart' as tz;

class ExerciseAlarms {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<bool>? _ready;
  static bool _asked = false;

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

  static Future<bool> init() => _ready ??= _start();

  static Future<bool> _start() async {
    if (!Platform.isAndroid) return false;
    try {
      await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings(_icon)));
      await _loadAndScheduleAlarms();
    } catch (e) {
      debugPrint('No se pudieron inicializar las alarmas: $e');
      return false;
    }
    return true;
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
        final routineName = alarm['routine_name'] as String;
        final alarmId = alarm['id'] as int;

        final daysList = Db.parseDays(daysStr);
        final shouldAlarmToday = daysList.isEmpty || daysList.contains(now.weekday);

        if (shouldAlarmToday) {
          await _scheduleAlarmNotifications(alarmId, alarmTime, routineName);
        }
      }
    } catch (e) {
      debugPrint('Error al cargar alarmas: $e');
    }
  }

  static Future<void> _scheduleAlarmNotifications(int alarmId, String alarmTime, String routineName) async {
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

    // Notificación 30 minutos antes
    final before30Id = alarmId * 10 + 1;
    final before30Time = alarmDateTime.subtract(const Duration(minutes: 30));
    if (before30Time.isAfter(now)) {
      await _scheduleNotification(
        before30Id,
        before30Time,
        'Hora de entrenar en 30 minutos',
        'Prepara esos musculos que es hora de entrenar',
      );
    }

    // Notificación 5 minutos después
    final after5Id = alarmId * 10 + 2;
    final after5Time = alarmDateTime.add(const Duration(minutes: 5));
    await _scheduleNotification(
      after5Id,
      after5Time,
      'No olvides entrenar',
      'El ejercicio de hoy no se va a hacer solo',
    );
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

  static Future<void> scheduleAlarm(int alarmId, String alarmTime, String routineName) async {
    if (!await init()) return;
    await _ensurePermission();
    await _scheduleAlarmNotifications(alarmId, alarmTime, routineName);
  }

  static Future<void> cancelAlarm(int alarmId) async {
    if (!await init()) return;
    final before30Id = alarmId * 10 + 1;
    final after5Id = alarmId * 10 + 2;
    try {
      await _plugin.cancel(id: before30Id);
      await _plugin.cancel(id: after5Id);
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
