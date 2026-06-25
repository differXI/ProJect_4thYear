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

  String? _statsError;
  String? _usersError;
  String? _markersError;
  String? _actionMessage;

  bool _isLoading = false;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.controller.isAdmin) return;
    setState(() {
      _isLoading = true;
      _statsError = null;
      _usersError = null;
      _markersError = null;
    });

    await Future.wait([
      _loadStats(),
      _loadUsers(),
      _loadMarkers(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    try {
      final stats = await widget.controller.getAdminStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (error) {
      if (!mounted) return;
      setState(() => _statsError = '$error');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await widget.controller.getAdminUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (error) {
      if (!mounted) return;
      setState(() => _usersError = '$error');
    }
  }

  Future<void> _loadMarkers() async {
    try {
      final markers = await widget.controller.getAdminMarkers();
      if (!mounted) return;
      setState(() => _markers = markers);
    } catch (error) {
      if (!mounted) return;
      setState(() => _markersError = '$error');
    }
  }

  Future<void> _toggleUser(AdminUserItem user) async {
    setState(() => _isActing = true);
    try {
      await widget.controller.updateAdminUser(userId: user.id, isActive: !user.isActive);
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionMessage = '$error');
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _changeRole(AdminUserItem user, String roleName) async {
    if (roleName == user.roleName) return;
    setState(() => _isActing = true);
    try {
      await widget.controller.updateAdminUser(userId: user.id, roleName: roleName);
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionMessage = '$error');
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _removeMarker(HazardMarkerItem marker) async {
    setState(() => _isActing = true);
    try {
      await widget.controller.deleteAdminMarker(marker.id);
      await _loadMarkers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionMessage = '$error');
    } finally {
      if (mounted) setState(() => _isActing = false);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionTitle('Admin dashboard', subtitle: 'Monitor users, runs, routes, and hazard pins'),
              ),
              if (_isLoading) const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_actionMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_actionMessage!, style: const TextStyle(color: RunnaColors.primaryDark)),
            ),

          // --- Stats ---
          if (_statsError != null)
            _ErrorCard(message: 'Stats failed to load: $_statsError', onRetry: _loadStats)
          else if (stats != null)
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
          if (_usersError != null)
            _ErrorCard(message: 'Users failed to load: $_usersError', onRetry: _loadUsers)
          else if (_users.isEmpty)
            const RunnaCard(child: Text('No users found.'))
          else
            ..._users.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RunnaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${user.firstName} ${user.lastName} (@${user.username})'),
                        subtitle: Text(
                          '${user.email} • ${user.runCount} runs • ${user.pinCount} pins',
                        ),
                        trailing: Switch(
                          value: user.isActive,
                          onChanged: _isActing ? null : (_) => _toggleUser(user),
                        ),
                      ),
                      Row(
                        children: [
                          const Text('Role:'),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: user.roleName == 'admin' ? 'admin' : 'member',
                            items: const [
                              DropdownMenuItem(value: 'member', child: Text('member')),
                              DropdownMenuItem(value: 'admin', child: Text('admin')),
                            ],
                            onChanged: _isActing ? null : (value) => value == null ? null : _changeRole(user, value),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),
          const SectionTitle('Moderate hazard pins'),
          if (_markers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${_markers.length} pins', style: const TextStyle(color: RunnaColors.muted, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          if (_markersError != null)
            _ErrorCard(message: 'Hazard pins failed to load: $_markersError', onRetry: _loadMarkers)
          else if (_markers.isEmpty)
            const RunnaCard(child: Text('No active pins to moderate.'))
          else
            ..._markers.map(
              (marker) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RunnaCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(marker.categoryLabel),
                    subtitle: Text(
                      'Severity ${marker.severity} • ${marker.status}'
                      '${marker.note != null ? ' • ${marker.note}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: RunnaColors.danger),
                      onPressed: _isActing ? null : () => _removeMarker(marker),
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return RunnaCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: RunnaColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: RunnaColors.danger))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}