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
  List<ManualRouteItem> _routes = const [];

  String? _statsError;
  String? _usersError;
  String? _markersError;
  String? _routesError;
  String? _actionMessage;

  bool _isLoading = false;
  bool _isActing = false;

  late int _lastSeenRunsVersion;
  late bool _lastSeenIsAdmin;

  @override
  void initState() {
    super.initState();
    _lastSeenRunsVersion = widget.controller.runsVersion;
    _lastSeenIsAdmin = widget.controller.isAdmin;
    widget.controller.addListener(_onControllerChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;

    // FIX: _load() bails out immediately unless isAdmin was already true
    // *at the moment this screen first mounted*. Signing in as an admin
    // account after that (e.g. on web, which has no persisted session to
    // restore on launch) never re-triggered it, so the whole dashboard
    // stayed blank forever even after a successful admin sign-in.
    final isAdmin = widget.controller.isAdmin;
    if (isAdmin != _lastSeenIsAdmin) {
      _lastSeenIsAdmin = isAdmin;
      _load();
      return;
    }

    // FIX: this screen stays mounted for the app's lifetime (see the
    // IndexedStack fix in main.dart), so initState()'s one-time load can't
    // pick up routes shared/unshared/created/deleted elsewhere on its own —
    // refresh the moderation list whenever notifyRunsChanged() bumps the
    // version, same as Home's community routes.
    if (widget.controller.runsVersion != _lastSeenRunsVersion) {
      _lastSeenRunsVersion = widget.controller.runsVersion;
      _loadRoutes();
    }
  }

  Future<void> _load() async {
    if (!widget.controller.isAdmin) return;
    setState(() {
      _isLoading = true;
      _statsError = null;
      _usersError = null;
      _markersError = null;
      _routesError = null;
    });

    await Future.wait([
      _loadStats(),
      _loadUsers(),
      _loadMarkers(),
      _loadRoutes(),
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

  Future<void> _loadRoutes() async {
    try {
      final routes = await widget.controller.getAdminRoutes();
      if (!mounted) return;
      setState(() => _routes = routes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _routesError = '$error');
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

  Future<void> _unpublishRoute(ManualRouteItem route) async {
    setState(() => _isActing = true);
    try {
      await widget.controller.unpublishAdminRoute(route.id);
      setState(() => _actionMessage = 'Route unpublished successfully');
      // FIX: this only refreshed Admin's own list — Home's community
      // routes and the route owner's own Saved routes list (if the same
      // session) never got told to refresh, so they kept showing the route
      // as still published/still present.
      widget.controller.notifyRunsChanged();
      await _loadRoutes();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionMessage = 'Failed to unpublish route: $error');
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _deleteRoute(ManualRouteItem route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete route'),
        content: Text(
          'Are you sure you want to permanently delete "${route.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isActing = true);
    try {
      await widget.controller.deleteAdminRoute(route.id);
      setState(() => _actionMessage = 'Route deleted successfully');
      // FIX: same as unpublish — without this, the route's owner (if the
      // same session) still sees it in their own Saved routes list, and
      // Home's community list still shows it, even though it's gone from
      // the database.
      widget.controller.notifyRunsChanged();
      await _loadRoutes();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionMessage = 'Failed to delete route: $error');
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isAdmin) {
      return ListView(
        padding: const EdgeInsets.all(RunnaSpacing.page),
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
        padding: const EdgeInsets.all(RunnaSpacing.page),
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
          else
            _PaginatedSearchSection<AdminUserItem>(
              items: _users,
              searchHint: 'Search users',
              emptyLabel: _users.isEmpty ? 'No users found.' : 'No users match your search.',
              searchMatcher: (user, query) =>
                  '${user.firstName} ${user.lastName} ${user.username} ${user.email}'
                      .toLowerCase()
                      .contains(query),
              itemBuilder: (context, user) => RunnaCard(
                // FIX: ListTile needs a Material ancestor to paint its
                // background/ink splashes; RunnaCard is a plain decorated
                // Container, not a Material. Transparent so it doesn't
                // change RunnaCard's own appearance.
                child: Material(
                  type: MaterialType.transparency,
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
          else
            _PaginatedSearchSection<HazardMarkerItem>(
              items: _markers,
              searchHint: 'Search hazard pins',
              emptyLabel: _markers.isEmpty ? 'No active pins to moderate.' : 'No pins match your search.',
              searchMatcher: (marker, query) =>
                  '${marker.categoryLabel} ${marker.status} ${marker.note ?? ''}'
                      .toLowerCase()
                      .contains(query),
              itemBuilder: (context, marker) => RunnaCard(
                child: Material(
                  type: MaterialType.transparency,
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

          const SizedBox(height: 20),
          const SectionTitle('Manage community routes'),
          if (_routes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_routes.length} public routes',
                style: const TextStyle(color: RunnaColors.muted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          if (_routesError != null)
            _ErrorCard(message: 'Routes failed to load: $_routesError', onRetry: _loadRoutes)
          else
            _PaginatedSearchSection<ManualRouteItem>(
              items: _routes,
              searchHint: 'Search community routes',
              emptyLabel: _routes.isEmpty ? 'No community routes to manage.' : 'No routes match your search.',
              searchMatcher: (route, query) =>
                  '${route.name} ${route.creatorFullName ?? ''}'.toLowerCase().contains(query),
              itemBuilder: (context, route) => RunnaCard(
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(route.name),
                        subtitle: Text(
                          '${route.distanceKm.toStringAsFixed(2)} km • '
                          '${route.creatorFullName ?? 'Unknown creator'}',
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Unpublish'),
                            onPressed: _isActing ? null : () => _unpublishRoute(route),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: _isActing ? null : () => _deleteRoute(route),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Search box + fixed-size list + page-number navigation, shared by the
/// admin screen's Users, Hazard pins, and Community routes sections so none
/// of them render unbounded, hard-to-scan lists.
class _PaginatedSearchSection<T> extends StatefulWidget {
  const _PaginatedSearchSection({
    super.key,
    required this.items,
    required this.searchMatcher,
    required this.itemBuilder,
    required this.emptyLabel,
    required this.searchHint,
    this.pageSize = 10,
  });

  final List<T> items;
  final bool Function(T item, String lowercaseQuery) searchMatcher;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyLabel;
  final String searchHint;
  final int pageSize;

  @override
  State<_PaginatedSearchSection<T>> createState() => _PaginatedSearchSectionState<T>();
}

class _PaginatedSearchSectionState<T> extends State<_PaginatedSearchSection<T>> {
  final _searchController = TextEditingController();
  String _query = '';
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items.where((item) => widget.searchMatcher(item, _query)).toList();

    final totalPages = filtered.isEmpty ? 1 : (filtered.length / widget.pageSize).ceil();
    // FIX: clamp instead of trusting _page — the underlying list can shrink
    // out from under a page the admin is currently viewing (delete, search).
    final page = _page.clamp(0, totalPages - 1);
    final start = page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, filtered.length);
    final pageItems = filtered.isEmpty ? <T>[] : filtered.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.isNotEmpty) ...[
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {
              _query = value.trim().toLowerCase();
              _page = 0;
            }),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = '';
                        _page = 0;
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (filtered.isEmpty)
          RunnaCard(child: Text(widget.emptyLabel))
        else ...[
          for (final item in pageItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: widget.itemBuilder(context, item),
            ),
          if (totalPages > 1)
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    visualDensity: VisualDensity.compact,
                    onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
                  ),
                  for (var i = 0; i < totalPages; i++)
                    _PageNumberButton(
                      pageNumber: i + 1,
                      isSelected: i == page,
                      onTap: () => setState(() => _page = i),
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    visualDensity: VisualDensity.compact,
                    onPressed: page < totalPages - 1 ? () => setState(() => _page = page + 1) : null,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  const _PageNumberButton({
    required this.pageNumber,
    required this.isSelected,
    required this.onTap,
  });

  final int pageNumber;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? RunnaColors.primary : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isSelected ? null : onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Text(
              '$pageNumber',
              style: TextStyle(
                color: isSelected ? Colors.white : RunnaColors.primaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: RunnaSpacing.card, vertical: 12),
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