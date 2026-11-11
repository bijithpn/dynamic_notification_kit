import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter/material.dart';

/// Shows the final "delivered" surface immediately.
class DeliveryCompletedDemo extends StatelessWidget {
  const DeliveryCompletedDemo({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: const Text('Delivery completed'),
      subtitle: const Text('Posts the final delivered state'),
      trailing: FilledButton(
        onPressed: () async {
          try {
            final c = await DynamicNotification.startDelivery(
              id: 'completed',
              template: const DeliveryCompletedTemplate(
                message: 'Delivered 🎉',
              ),
              state: DeliveryState(progress: .9),
            );
            await c.complete();
          } on DynamicNotificationException catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }
        },
        child: const Text('Show'),
      ),
    ),
  );
}
