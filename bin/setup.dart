import 'dart:io';

import 'package:dynamic_notification_kit/src/setup/setup_runner.dart';

/// dart run dynamic_notification_kit:setup [--android] [--ios] [--widget]
///   [--dry-run] [--revert] [--update] [--check] [--frequent-updates] [--project <dir>]
Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('''
dart run dynamic_notification_kit:setup [options]

  --android            patch Android manifest + gradle
  --ios                patch Info.plist + Podfile
  --widget             add the iOS Live Activity widget extension
  (no platform flag = all three)
  --dry-run            print changes, write nothing
  --check              exit 1 if configuration is missing (CI)
  --revert             restore .bak backups
  --update             overwrite ios/DeliveryLiveActivity files with the package's
                       latest widget templates (your copy is kept as .user.bak)
  --frequent-updates   also set NSSupportsLiveActivitiesFrequentUpdates
  --project <dir>      app directory (default: .)''');
    return;
  }
  exit(await SetupRunner(SetupOptions.parse(args)).run());
}
