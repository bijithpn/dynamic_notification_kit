import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter/material.dart';

import '../simulator/delivery_simulator.dart';
import 'demo_scaffold.dart';

Widget deliveryTrackingDemo() => DeliveryDemo(
  id: 'tracking',
  title: 'Delivery tracking',
  template: DeliveryTrackingTemplate(route: sampleRoute),
);
