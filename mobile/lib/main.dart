import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/admin/admin_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_screen.dart';
import 'features/hazards/hazards_screen.dart';
import 'features/home/home_screen.dart';
import 'features/routes/routes_screen.dart';
import 'features/runs/runs_screen.dart';

void main() {
  runApp(const RunnaApp());
}

class RunnaApp extends StatefulWidget {
  const RunnaApp({super.key});

  @override
  State<RunnaApp> createState() => _RunnaAppState();
}

class _RunnaAppState extends State<RunnaApp> {
  late final AuthController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AuthController()..addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_controller.isAdmin && _currentIndex == 5) {
      _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Routes'),
      const NavigationDestination(
        icon: Icon(Icons.directions_run_outlined),
        selectedIcon: Icon(Icons.directions_run),
        label: 'Runs',
      ),
      const NavigationDestination(
        icon: Icon(Icons.warning_amber_outlined),
        selectedIcon: Icon(Icons.warning_amber),
        label: 'Hazards',
      ),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
      if (_controller.isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
    ];

    final pages = <Widget>[
      HomeScreen(controller: _controller, onNavigate: (index) => setState(() => _currentIndex = index)),
      RoutesScreen(controller: _controller),
      RunsScreen(controller: _controller),
      HazardsScreen(controller: _controller),
      AuthScreen(controller: _controller),
      if (_controller.isAdmin) AdminScreen(controller: _controller),
    ];

    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    return MaterialApp(
      title: 'Runna',
      debugShowCheckedModeBanner: false,
      theme: RunnaTheme.light(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Runna'),
          actions: [
            if (_controller.isAuthenticated)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    _controller.currentUser!.firstName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(child: pages[safeIndex]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: destinations,
        ),
      ),
    );
  }
}
