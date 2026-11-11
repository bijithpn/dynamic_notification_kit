import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter/material.dart';

class MinimalDemo extends StatelessWidget {
  const MinimalDemo({super.key});

  Future<void> _post(BuildContext context, CompactNotificationContent c) async {
    try {
      await DynamicNotification.start(
        DynamicNotificationRequest(
          id: 'minimal',
          mode: DynamicNotificationMode.minimal,
          compact: c,
        ),
      );
    } on DynamicNotificationException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: ListTile(
          title: const Text('Icon + text'),
          onTap: () => _post(
            context,
            const CompactNotificationContent(
              title: DynamicText('Order ready', shortText: 'Ready'),
              body: DynamicText('Pick up at counter 3'),
            ),
          ),
        ),
      ),
      Card(
        child: ListTile(
          title: const Text('Countdown (2 min)'),
          onTap: () => _post(
            context,
            CompactNotificationContent(
              title: const DynamicText('Timer', shortText: 'Timer'),
              countdownTo: DateTime.now().add(const Duration(minutes: 2)),
              layout: CompactNotificationLayout.iconAndTimer,
            ),
          ),
        ),
      ),
      Card(
        child: ListTile(
          title: const Text('Progress 60%'),
          onTap: () => _post(
            context,
            CompactNotificationContent(
              title: const DynamicText('Uploading', shortText: 'Upload'),
              progress: DynamicProgress(value: .6),
              layout: CompactNotificationLayout.iconAndProgress,
            ),
          ),
        ),
      ),
      OutlinedButton(
        onPressed: () => DynamicNotification.end('minimal'),
        child: const Text('Dismiss'),
      ),
    ],
  );
}
