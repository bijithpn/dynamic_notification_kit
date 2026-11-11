import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter/material.dart';

import '../simulator/delivery_simulator.dart';
import 'demo_scaffold.dart';

Widget animatedRouteDemo() => DeliveryDemo(
  id: 'animated',
  title: 'Animated route',
  template: AnimatedRouteTemplate(route: sampleRoute),
  vehicle: DeliveryVehicle.car,
);
