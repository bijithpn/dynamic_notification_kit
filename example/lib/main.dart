import 'package:flutter/material.dart';

import 'showcase/animated_route_demo.dart';
import 'showcase/compact_delivery_demo.dart';
import 'showcase/delivery_completed_demo.dart';
import 'showcase/delivery_tracking_demo.dart';
import 'showcase/diagnostics_page.dart';
import 'showcase/driver_approaching_demo.dart';
import 'showcase/minimal_demo.dart';

void main() => runApp(const ShowcaseApp());

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dynamic Notification Kit',
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          deliveryTrackingDemo(),
          compactDeliveryDemo(),
          animatedRouteDemo(),
          driverApproachingDemo(),
          const DeliveryCompletedDemo(),
        ],
      ),
      const MinimalDemo(),
      const DiagnosticsPage(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Dynamic Notification Kit')),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.delivery_dining),
            label: 'Delivery',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Minimal',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check),
            label: 'Diagnostics',
          ),
        ],
      ),
    );
  }
}
