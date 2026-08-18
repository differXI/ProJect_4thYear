import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/route_preview_sheet.dart';
import '../../widgets/route_result_card.dart';
import '../auth/auth_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, required this.onNavigate});

  final AuthController controller;
  final ValueChanged<int> onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<RunItem> _runs = const [];
  List<ManualRouteItem> _communityRoutes = const [];
  Set<int> _favoriteRouteIds = <int>{};

  String _communitySearch = '';
  String _communitySort = 'newest';

  // Defaults to 'week' so the dashboard opens on the most relevant range.
  String _statsFilter = 'week';

  String? _error;
  bool _isLoadingCommunity = false;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCommunityRoutes();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoadingStats = true);
    try {
      final runs = widget.controller.isAuthenticated ? await widget.controller.getRuns() : const <RunItem>[];
      final favorites = widget.controller.isAuthenticated
          ? await widget.controller.getFavoriteRoutes()
          : const <ManualRouteItem>[];
      if (!mounted) return;
      setState(() {
        _runs = runs;
        _favoriteRouteIds = favorites.map((route) => route.id).toSet();
        _error = null;
        _isLoadingStats = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadCommunityRoutes() async {
    setState(() {
      _isLoadingCommunity = true;
      _error = null;
    });
    try {
      final routes = await widget.controller.getCommunityRoutes(
        search: _communitySearch,
        sort: _communitySort,
      );
      if (!mounted) return;
      setState(() => _communityRoutes = routes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _isLoadingCommunity = false);
    }
  }

  void _onSearchChanged(String value) {
    _communitySearch = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _loadCommunityRoutes);
    setState(() {});
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _communitySearch = '';
    _loadCommunityRoutes();
  }

  Future<void> _toggleFavorite(ManualRouteItem route) async {
    if (!widget.controller.isAuthenticated) {
      widget.onNavigate(4);
      return;
    }
    final wasFavorited = _favoriteRouteIds.contains(route.id);
    setState(() {
      if (wasFavorited) {
        _favoriteRouteIds.remove(route.id);
      } else {
        _favoriteRouteIds.add(route.id);
      }
    });
    try {
      await widget.controller.favoriteManualRoute(routeId: route.id, favorite: !wasFavorited);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasFavorited) {
          _favoriteRouteIds.add(route.id);
        } else {
          _favoriteRouteIds.remove(route.id);
        }
        _error = '$error';
      });
    }
  }

  void _startRunOnRoute(ManualRouteItem route) {
    widget.controller.setPendingRunRoute(route);
    widget.onNavigate(2);
  }

  void _openRoutePreview(ManualRouteItem route) {
    showRoutePreviewSheet(
      context,
      route: route,
      isFavorited: _favoriteRouteIds.contains(route.id),
      isAuthenticated: widget.controller.isAuthenticated,
      onToggleFavorite: () => _toggleFavorite(route),
      onRun: () => _startRunOnRoute(route),
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds == 0) return '0h 0m';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;

    // ── Calculate Stats (with a working week/month/year filter) ──
    final finishedRuns = _runs.where((run) => run.status == 'finished').toList();

    double totalDistanceKm = 0.0;
    int totalDurationSeconds = 0;
    double totalCalories = 0.0;
    int totalRunCount = 0;

    final now = DateTime.now();
    DateTime? cutoff;
    switch (_statsFilter) {
      case 'week':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case 'year':
        cutoff = now.subtract(const Duration(days: 365));
        break;
    }

    for (final run in finishedRuns) {
      final runDate = run.finishedAt ?? run.startedAt;
      final isInFilterRange = cutoff == null || (runDate != null && runDate.isAfter(cutoff));
      if (isInFilterRange) {
        totalRunCount++;
        totalDistanceKm += run.distanceKm;
        totalDurationSeconds += run.durationSeconds;
        totalCalories += run.distanceKm * 60; // Estimate: 60 kcal per km
      }
    }

    return RefreshIndicator(
      color: RunnaColors.primary,
      onRefresh: () async {
        await Future.wait([_load(), _loadCommunityRoutes()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(RunnaSpacing.page),
        children: [
          Text(
            user == null ? 'Welcome!' : 'Hello, ${user.firstName}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: RunnaColors.primaryDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your running dashboard & community routes',
            style: TextStyle(color: RunnaColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: const TextStyle(color: RunnaColors.danger)),
            ),

          // ── Statistics Dashboard with Time Filter ──
          if (_isLoadingStats)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else
            RunnaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bar_chart_rounded, color: RunnaColors.primary),
                          SizedBox(width: 8),
                          Text('Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: RunnaColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _buildFilterTab('Week', 'week'),
                            _buildFilterTab('Month', 'month'),
                            _buildFilterTab('Year', 'year'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        totalDistanceKm.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, height: 1),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text('km', style: TextStyle(fontSize: 16, color: RunnaColors.muted, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Total Distance', style: TextStyle(color: RunnaColors.muted, fontSize: 13)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: RunnaColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat('$totalRunCount', 'Runs', Icons.directions_run),
                        Container(width: 1.5, height: 30, color: RunnaColors.muted.withValues(alpha: 0.2)),
                        _buildMiniStat(_formatDuration(totalDurationSeconds), 'Time', Icons.timer_outlined),
                        Container(width: 1.5, height: 30, color: RunnaColors.muted.withValues(alpha: 0.2)),
                        _buildMiniStat(totalCalories.toStringAsFixed(0), 'Kcal', Icons.local_fire_department_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // ── Community Routes Section ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Community Routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              PopupMenuButton<String>(
                initialValue: _communitySort,
                onSelected: (value) {
                  setState(() => _communitySort = value);
                  _loadCommunityRoutes();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'newest', child: Text('Newest')),
                  PopupMenuItem(value: 'popular', child: Text('Popular')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: RunnaColors.background,
                    border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _communitySort == 'popular' ? Icons.trending_up : Icons.schedule,
                        size: 16,
                        color: RunnaColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _communitySort == 'popular' ? 'Popular' : 'Newest',
                        style: const TextStyle(color: RunnaColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Search Bar (auto-searches with a short debounce) ──
          SizedBox(
            height: RunnaSpacing.inputHeight,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _searchDebounce?.cancel();
                _loadCommunityRoutes();
              },
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search routes...',
                hintStyle: TextStyle(color: RunnaColors.muted.withValues(alpha: 0.7)),
                prefixIcon: const Icon(Icons.search, size: 20, color: RunnaColors.primary),
                suffixIcon: _communitySearch.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearSearch,
                      ),
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: RunnaColors.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: RunnaColors.muted.withValues(alpha: 0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: RunnaColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Community List ──
          if (_isLoadingCommunity)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_communityRoutes.isEmpty)
            RunnaCard(
              child: Center(
                child: Text(
                  _communitySearch.isEmpty
                      ? 'No routes found. Be the first to share one!'
                      : 'No routes match "$_communitySearch".',
                  style: const TextStyle(color: RunnaColors.muted),
                ),
              ),
            )
          else
            ..._communityRoutes.map((route) => _buildCommunityCard(route)),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _statsFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statsFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? RunnaColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : RunnaColors.primary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: RunnaColors.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: RunnaColors.muted)),
      ],
    );
  }

  Widget _buildCommunityCard(ManualRouteItem route) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RouteResultCard(
        route: route,
        isFavorited: _favoriteRouteIds.contains(route.id),
        onToggleFavorite: () => _toggleFavorite(route),
        onViewMap: () => _openRoutePreview(route),
        onRun: () => _startRunOnRoute(route),
      ),
    );
  }
}
