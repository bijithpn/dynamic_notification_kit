import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter/material.dart';

import 'demo_scaffold.dart';

Widget driverApproachingDemo() => const DeliveryDemo(
  id: 'approaching',
  title: 'Driver approaching',
  template: DriverApproachingTemplate(approachingThresholdMeters: 400),
  vehicle: DeliveryVehicle.van,
);
