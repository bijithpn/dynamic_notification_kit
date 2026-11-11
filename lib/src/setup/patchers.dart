/// Pure text patchers for native project files. No I/O, so they are unit
/// testable against fixtures. Each returns the (possibly unchanged) text.
library;

class SetupException implements Exception {
  SetupException(this.message);
  final String message;
  @override
  String toString() => 'SetupException: $message';
}

class PatchResult {
  const PatchResult(this.text, this.changes);
  final String text;

  /// Human-readable list of what changed; empty = already configured.
  final List<String> changes;
  bool get changed => changes.isNotEmpty;
}

const androidPermissions = [
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.POST_PROMOTED_NOTIFICATIONS',
];

PatchResult patchManifest(String xml) {
  final open = RegExp(r'<manifest\b[^>]*>').firstMatch(xml);
  if (open == null || !xml.contains('</manifest>')) {
    throw SetupException(
      'AndroidManifest.xml is malformed (no <manifest> element).',
    );
  }
  final changes = <String>[];
  final add = StringBuffer();
  for (final p in androidPermissions) {
    if (!xml.contains('android:name="$p"')) {
      add.write('\n    <uses-permission android:name="$p" />');
      changes.add('add <uses-permission $p>');
    }
  }
  if (changes.isEmpty) return PatchResult(xml, const []);
  final i = open.end;
  return PatchResult(
    xml.substring(0, i) + add.toString() + xml.substring(i),
    changes,
  );
}

PatchResult patchGradle(String gradle, {int compileSdk = 36, int minSdk = 21}) {
  if (!gradle.contains('android')) {
    throw SetupException('build.gradle has no android { } block.');
  }
  final isKts =
      gradle.contains('compileSdk =') || gradle.contains('namespace =');
  var text = gradle;
  final changes = <String>[];

  // compileSdk
  final cs = RegExp(r'compileSdk(?:Version)?\s*=?\s*([^\n]+)');
  final m = cs.firstMatch(text);
  if (m == null) {
    throw SetupException('Could not find compileSdk in build.gradle.');
  }
  final raw = m.group(1)!.trim();
  final n = int.tryParse(raw);
  String? replacement;
  if (n != null) {
    if (n < compileSdk) replacement = '$compileSdk';
  } else if (raw.contains('flutter.compileSdkVersion') &&
      !raw.contains('max')) {
    replacement = isKts
        ? 'maxOf(flutter.compileSdkVersion, $compileSdk)'
        : 'Math.max(flutter.compileSdkVersion, $compileSdk)';
  }
  if (replacement != null) {
    final eq = isKts ? 'compileSdk = ' : 'compileSdk ';
    text = text.replaceRange(m.start, m.end, '$eq$replacement');
    changes.add('set compileSdk >= $compileSdk');
  }

  // minSdk: only bump explicit numbers below the floor.
  final ms = RegExp(r'minSdk(?:Version)?\s*=?\s*(\d+)\b').firstMatch(text);
  if (ms != null && int.parse(ms.group(1)!) < minSdk) {
    text = text.replaceRange(
      ms.start,
      ms.end,
      isKts ? 'minSdk = $minSdk' : 'minSdkVersion $minSdk',
    );
    changes.add('raise minSdk to $minSdk');
  }
  return PatchResult(text, changes);
}

PatchResult patchInfoPlist(String plist, {bool frequentUpdates = false}) {
  if (!plist.contains('<dict>') || !plist.contains('</dict>')) {
    throw SetupException('Info.plist is malformed (no <dict>).');
  }
  var text = plist;
  final changes = <String>[];

  String set(String t, String key) {
    final re = RegExp('<key>$key</key>\\s*<(true|false)\\s*/>');
    final m = re.firstMatch(t);
    if (m == null) {
      final close = t.lastIndexOf('</dict>');
      changes.add('add $key = true');
      return '${t.substring(0, close)}\t<key>$key</key>\n\t<true/>\n${t.substring(close)}';
    }
    if (m.group(1) == 'false') {
      changes.add('flip $key to true');
      return t.replaceRange(m.start, m.end, '<key>$key</key>\n\t<true/>');
    }
    return t;
  }

  text = set(text, 'NSSupportsLiveActivities');
  if (frequentUpdates) {
    text = set(text, 'NSSupportsLiveActivitiesFrequentUpdates');
  }
  return PatchResult(text, changes);
}

PatchResult patchPodfile(String podfile, {String minIos = '15.0'}) {
  final re = RegExp(
    r"^\s*(#\s*)?platform\s*:ios\s*,\s*'([\d.]+)'",
    multiLine: true,
  );
  final m = re.firstMatch(podfile);
  if (m == null) {
    throw SetupException('Podfile has no platform :ios line.');
  }
  final commented = m.group(1) != null;
  final cur = double.tryParse(m.group(2)!) ?? 0;
  final want = double.parse(minIos);
  if (!commented && cur >= want) return PatchResult(podfile, const []);
  final line = "platform :ios, '$minIos'";
  return PatchResult(podfile.replaceRange(m.start, m.end, line), [
    "set Podfile platform to iOS $minIos",
  ]);
}

/// Names of problems for `--check` / diagnose, without changing anything.
List<String> checkManifest(String xml) => [
  for (final p in androidPermissions)
    if (!xml.contains('android:name="$p"')) 'AndroidManifest.xml missing $p',
];
