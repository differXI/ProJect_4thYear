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
  List<ManualRouteItem> _communityRoutes = const [];
  
  String _communitySearch = '';
  String _communitySort = 'newest';
  
  // ตัวแปรสำหรับ Filter สถิติ (ตั้งค่าเริ่มต้นเป็น 'week')
  String _statsFilter = 'week'; 

  String? _error;
  bool _isLoadingCommunity = false;
  bool _isLoadingStats = true;

  // Green Theme Colors
  final Color _primaryGreen = Colors.green.shade600;
  final Color _lightGreen = Colors.green.shade50;
  final Color _borderColor = Colors.green.shade200;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCommunityRoutes();
  }

  Future<void> _load() async {
    setState(() => _isLoadingStats = true);
    try {
      final map = await widget.controller.getBaseMap();
      final runs = widget.controller.isAuthenticated ? await widget.controller.getRuns() : const <RunItem>[];
      if (!mounted) return;
      setState(() {
        _map = map;
        _runs = runs;
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
    
    // Calculate Stats
    final finishedRuns = _runs.where((run) => run.status == 'finished').toList();
    
    double totalDistanceKm = 0.0;
    int totalDurationSeconds = 0;
    double totalCalories = 0.0;
    int totalRunCount = 0;

    final now = DateTime.now();

    for (var run in finishedRuns) {
      // ---------------------------------------------------------
      // TODO: ใส่เงื่อนไข Filter วันที่ของคุณตรงนี้
      // ตัวอย่าง: หาก RunItem ของคุณมีตัวแปรชื่อ createdAt (เป็น DateTime)
      // ---------------------------------------------------------
      bool isInFilterRange = true; 
      
      /* 
      // เอาคอมเมนต์นี้ออกและเปลี่ยน 'run.createdAt' เป็นชื่อตัวแปรที่ถูกต้องใน Model ของคุณ
      if (run.createdAt != null) {
        final runDate = run.createdAt!;
        if (_statsFilter == 'week') {
          isInFilterRange = now.difference(runDate).inDays <= 7;
        } else if (_statsFilter == 'month') {
          isInFilterRange = now.difference(runDate).inDays <= 30;
        } else if (_statsFilter == 'year') {
          isInFilterRange = now.difference(runDate).inDays <= 365;
        }
      } 
      */

      if (isInFilterRange) {
        totalRunCount++;
        totalDistanceKm += (run.distanceKm ?? 0.0);
        totalDurationSeconds += (run.durationSeconds ?? 0);
        totalCalories += ((run.distanceKm ?? 0.0) * 60); // Estimate: 60 kcal per km
      }
    }

    return RefreshIndicator(
      color: _primaryGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // 1. Header 
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user == null ? 'Welcome!' : 'Hello, ${user.firstName}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your running dashboard & community routes',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          // 2. Statistics Dashboard with Time Filter
          if (_isLoadingStats)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(color: _primaryGreen.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bar_chart_rounded, color: _primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      
                      // TIME FILTER TABS (Week / Month / Year)
                      Container(
                        decoration: BoxDecoration(
                          color: _lightGreen,
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
                  
                  // Main Highlight
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        totalDistanceKm.toStringAsFixed(1),
                        style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.grey.shade800, height: 1),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('km', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Total Distance', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  
                  const SizedBox(height: 20),
                  
                  // Sub-stats Grid
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _lightGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat('$totalRunCount', 'Runs', Icons.directions_run),
                        Container(width: 1.5, height: 30, color: _borderColor),
                        _buildMiniStat(_formatDuration(totalDurationSeconds), 'Time', Icons.timer_outlined),
                        Container(width: 1.5, height: 30, color: _borderColor),
                        _buildMiniStat(totalCalories.toStringAsFixed(0), 'Kcal', Icons.local_fire_department_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // 3. Community Routes Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Community Routes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // Compact Sort Menu
              PopupMenuButton<String>(
                initialValue: _communitySort,
                onSelected: (value) {
                  setState(() => _communitySort = value);
                  _loadCommunityRoutes();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'newest', child: Text('Newest')),
                  const PopupMenuItem(value: 'popular', child: Text('Popular')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    border: Border.all(color: _borderColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(_communitySort == 'popular' ? Icons.trending_up : Icons.schedule, size: 16, color: _primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        _communitySort == 'popular' ? 'Popular' : 'Newest',
                        style: TextStyle(color: _primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Search Bar
          SizedBox(
            height: 44,
            child: TextField(
              onChanged: (value) => setState(() => _communitySearch = value),
              onSubmitted: (_) => _loadCommunityRoutes(),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search routes...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, size: 20, color: _primaryGreen),
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _primaryGreen, width: 1.5),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Community List
          if (_isLoadingCommunity)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_communityRoutes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Text('No routes found. Be the first to share one!'),
              ),
            )
          else
            ..._communityRoutes.map((route) => _buildCommunityCard(route)),
            
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Helper Widget: สร้างปุ่มเลือกช่วงเวลา (Week/Month/Year)
  Widget _buildFilterTab(String label, String value) {
    final isSelected = _statsFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _statsFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _primaryGreen,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Helper for Dashboard Mini Stats
  Widget _buildMiniStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: _primaryGreen),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  // Helper for Community Cards
  Widget _buildCommunityCard(ManualRouteItem route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.map_rounded, color: _primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${route.creatorFullName ?? 'Unknown'} • ${route.runCount} runs',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${route.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => widget.onNavigate(1),
                icon: Icon(Icons.visibility_outlined, size: 18, color: Colors.grey.shade700),
                label: Text('Map', style: TextStyle(color: Colors.grey.shade700)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  if (!widget.controller.isAuthenticated) {
                    widget.onNavigate(4);
                    return;
                  }
                  setState(() => _isLoadingCommunity = true);
                  try {
                    await widget.controller.startRun(
                      manualRouteId: route.id,
                      notes: 'Following shared route: ${route.name}',
                    );
                    if (!mounted) return;
                    widget.onNavigate(2);
                  } catch (error) {
                    if (!mounted) return;
                    setState(() => _error = '$error');
                  } finally {
                    if (mounted) setState(() => _isLoadingCommunity = false);
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}