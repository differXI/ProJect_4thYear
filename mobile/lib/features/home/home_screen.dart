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

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final finishedRuns = _runs.where((run) => run.status == 'finished').toList();
    final recentRuns = finishedRuns
        .where((run) => run.finishedAt != null && run.finishedAt!.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .toList();
    final weeklyDistance = recentRuns.fold<double>(0, (sum, run) => sum + run.distanceKm);
    final weeklyTime = recentRuns.fold<int>(0, (sum, run) => sum + run.durationSeconds);
    final avgPace = recentRuns.where((run) => run.avgPaceMinPerKm != null).map((run) => run.avgPaceMinPerKm!).fold<double>(0, (sum, pace) => sum + pace);
    final averagePace = recentRuns.isEmpty || avgPace == 0 ? 0.0 : avgPace / recentRuns.where((run) => run.avgPaceMinPerKm != null).length;
    final activePins = _map?.markers.length ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionTitle(
            user == null ? 'Runna' : 'Hello, ${user.firstName}',
            subtitle: 'Track your movement, stay safe, and discover shared routes',
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: RunnaColors.danger)),
            ),
          RunnaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Weekly overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Last 7 days', style: TextStyle(color: RunnaColors.muted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _MetricTile(label: 'Runs', value: '${recentRuns.length}', icon: Icons.directions_run)),
                    const SizedBox(width: 12),
                    Expanded(child: _MetricTile(label: 'Distance', value: '${weeklyDistance.toStringAsFixed(1)} km', icon: Icons.route_outlined)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _MetricTile(label: 'Time', value: _formatDuration(weeklyTime), icon: Icons.timer_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _MetricTile(label: 'Avg pace', value: averagePace == 0 ? '--' : '${averagePace.toStringAsFixed(1)} min/km', icon: Icons.speed_outlined)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  title: 'Create route',
                  subtitle: 'Map your route',
                  icon: Icons.route_outlined,
                  onTap: () => widget.onNavigate(1),
                ),
              ),
            ],
          ),
          _QuickAction(
            title: 'Start a run',
            subtitle: 'Track pace and distance',
            icon: Icons.play_circle_outline,
            onTap: () => widget.onNavigate(2),
          ),
          _QuickAction(
            title: 'Report hazard',
            subtitle: 'Keep the route safe',
            icon: Icons.warning_amber_outlined,
            onTap: () => widget.onNavigate(3),
          ),
          if (widget.controller.isAdmin)
            _QuickAction(
              title: 'Admin dashboard',
              subtitle: 'Manage the platform',
              icon: Icons.admin_panel_settings_outlined,
              onTap: () => widget.onNavigate(4),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => widget.onNavigate(3),
                icon: const Icon(Icons.location_on_outlined),
                label: Text('Active pins ($activePins)'),
              ),
              TextButton.icon(
                onPressed: () => widget.onNavigate(2),
                icon: const Icon(Icons.format_list_bulleted),
                label: Text('All runs (${finishedRuns.length})'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RunnaColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: RunnaColors.accent.withValues(alpha: 0.3),
            child: Icon(icon, size: 18, color: RunnaColors.primaryDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: RunnaColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
