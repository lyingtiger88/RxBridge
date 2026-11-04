#!/usr/bin/env python3
"""Configure generated Android platform for opt-in RxBridge local reminders.

Flutter android/ and ios/ are generated during CI. Re-run after 'flutter create'.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
manifest = root / "android/app/src/main/AndroidManifest.xml"
gradle = root / "android/app/build.gradle.kts"

xml = manifest.read_text(encoding="utf-8")
if "android.permission.RECEIVE_BOOT_COMPLETED" not in xml:
    xml = xml.replace(
        "<application",
        '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />\n'
        "    <application",
        1,
    )
receivers = '''
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
'''
if "ScheduledNotificationReceiver" not in xml:
    if "</application>" not in xml:
        raise SystemExit("Missing Android application element")
    xml = xml.replace("</application>", receivers + "    </application>", 1)
manifest.write_text(xml, encoding="utf-8")

content = gradle.read_text(encoding="utf-8")
content, count = re.subn(r"compileSdk\s*=\s*flutter\.compileSdkVersion",
                        "compileSdk = 36", content, count=1)
if count != 1 and "compileSdk = 36" not in content:
    raise SystemExit("Unexpected compileSdk setup")
if "isCoreLibraryDesugaringEnabled" not in content:
    content = content.replace(
        "compileOptions {",
        "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
        1,
    )
if "isCoreLibraryDesugaringEnabled" not in content:
    raise SystemExit("Missing compileOptions in Gradle file")
content = content.replace(
    "sourceCompatibility = JavaVersion.VERSION_11",
    "sourceCompatibility = JavaVersion.VERSION_17",
).replace(
    "targetCompatibility = JavaVersion.VERSION_11",
    "targetCompatibility = JavaVersion.VERSION_17",
)
if "coreLibraryDesugaring(" not in content:
    content += '\n dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
gradle.write_text(content, encoding="utf-8")
print("Configured Android scheduled notifications with inexact alarms")
