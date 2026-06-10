import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';

class RunsScreen extends StatefulWidget {
  const RunsScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<RunsScreen> createState() => _RunsScreenState();
}

class _RunsScreenState extends State<RunsScreen> {
  List<RunItem> _runs = const [];
  List<ManualRouteItem> _routes = const [];
  RunItem? _activeRun;
  RunItem? _selectedRun;
  Timer? _timer;
  int _elapsedSeconds = 0;
  double _distanceKm = 3.0;
  int _stepCount = 0;
  int? _selectedRouteId;
  String? _message;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.controller.isAuthenticated) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final runs = await widget.controller.getRuns();
      final routes = await widget.controller.getManualRoutes();
      if (!mounted) return;
      RunItem? activeRun;
      for (final run in runs) {
        if (run.status == 'active') {
          activeRun = run;
          break;
        }
      }
      setState(() {
        _runs = runs;
        _routes = routes;
        _activeRun = activeRun;
        if (_activeRun != null) {
          _elapsedSeconds = _activeRun!.durationSeconds;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds += 1;
        _stepCount = (_elapsedSeconds * 2.8).round();
      });
    });
  }

  Future<void> _startRun() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final run = await widget.controller.startRun(
        manualRouteId: _selectedRouteId,
        notes: 'Tracked from Runna mobile',
      );
      if (!mounted) return;
      setState(() {
        _activeRun = run;
        _elapsedSeconds = 0;
        _stepCount = 0;
      });
      _startTimer();
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finishRun() async {
    final activeRun = _activeRun;
    if (activeRun == null) return;
    _timer?.cancel();
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final finished = await widget.controller.finishRun(
        runId: activeRun.id,
        distanceKm: _distanceKm,
        durationSeconds: _elapsedSeconds,
        stepCount: _stepCount,
      );
      if (!mounted) return;
      setState(() {
        _activeRun = null;
        _selectedRun = finished;
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isAuthenticated) {
      return const ListView(
        padding: EdgeInsets.all(20),
        children: [
          SectionTitle('Runs', subtitle: 'Track activity and receive AI performance insights'),
          SizedBox(height: 16),
          RunnaCard(child: Text('Sign in to start runs and view AI summaries.')),
        ],
      );
    }

    RunItem? latestAnalyzed;
    for (final run in _runs) {
      if (run.status == 'finished' && run.aiInsight != null) {
        latestAnalyzed = run;
        break;
      }
    }
    final displayRun = _selectedRun ?? latestAnalyzed;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Runs', subtitle: 'Track distance, pace, steps, and AI feedback'),
        const SizedBox(height: 16),
        RunnaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _activeRun == null ? 'Ready to run' : 'Active run #${_activeRun!.id}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric(label: 'Time', value: _formatDuration(_elapsedSeconds)),
                  _Metric(label: 'Distance', value: '${_distanceKm.toStringAsFixed(1)} km'),
                  _Metric(label: 'Steps', value: '$_stepCount'),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: _selectedRouteId,
                decoration: const InputDecoration(labelText: 'Optional saved route'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Free run')),
                  ..._routes.map(
                    (route) => DropdownMenuItem<int?>(
                      value: route.id,
                      child: Text(route.name),
                    ),
                  ),
                ],
                onChanged: _activeRun == null
                    ? (value) => setState(() => _selectedRouteId = value)
                    : null,
              ),
              const SizedBox(height: 12),
              Text('Distance (km): ${_distanceKm.toStringAsFixed(1)}'),
              Slider(
                value: _distanceKm,
                min: 0.5,
                max: 21.0,
                divisions: 41,
                label: _distanceKm.toStringAsFixed(1),
                onChanged: _activeRun == null ? (value) => setState(() => _distanceKm = value) : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading || _activeRun != null ? null : _startRun,
                      child: const Text('Start run'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _isLoading || _activeRun == null ? null : _finishRun,
                      child: const Text('Finish & analyze'),
                    ),
                  ),
                ],
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, style: const TextStyle(color: RunnaColors.danger)),
              ],
            ],
          ),
        ),
        if (displayRun != null && displayRun.aiInsight != null) ...[
          const SizedBox(height: 20),
          const SectionTitle('AI performance summary'),
          const SizedBox(height: 12),
          RunnaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InsightBlock(title: 'Insight', body: displayRun.aiInsight!),
                const SizedBox(height: 12),
                _InsightBlock(title: 'Reasoning', body: displayRun.aiReasoning ?? ''),
                const SizedBox(height: 12),
                _InsightBlock(title: 'Recommendations', body: displayRun.aiRecommendations ?? ''),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle('Run history'),
            TextButton(onPressed: _isLoading ? null : _load, child: const Text('Refresh')),
          ],
        ),
        const SizedBox(height: 12),
        if (_runs.isEmpty)
          const RunnaCard(child: Text('No runs yet.'))
        else
          ..._runs.map(
            (run) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RunnaCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Run #${run.id} • ${run.status}'),
                  subtitle: Text(
                    '${run.distanceKm.toStringAsFixed(2)} km • ${_formatDuration(run.durationSeconds)} • '
                    '${run.stepCount} steps'
                    '${run.avgPaceMinPerKm != null ? ' • ${run.avgPaceMinPerKm!.toStringAsFixed(2)} min/km' : ''}',
                  ),
                  trailing: run.aiInsight != null ? const Icon(Icons.auto_awesome, color: RunnaColors.primary) : null,
                  onTap: () => setState(() => _selectedRun = run),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
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

class _InsightBlock extends StatelessWidget {
  const _InsightBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: RunnaColors.primaryDark)),
        const SizedBox(height: 6),
        Text(body),
      ],
    );
  }
}
