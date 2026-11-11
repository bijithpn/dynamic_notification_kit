import 'dart:io';

import 'package:dynamic_notification_kit/src/setup/patchers.dart';
import 'package:dynamic_notification_kit/src/setup/setup_runner.dart';
import 'package:flutter_test/flutter_test.dart';

const manifest =
    '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="x"/>
</manifest>''';

const plist = '''<?xml version="1.0"?>
<plist version="1.0">
<dict>
\t<key>CFBundleName</key>
\t<string>x</string>
</dict>
</plist>''';

void main() {
  group('patchManifest', () {
    test('adds both permissions once (idempotent)', () {
      final r = patchManifest(manifest);
      expect(r.changes, hasLength(2));
      expect(r.text, contains('POST_PROMOTED_NOTIFICATIONS'));
      expect(patchManifest(r.text).changed, false);
    });
    test('malformed throws', () {
      expect(() => patchManifest('garbage'), throwsA(isA<SetupException>()));
    });
  });

  group('patchGradle', () {
    test('kotlin DSL flutter.compileSdkVersion -> maxOf', () {
      final r = patchGradle(
        'android {\n    compileSdk = flutter.compileSdkVersion\n}',
      );
      expect(r.text, contains('maxOf(flutter.compileSdkVersion, 36)'));
      expect(patchGradle(r.text).changed, false);
    });
    test('groovy numeric compileSdk and low minSdk', () {
      final r = patchGradle(
        'android {\n    compileSdkVersion 33\n    defaultConfig { minSdkVersion 16 }\n}',
      );
      expect(r.text, contains('compileSdk 36'));
      expect(r.text, contains('minSdkVersion 21'));
    });
    test('already high is untouched', () {
      expect(
        patchGradle('android {\n    compileSdk = 36\n    minSdk = 24\n}')
            .changed,
        false,
      );
    });
    test('missing compileSdk throws', () {
      expect(() => patchGradle('android { }'), throwsA(isA<SetupException>()));
    });
  });

  group('patchInfoPlist', () {
    test('adds key, idempotent', () {
      final r = patchInfoPlist(plist);
      expect(r.text, contains('NSSupportsLiveActivities'));
      expect(patchInfoPlist(r.text).changed, false);
    });
    test('flips false to true', () {
      final r = patchInfoPlist(
        plist.replaceFirst(
          '</dict>',
          '<key>NSSupportsLiveActivities</key>\n<false/>\n</dict>',
        ),
      );
      expect(
        RegExp(r'NSSupportsLiveActivities</key>\s*<true/>').hasMatch(r.text),
        true,
      );
    });
    test('frequent updates opt-in', () {
      expect(
        patchInfoPlist(plist, frequentUpdates: true).text,
        contains('NSSupportsLiveActivitiesFrequentUpdates'),
      );
    });
    test('malformed throws', () {
      expect(() => patchInfoPlist('nope'), throwsA(isA<SetupException>()));
    });
  });

  group('patchPodfile', () {
    test('uncomments and raises', () {
      final r = patchPodfile("# platform :ios, '12.0'\nfoo");
      expect(r.text, startsWith("platform :ios, '15.0'"));
    });
    test('leaves higher platform', () {
      expect(patchPodfile("platform :ios, '17.0'").changed, false);
    });
  });

  group('SetupRunner on fixture project', () {
    late Directory d;
    setUp(() {
      d = Directory.systemTemp.createTempSync('dnk_setup');
      File('${d.path}/android/app/src/main/AndroidManifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(manifest);
      File('${d.path}/android/app/build.gradle.kts')
          .writeAsStringSync('android {\n    compileSdk = 34\n}');
      File('${d.path}/ios/Runner/Info.plist')
        ..createSync(recursive: true)
        ..writeAsStringSync(plist);
      File('${d.path}/ios/Podfile')
          .writeAsStringSync("platform :ios, '13.0'\n");
    });
    tearDown(() => d.deleteSync(recursive: true));

    SetupRunner r(List<String> a) => SetupRunner(
      SetupOptions.parse([...a, '--project', d.path]),
      log: (_) {},
    );

    test('check fails, setup fixes, check passes, revert restores', () async {
      expect(await r(['--android', '--ios', '--check']).run(), 1);
      expect(await r(['--android', '--ios']).run(), 0);
      expect(await r(['--android', '--ios', '--check']).run(), 0);
      expect(File('${d.path}/ios/Podfile.bak').existsSync(), true);
      expect(await r(['--revert']).run(), 0);
      expect(
        File('${d.path}/android/app/src/main/AndroidManifest.xml')
            .readAsStringSync(),
        manifest,
      );
    });

    test('dry run writes nothing', () async {
      await r(['--android', '--dry-run']).run();
      expect(
        File('${d.path}/android/app/src/main/AndroidManifest.xml')
            .readAsStringSync(),
        manifest,
      );
    });

    test('malformed manifest gives clear error exit code', () async {
      File('${d.path}/android/app/src/main/AndroidManifest.xml')
          .writeAsStringSync('junk');
      expect(await r(['--android']).run(), 2);
    });
  });
}
