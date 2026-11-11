import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter/material.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});
  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  DynamicNotificationCapabilities? _caps;
  List<String> _issues = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final c = await DynamicNotification.getCapabilities();
      final d = await DynamicNotification.diagnose();
      setState(() {
        _caps = c;
        _issues = d;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Widget _row(
    String label,
    bool ok, {
    bool warn = false,
    String? hint,
    VoidCallback? fix,
    String fixLabel = 'Fix',
  }) {
    final color = ok ? Colors.green : (warn ? Colors.amber : Colors.red);
    return ListTile(
      leading: Icon(
        ok ? Icons.check_circle : (warn ? Icons.info : Icons.cancel),
        color: color,
      ),
      title: Text(label),
      subtitle: hint == null ? null : Text(hint),
      trailing: !ok && fix != null
          ? TextButton(onPressed: fix, child: Text(fixLabel))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _caps;
    return ListView(
      children: [
        if (_error != null) ListTile(title: Text(_error!)),
        if (c != null) ...[
          ListTile(title: Text('${c.platform} ${c.osVersion}')),
          _row('Notifications permitted', c.notificationsPermitted),
          _row(
            'Live surface (Live Activity / ProgressStyle)',
            c.supportsLiveSurface,
            hint: c.platform == 'ios'
                ? 'Live Activities must be ON in Settings. They appear on the lock screen and Dynamic Island only while the app is in the background.'
                : 'Needs Android 16 for the progress tracker; older versions use a custom layout.',
            fix: DynamicNotification.openSettings,
            fixLabel: 'Settings',
          ),
          if (c.platform == 'android')
            _row(
              'Live Updates (status-bar chip)',
              c.supportsPromotedOngoing,
              warn: true,
              hint: c.supportsPromotedOngoing ? null : 'Needs Android 16 and "Live notifications" enabled for this app. The notification still works without it, just without the chip.',
              fix: () => DynamicNotification.openSettings(promoted: true),
              fixLabel: 'Enable',
            )
          else
            _row(
              'Status-bar chip',
              true,
              hint: 'Android 16 only. Not applicable on iOS.',
            ),
          if (c.platform == 'ios')
            _row(
              c.dynamicIslandIsHeuristic
                  ? 'Dynamic Island (device-model heuristic)'
                  : 'Dynamic Island',
              c.supportsDynamicIsland,
              warn: true,
              hint: 'Background the app (swipe home) to see it.',
            ),
        ],
        for (final i in _issues) _row(i, false),
        if (c != null && _issues.isEmpty)
          _row('Native configuration looks complete', true),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              FilledButton(
                onPressed: () async {
                  await DynamicNotification.requestPermission();
                  _refresh();
                },
                child: const Text('Request permission'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _refresh, child: const Text('Refresh')),
            ],
          ),
        ),
      ],
    );
  }
}
