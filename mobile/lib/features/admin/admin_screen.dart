import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  AdminStats? _stats;
  List<AdminUserItem> _users = const [];
  List<HazardMarkerItem> _markers = const [];
  String? _message;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.controller.isAdmin) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final stats = await widget.controller.getAdminStats();
      final users = await widget.controller.getAdminUsers();
      final markers = await widget.controller.getAdminMarkers();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _users = users;
        _markers = markers.where((marker) => marker.status == 'active').toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleUser(AdminUserItem user) async {
    setState(() => _isLoading = true);
    try {
      await widget.controller.updateAdminUser(userId: user.id, isActive: !user.isActive);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMarker(HazardMarkerItem marker) async {
    setState(() => _isLoading = true);
    try {
      await widget.controller.deleteAdminMarker(marker.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isAdmin) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          SectionTitle('Admin', subtitle: 'Platform monitoring and moderation'),
          SizedBox(height: 16),
          RunnaCard(child: Text('Admin access required.')),
        ],
      );
    }

    final stats = _stats;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionTitle('Admin dashboard', subtitle: 'Monitor users, runs, routes, and hazard pins'),
          const SizedBox(height: 16),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_message!, style: const TextStyle(color: RunnaColors.danger)),
            ),
          if (stats != null)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AdminStat(label: 'Users', value: '${stats.totalUsers}'),
                _AdminStat(label: 'Active users', value: '${stats.activeUsers}'),
                _AdminStat(label: 'Runs', value: '${stats.totalRuns}'),
                _AdminStat(label: 'Finished runs', value: '${stats.finishedRuns}'),
                _AdminStat(label: 'Active pins', value: '${stats.activePins}'),
                _AdminStat(label: 'Saved routes', value: '${stats.totalRoutes}'),
              ],
            ),
          const SizedBox(height: 20),
          const SectionTitle('Users'),
          const SizedBox(height: 12),
          ..._users.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RunnaCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${user.firstName} ${user.lastName} (@${user.username})'),
                  subtitle: Text(
                    '${user.email} • ${user.roleName} • ${user.runCount} runs • ${user.pinCount} pins',
                  ),
                  trailing: Switch(
                    value: user.isActive,
                    onChanged: _isLoading ? null : (_) => _toggleUser(user),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Moderate hazard pins'),
          const SizedBox(height: 12),
          if (_markers.isEmpty)
            const RunnaCard(child: Text('No active pins to moderate.'))
          else
            ..._markers.map(
              (marker) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RunnaCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(marker.categoryLabel),
                    subtitle: Text('Severity ${marker.severity}${marker.note != null ? ' • ${marker.note}' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: RunnaColors.danger),
                      onPressed: _isLoading ? null : () => _removeMarker(marker),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminStat extends StatelessWidget {
  const _AdminStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RunnaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: RunnaColors.muted, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ],
      ),
    );
  }
}