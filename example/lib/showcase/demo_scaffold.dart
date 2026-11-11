import 'dart:async';

import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter/material.dart';

import '../simulator/delivery_simulator.dart';

/// Shared start/stop UI so each template demo stays tiny.
class DeliveryDemo extends StatefulWidget {
  const DeliveryDemo({
    super.key,
    required this.id,
    required this.title,
    required this.template,
    this.vehicle = DeliveryVehicle.scooter,
  });

  final String id;
  final String title;
  final DeliveryTemplate template;
  final DeliveryVehicle vehicle;

  @override
  State<DeliveryDemo> createState() => _DeliveryDemoState();
}

class _DeliveryDemoState extends State<DeliveryDemo> {
  DeliveryController? _c;
  DeliverySimulator? _sim;
  String _log = 'Idle';
  StreamSubscription<dynamic>? _resSub, _errSub;
  bool _noise = false, _drop = false, _ooo = false;

  Future<void> _start() async {
    try {
      final c = await DynamicNotification.startDelivery(
        id: widget.id,
        template: widget.template,
        state: DeliveryState(
          progress: 0,
          vehicle: widget.vehicle,
          eta: DateTime.now().add(const Duration(minutes: 12)),
          driverName: 'Alex',
        ),
        route: sampleRoute,
      );
      _resSub?.cancel();
      _errSub?.cancel();
      _resSub = c.results.listen((r) => _say('Last update: ${r.name}'));
      _errSub = c.errors.listen((e) => _say(e.toString()));
      _c = c;
      _sim = DeliverySimulator(c)
        ..gpsNoise = _noise
        ..dropouts = _drop
        ..outOfOrder = _ooo
        ..start();
      _say('Started');
    } on DynamicNotificationException catch (e) {
      _say(e.toString());
    }
  }

  void _say(String m) {
    if (mounted) setState(() => _log = m);
  }

  Future<void> _stop() async {
    _sim?.stop();
    _resSub?.cancel();
    _errSub?.cancel();
    await _c?.end();
    if (!mounted) return;
    setState(() {
      _c = null;
      _sim = null;
      _log = 'Ended';
    });
  }

  @override
  void dispose() {
    _sim?.stop();
    _resSub?.cancel();
    _errSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Theme.of(context).platform == TargetPlatform.iOS
                  ? 'Tap Start, then swipe home or lock the phone to see the Dynamic Island / lock screen.'
                  : 'Tap Start, then pull down the notification shade.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('GPS noise'),
                  selected: _noise,
                  onSelected: (v) => setState(() {
                    _noise = v;
                    _sim?.gpsNoise = v;
                  }),
                ),
                FilterChip(
                  label: const Text('Dropouts'),
                  selected: _drop,
                  onSelected: (v) => setState(() {
                    _drop = v;
                    _sim?.dropouts = v;
                  }),
                ),
                FilterChip(
                  label: const Text('Out-of-order'),
                  selected: _ooo,
                  onSelected: (v) => setState(() {
                    _ooo = v;
                    _sim?.outOfOrder = v;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _c == null ? _start : null,
                  child: const Text('Start'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _c == null ? null : _stop,
                  child: const Text('End'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _log,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
