import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminders contain no diagnosis, medication name, or private result.
class CareReminders {
  CareReminders._();
  static final CareReminders instance = CareReminders._();
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const firstId = 71300;
  static const slotCount = 8;
  static const habitFirstId = 71400;
  static const habitSlotCount = 8;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    final name = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(name));
    await plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _initialized = true;
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      return await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      return await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    }
    return false;
  }

  Future<bool> activateDailyGlucoseReminders(List<TimeOfDay> times) async {
    if ((!Platform.isAndroid && !Platform.isIOS) || times.isEmpty || times.length > slotCount) return false;
    await initialize();
    if (!await _requestPermission()) return false;
    await cancelGlucoseReminders();
    await _schedule(times, firstId, 'زمان ثبت اندازه‌گیری برنامه‌ریزی‌شده فرا رسیده است.', slotCount);
    return true;
  }

  int _habitBaseId(String planId) {
    var hash = 0;
    for (final unit in planId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return habitFirstId + (hash % 10000) * habitSlotCount;
  }

  Future<bool> activateHabitReminders({required String planId, required List<String> times}) async {
    if ((!Platform.isAndroid && !Platform.isIOS) || times.isEmpty || times.length > habitSlotCount) return false;
    final parsed = <TimeOfDay>[];
    for (final raw in times) {
      final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(raw);
      if (match == null) return false;
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      if (hour > 23 || minute > 59) return false;
      parsed.add(TimeOfDay(hour: hour, minute: minute));
    }
    await initialize();
    if (!await _requestPermission()) return false;
    await cancelHabitReminders(planId);
    await _schedule(parsed, _habitBaseId(planId), 'زمان انجام برنامه روزانه شما فرا رسیده است.', habitSlotCount);
    return true;
  }

  Future<void> _schedule(List<TimeOfDay> times, int baseId, String body, int maxSlots) async {
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < times.length && i < maxSlots; i++) {
      final time = times[i];
      var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
      if (!next.isAfter(now)) {
        next = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, time.hour, time.minute);
      }
      await plugin.zonedSchedule(
        id: baseId + i,
        title: 'یادآوری پل سلامت',
        body: body,
        scheduledDate: next,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rxbridge_care_reminders', 'یادآورهای پل سلامت',
            channelDescription: 'یادآورهای عمومی و خصوصی‌نگهدار',
            importance: Importance.high, priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelHabitReminders(String planId) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await initialize();
    final base = _habitBaseId(planId);
    for (var i = 0; i < habitSlotCount; i++) {
      await plugin.cancel(id: base + i);
    }
  }

  Future<void> cancelGlucoseReminders() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await initialize();
    for (var i = 0; i < slotCount; i++) {
      await plugin.cancel(id: firstId + i);
    }
  }
}
