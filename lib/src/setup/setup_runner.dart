import 'dart:io';
import 'dart:isolate';

import 'patchers.dart';

class SetupOptions {
  SetupOptions({
    this.android = false,
    this.ios = false,
    this.widget = false,
    this.dryRun = false,
    this.revert = false,
    this.check = false,
    this.frequentUpdates = false,
    this.update = false,
    this.projectDir = '.',
  });

  bool android, ios, widget;
  final bool dryRun, revert, check, frequentUpdates, update;
  final String projectDir;

  static SetupOptions parse(List<String> args) {
    bool has(String f) => args.contains(f);
    final any = has('--android') || has('--ios') || has('--widget');
    final dirIdx = args.indexOf('--project');
    return SetupOptions(
      android: !any || has('--android'),
      ios: !any || has('--ios'),
      widget: !any || has('--widget'),
      dryRun: has('--dry-run'),
      revert: has('--revert'),
      check: has('--check'),
      frequentUpdates: has('--frequent-updates'),
      update: has('--update'),
      projectDir: dirIdx >= 0 && dirIdx + 1 < args.length
          ? args[dirIdx + 1]
          : '.',
    );
  }
}

class SetupRunner {
  SetupRunner(this.o, {void Function(String)? log})
    : _log = log ?? stdout.writeln;
  final SetupOptions o;
  final void Function(String) _log;
  final done = <String>[];
  final manual = <String>[];
  final problems = <String>[];

  String _p(String rel) => '${o.projectDir}/$rel';

  Future<int> run() async {
    try {
      if (o.revert) return _revert();
      if (o.android) _android();
      if (o.ios) _ios();
      if (o.widget) await _widget();
    } on SetupException catch (e) {
      _log('✗ ${e.message}');
      return 2;
    }
    for (final d in done) {
      _log('✅ $d');
    }
    for (final m in manual) {
      _log('⚠️  $m');
    }
    for (final p in problems) {
      _log('✗ $p');
    }
    if (o.check) return problems.isEmpty ? 0 : 1;
    return 0;
  }

  /// Patches [rel] using [patch]; writes `.bak` once; honours dry-run/check.
  void _patchFile(String rel, PatchResult Function(String) patch) {
    final f = File(_p(rel));
    if (!f.existsSync()) {
      if (o.check) {
        problems.add('$rel not found');
      } else {
        manual.add('$rel not found — skipped');
      }
      return;
    }
    final before = f.readAsStringSync();
    final r = patch(before);
    if (!r.changed) {
      done.add('$rel already configured');
      return;
    }
    if (o.check) {
      problems.addAll(r.changes.map((c) => '$rel: needs "$c"'));
      return;
    }
    if (o.dryRun) {
      _log('--- $rel (dry run)');
      final old = before.split('\n').toSet();
      for (final l in r.text.split('\n')) {
        if (!old.contains(l)) _log('+ $l');
      }
      return;
    }
    final bak = File('${f.path}.bak');
    if (!bak.existsSync()) bak.writeAsStringSync(before);
    f.writeAsStringSync(r.text);
    done.add('$rel: ${r.changes.join('; ')}');
  }

  void _android() {
    _patchFile('android/app/src/main/AndroidManifest.xml', patchManifest);
    final kts = File(_p('android/app/build.gradle.kts')).existsSync();
    _patchFile(
      kts ? 'android/app/build.gradle.kts' : 'android/app/build.gradle',
      patchGradle,
    );
  }

  void _ios() {
    _patchFile(
      'ios/Runner/Info.plist',
      (s) => patchInfoPlist(s, frequentUpdates: o.frequentUpdates),
    );
    _patchFile('ios/Podfile', patchPodfile);
  }

  Future<String> _packageRoot() async {
    final uri = await Isolate.resolvePackageUri(
      Uri.parse(
        'package:dynamic_notification_kit/dynamic_notification_kit.dart',
      ),
    );
    if (uri == null) {
      throw SetupException('Cannot locate dynamic_notification_kit package.');
    }
    return File.fromUri(uri).parent.parent.path;
  }

  Future<void> _widget() async {
    const ext = 'DeliveryLiveActivity';
    final dest = Directory(_p('ios/$ext'));
    final proj = _p('ios/Runner.xcodeproj');
    if (!Directory(proj).existsSync()) {
      manual.add('ios/Runner.xcodeproj not found — skipped widget extension');
      return;
    }
    final pbx = File('$proj/project.pbxproj');
    final already =
        pbx.existsSync() && pbx.readAsStringSync().contains('$ext.appex');
    if (o.check) {
      if (!already) {
        problems.add('Widget extension "$ext" is not in Runner.xcodeproj');
      }
      return;
    }
    if (o.dryRun) {
      _log(
        '--- would copy ios_widget_template -> ios/$ext and add Xcode target',
      );
      return;
    }
    final root = await _packageRoot();
    final src = Directory('$root/ios_widget_template');
    dest.createSync(recursive: true);
    for (final f in src.listSync().whereType<File>()) {
      final t = File('${dest.path}/${f.uri.pathSegments.last}');
      if (!t.existsSync()) {
        f.copySync(t.path);
      } else if (o.update && t.readAsStringSync() != f.readAsStringSync()) {
        // Refresh from the package; keep the user's version next to it.
        t.copySync('${t.path}.user.bak');
        f.copySync(t.path);
        done.add(
          'Updated ${t.uri.pathSegments.last} (previous copy: .user.bak)',
        );
      }
    }
    if (already) {
      done.add('Widget extension already in Xcode project');
      return;
    }
    final bak = File('${pbx.path}.bak');
    if (!bak.existsSync()) bak.writeAsStringSync(pbx.readAsStringSync());
    final r = await Process.run('ruby', [
      '$root/tool/add_widget_target.rb',
      proj,
      ext,
      '16.2',
    ]);
    if (r.exitCode == 0) {
      done.add('Added Xcode widget extension target "$ext" (iOS 16.2)');
    } else {
      manual.addAll([
        'Could not add the Xcode target automatically (${(r.stderr as String).trim().split('\n').first}).',
        'Manual steps: 1) Xcode → File → New → Target → Widget Extension "$ext" (uncheck Include Live Activity if prompted to replace files);',
        '2) delete generated Swift files and add ios/$ext/*.swift to the target;',
        '3) set the extension deployment target to iOS 16.2 and use ios/$ext/Info.plist;',
        '4) add DeliveryAttributes.swift to BOTH Runner and the extension targets;',
        '5) embed the extension in Runner (Build Phases → Embed Foundation Extensions).',
      ]);
    }
    manual.add(
      'Set a signing team for the "$ext" target in Xcode (cannot be automated).',
    );
  }

  int _revert() {
    var n = 0;
    for (final rel in [
      'android/app/src/main/AndroidManifest.xml',
      'android/app/build.gradle.kts',
      'android/app/build.gradle',
      'ios/Runner/Info.plist',
      'ios/Podfile',
      'ios/Runner.xcodeproj/project.pbxproj',
    ]) {
      final bak = File('${_p(rel)}.bak');
      if (bak.existsSync()) {
        if (!o.dryRun) {
          File(_p(rel)).writeAsStringSync(bak.readAsStringSync());
          bak.deleteSync();
        }
        _log('↩ restored $rel');
        n++;
      }
    }
    final d = Directory(_p('ios/DeliveryLiveActivity'));
    if (d.existsSync() && !o.dryRun) {
      d.deleteSync(recursive: true);
      _log('↩ removed ios/DeliveryLiveActivity');
    }
    if (n == 0) _log('Nothing to revert (no .bak files).');
    return 0;
  }
}
