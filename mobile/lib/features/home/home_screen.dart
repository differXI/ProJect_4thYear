import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, required this.onNavigate});

  final AuthController controller;
  final ValueChanged<int> onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BaseMapData? _map;
  List<RunItem> _runs = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final map = await widget.controller.getBaseMap();
      final runs = widget.controller.isAuthenticated ? await widget.controller.getRuns() : const <RunItem>[];
      if (!mounted) return;
      setState(() {
        _map = map;
        _runs = runs;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final finishedRuns = _runs.where((run) => run.status == 'finished').length;
    final activePins = _map?.markers.length ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionTitle(
            user == null ? 'Runna' : 'Hello, ${user.firstName}',
            subtitle: 'Route-centric running with AI insights and community hazard pins',
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: RunnaColors.danger)),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(label: 'Active pins', value: '$activePins', icon: Icons.place_outlined),
              _StatChip(label: 'Your runs', value: '$finishedRuns', icon: Icons.directions_run),
              _StatChip(
                label: 'Account',
                value: user == null ? 'Guest' : user.roleName,
                icon: Icons.person_outline,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _QuickAction(
            title: 'Create route',
            subtitle: 'Draw a custom running route on the map',
            icon: Icons.route_outlined,
            onTap: () => widget.onNavigate(1),
          ),
          _QuickAction(
            title: 'Start a run',
            subtitle: 'Track distance, pace, steps, and get AI feedback',
            icon: Icons.play_circle_outline,
            onTap: () => widget.onNavigate(2),
          ),
          _QuickAction(
            title: 'Report hazard',
            subtitle: 'Share and validate real-world route conditions',
            icon: Icons.warning_amber_outlined,
            onTap: () => widget.onNavigate(3),
          ),
          if (widget.controller.isAdmin)
            _QuickAction(
              title: 'Admin dashboard',
              subtitle: 'Manage users, pins, and platform activity',
              icon: Icons.admin_panel_settings_outlined,
              onTap: () => widget.onNavigate(4),
            ),
          const SizedBox(height: 20),
          const SectionTitle('Project features', subtitle: 'Aligned with your senior project proposal'),
          const SizedBox(height: 12),
          const RunnaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeatureLine('Manual route creation on interactive map'),
                _FeatureLine('Collaborative hazard pin system with validation'),
                _FeatureLine('Run tracking: distance, duration, pace, steps'),
                _FeatureLine('AI performance summary after each run'),
                _FeatureLine('Role-based access: guest, member, admin'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return RunnaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: RunnaColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: RunnaColors.muted, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: RunnaCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: RunnaColors.accent.withValues(alpha: 0.25),
                child: Icon(icon, color: RunnaColors.primaryDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: RunnaColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: RunnaColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
