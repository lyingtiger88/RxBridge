import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// OS-scheduled reminders, never containing private medical results.
/// The caller must request permission with an explicit user gesture.
class CareReminders {
  CareReminders._();
  static final CareReminders instance = CareReminders._();
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const firstId = 71300;
  static const slotCount = 8;

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

  Future<bool> activateDailyGlucoseReminders(List<TimeOfDay> times) async {
    if(!Platform.isAndroid && !Platform.isIOS) return false;
    if(times.isEmpty || times.length > slotCount) return false;
    await initialize();
    bool permitted = true;
    if(Platform.isAndroid) {
      permitted = await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission() ?? false;
    } else if(Platform.isIOS) {
      permitted = await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert:true,badge:false,sound:true) ?? false;
    }
    if(!permitted) return false;
    await cancelGlucoseReminders();
    final now=tz.TZDateTime.now(tz.local);
    for(var i=0;i<times.length;i++) {
      final time=times[i];
      var next=tz.TZDateTime(tz.local,now.year,now.month,now.day,time.hour,time.minute);
      if(!next.isAfter(now)) next=tz.TZDateTime(tz.local,now.year,now.month,now.day+1,time.hour,time.minute);
      await plugin.zonedSchedule(
        firstId+i,
        title:'یادآوری پل سلامت',
        body:'زمان ثبت اندازه‌گیری برنامه‌ریزی‌شده فرا رسیده است.',
        scheduledDate: next,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rxbridge_care_reminders','یادآورهای پایش',
            channelDescription:'یادآورهای عمومی ثبت اندازه‌گیری',
            importance: Importance.high, priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
    return true;
  }

  Future<void> cancelGlucoseReminders() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await initialize();
    for(var i=0;i<slotCount;i++) {await plugin.cancel(id:firstId+i);}
  }
}
