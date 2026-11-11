import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter/material.dart';

import 'demo_scaffold.dart';

Widget compactDeliveryDemo() => const DeliveryDemo(
  id: 'compact',
  title: 'Compact delivery',
  template: CompactDeliveryTemplate(),
  vehicle: DeliveryVehicle.bike,
);
