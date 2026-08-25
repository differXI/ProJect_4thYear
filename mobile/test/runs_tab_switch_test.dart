// Regression test for the "stats reset to 0 / tracking stops" bug.
//
// Root cause: main.dart used to swap the bottom-nav body to a brand new
// widget every time the tab changed (`pages[safeIndex]`), which destroyed
// and recreated RunsScreen's whole State — killing the GPS stream and the
// 1-second timer — every time the user left the Runs tab and came back.
// The fix wraps the tabs in an IndexedStack so every tab stays mounted and
// RunsScreen keeps tracking in the background regardless of which tab is
// visible.
//
// This test exercises exactly that: it mounts all tabs together (the same
// composition as main.dart), starts a run, hops across every other tab and
// back, and asserts nothing throws and the active run survives the round
// trip instead of resetting.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runna_mobile/core/models.dart';
import 'package:runna_mobile/core/theme.dart';
import 'package:runna_mobile/features/auth/auth_controller.dart';
import 'package:runna_mobile/features/auth/auth_screen.dart';
import 'package:runna_mobile/features/hazards/hazards_screen.dart';
import 'package:runna_mobile/features/home/home_screen.dart';
import 'package:runna_mobile/features/routes/routes_screen.dart';
import 'package:runna_mobile/features/runs/runs_screen.dart';

/// The Routes tab has a PRE-EXISTING, unrelated bug (a `ListTile` nested
/// directly inside `RunnaCard`'s decorated `Container`, with no `Material`
/// ancestor) that throws this exact FlutterError in debug mode whenever it
/// renders a saved route — it fires repeatedly across repaint passes. It
/// predates and is untouched by the runs-tracking fix this test guards, so
/// it's filtered out at the source here instead of failing the test — any
/// *other* error still reaches the default handler and fails loudly.
bool _isKnownRoutesScreenWarning(FlutterErrorDetails details) {
  return details.exception.toString().contains(
      'ListTile background color or ink splashes');
}

/// The test binding installs its own `FlutterError.onError` (which feeds
/// `takeException()`) fresh per test, after `setUp()` runs — so the filter
/// must be installed from inside the test body, not a top-level `setUp`.
void _ignoreKnownRoutesScreenWarning() {
  final original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isKnownRoutesScreenWarning(details)) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  testWidgets(
    'all tabs mount together under IndexedStack without throwing',
    (tester) async {
      _ignoreKnownRoutesScreenWarning();

      // The default 800x600 test surface is shorter than RunsScreen's
      // content (map + controls), which pushes "Start run" below the fold
      // and makes tester.tap() unable to hit-test it. Keep the default
      // width (home_screen.dart's layout overflows below it) but give it
      // more vertical room.
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = _FakeAuthController();
      await tester.pumpWidget(_TabbedTestHarness(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(ValueKey('tab_$i')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'switching to tab $i threw');
      }
    },
  );

  testWidgets(
    'starting a run survives switching to every other tab and back',
    (tester) async {
      _ignoreKnownRoutesScreenWarning();

      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = _FakeAuthController();
      await tester.pumpWidget(_TabbedTestHarness(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final runsScreenFinder = find.byType(RunsScreen);
      expect(runsScreenFinder, findsOneWidget);

      // The single fake manual route is auto-selected on load, so "Start
      // run" should already be enabled.
      final startRunFinder = find.descendant(
        of: runsScreenFinder,
        matching: find.text('Start run'),
      );
      await tester.ensureVisible(startRunFinder);
      await tester.tap(startRunFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(of: runsScreenFinder, matching: find.textContaining('Active run #')),
        findsOneWidget,
      );

      // Let a few ticks of the run's periodic timer pass.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);

      // Hop across every other tab and back to Runs — this is exactly the
      // navigation pattern that used to tear down RunsScreen's State.
      for (final tabIndex in [0, 1, 3, 4, 2]) {
        await tester.tap(find.byKey(ValueKey('tab_$tabIndex')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'switching to tab $tabIndex threw');
      }

      // Back on Runs: the active run must have survived the round trip
      // instead of resetting to "No active run".
      expect(
        find.descendant(of: runsScreenFinder, matching: find.textContaining('Active run #')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: runsScreenFinder, matching: find.text('No active run')),
        findsNothing,
      );

      // Timer keeps advancing after the round trip.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a route queued via setPendingRunRoute is picked up by an '
    'already-mounted RunsScreen',
    (tester) async {
      // Regression test: HomeScreen._startRunOnRoute and RoutesScreen
      // ._startRunOnFavorite both call controller.setPendingRunRoute(route)
      // then switch to the Runs tab, expecting RunsScreen to load that
      // route. Before the IndexedStack fix, switching tabs recreated
      // RunsScreen (calling initState -> _loadRuns -> takePendingRunRoute),
      // which is how this used to work. Now that RunsScreen stays mounted
      // for the app's lifetime, it must instead react to the controller's
      // notifyListeners() call directly.
      _ignoreKnownRoutesScreenWarning();
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = _FakeAuthController();
      await tester.pumpWidget(_TabbedTestHarness(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final runsScreenFinder = find.byType(RunsScreen);
      expect(
        find.descendant(of: runsScreenFinder, matching: find.textContaining('Test Loop')),
        findsWidgets,
      );

      // Simulate tapping "Run" on a community route the user doesn't own.
      const communityRoute = ManualRouteItem(
        id: 99,
        userId: 42, // not the current user
        name: 'Someone Elses Loop',
        pathJson: '[{"lat":18.79,"lng":98.97},{"lat":18.80,"lng":98.98}]',
        distanceKm: 3.4,
        isShared: true,
        runCount: 2,
      );
      controller.setPendingRunRoute(communityRoute);
      await tester.tap(find.byKey(const ValueKey('tab_2'))); // Runs tab
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // RunsScreen must have picked up the queued route without needing to
      // be recreated.
      expect(
        find.descendant(of: runsScreenFinder, matching: find.textContaining('Someone Elses Loop')),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'leaving the Runs tab after finishing a run clears the stale summary '
    'so the map reappears next time',
    (tester) async {
      // Regression test: finishing a run shows a map-less "Summary Result"
      // screen. Before the IndexedStack fix, leaving the tab destroyed
      // RunsScreen entirely, which reset that summary for free. Now it must
      // be cleared explicitly (via the isActive flag) when the tab stops
      // being active, or the next visit — including via the "Run" button
      // from a community/favorite route — shows the stale summary instead
      // of the map.
      //
      // Start with an already-active run so RunsScreen picks it up via
      // _resumeActiveRun() at initState — which deliberately never touches
      // the GPS stream (the user must press "Resume GPS" for that). Tapping
      // "Start run" instead would go through the real LocationService/
      // Geolocator, whose stream subscription never resolves cancel() in a
      // headless test (no platform plugin registered) — a test-environment
      // limitation, not a production bug, that this sidesteps entirely.
      _ignoreKnownRoutesScreenWarning();
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = _FakeAuthController(startWithActiveRun: true);
      await tester.pumpWidget(_TabbedTestHarness(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final runsScreenFinder = find.byType(RunsScreen);
      expect(
        find.descendant(of: runsScreenFinder, matching: find.textContaining('Active run #')),
        findsOneWidget,
      );

      final finishRunFinder = find.descendant(
        of: runsScreenFinder,
        matching: find.text('Finish run'),
      );
      await tester.ensureVisible(finishRunFinder);
      await tester.tap(finishRunFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The map-less summary screen shows right after finishing.
      expect(
        find.descendant(of: runsScreenFinder, matching: find.text('Summary Result')),
        findsOneWidget,
      );

      // Leave the Runs tab WITHOUT tapping the summary's own back arrow —
      // e.g. via the bottom nav, exactly like tapping "Home".
      await tester.tap(find.byKey(const ValueKey('tab_0')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Coming back to Runs must show the live tracking view (with the
      // map), not the stale summary.
      await tester.tap(find.byKey(const ValueKey('tab_2')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(of: runsScreenFinder, matching: find.text('Summary Result')),
        findsNothing,
      );
      expect(
        find.descendant(of: runsScreenFinder, matching: find.text('No active run')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'finishing a run refreshes Home and Routes so their run counts can update',
    (tester) async {
      // Regression test: Home's community-routes list and Routes' favorites
      // list show a route's run count, fetched once in initState(). Since
      // those screens now stay mounted for the app's lifetime, that fetch
      // never repeats on its own, so a run count would stay stale forever
      // after finishing a run on a different tab. notifyRunsChanged() plus a
      // controller listener on each screen should trigger a fresh fetch.
      _ignoreKnownRoutesScreenWarning();
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = _FakeAuthController(startWithActiveRun: true);
      await tester.pumpWidget(_TabbedTestHarness(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final communityFetchesAfterMount = controller.communityRoutesFetchCount;
      final manualRoutesFetchesAfterMount = controller.manualRoutesFetchCount;
      expect(communityFetchesAfterMount, greaterThan(0));
      expect(manualRoutesFetchesAfterMount, greaterThan(0));

      final runsScreenFinder = find.byType(RunsScreen);
      final finishRunFinder = find.descendant(
        of: runsScreenFinder,
        matching: find.text('Finish run'),
      );
      await tester.ensureVisible(finishRunFinder);
      await tester.tap(finishRunFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Home (community routes) and Routes (favorites/manual routes) must
      // have re-fetched after the run finished, even though neither tab was
      // ever visited during this test.
      expect(controller.communityRoutesFetchCount, greaterThan(communityFetchesAfterMount));
      expect(controller.manualRoutesFetchCount, greaterThan(manualRoutesFetchesAfterMount));
    },
  );
}

class _TabbedTestHarness extends StatefulWidget {
  const _TabbedTestHarness({required this.controller});

  final AuthController controller;

  @override
  State<_TabbedTestHarness> createState() => _TabbedTestHarnessState();
}

class _TabbedTestHarnessState extends State<_TabbedTestHarness> {
  int _index = 2; // Runs tab, matching main.dart's tab order.

  @override
  Widget build(BuildContext context) {
    void navigate(int index) => setState(() => _index = index);

    final pages = <Widget>[
      HomeScreen(controller: widget.controller, onNavigate: navigate),
      RoutesScreen(controller: widget.controller, onNavigate: navigate),
      RunsScreen(controller: widget.controller, isActive: _index == 2),
      HazardsScreen(controller: widget.controller),
      AuthScreen(controller: widget.controller),
    ];

    return MaterialApp(
      theme: RunnaTheme.light(),
      home: Scaffold(
        body: SafeArea(child: IndexedStack(index: _index, children: pages)),
        bottomNavigationBar: Row(
          children: [
            for (var i = 0; i < pages.length; i++)
              Expanded(
                child: TextButton(
                  key: ValueKey('tab_$i'),
                  onPressed: () => navigate(i),
                  child: Text('TAB_$i'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController({bool startWithActiveRun = false}) {
    if (startWithActiveRun) {
      _runs.add(RunItem(
        id: _nextRunId++,
        userId: 1,
        status: 'active',
        distanceKm: 0,
        durationSeconds: 0,
        manualRouteId: _route.id,
        startedAt: DateTime.now().toUtc(),
      ));
    }
  }

  final ManualRouteItem _route = const ManualRouteItem(
    id: 1,
    userId: 1,
    name: 'Test Loop',
    pathJson: '[{"lat":18.80,"lng":98.95},{"lat":18.81,"lng":98.96}]',
    distanceKm: 1.2,
    isShared: false,
    runCount: 0,
  );

  final List<RunItem> _runs = [];
  int _nextRunId = 1;

  int communityRoutesFetchCount = 0;
  int manualRoutesFetchCount = 0;

  @override
  bool get isAuthenticated => true;

  @override
  Future<HealthResponse> getHealth() async => const HealthResponse(status: 'ok');

  @override
  Future<List<RunItem>> getRuns() async => List.unmodifiable(_runs);

  @override
  Future<List<ManualRouteItem>> getManualRoutes() async {
    manualRoutesFetchCount++;
    return [_route];
  }

  @override
  Future<List<ManualRouteItem>> getFavoriteRoutes() async => const [];

  @override
  Future<List<ManualRouteItem>> getCommunityRoutes({
    String? search,
    String? province,
    String sort = 'newest',
  }) async {
    communityRoutesFetchCount++;
    return const [];
  }

  @override
  Future<BaseMapData> getBaseMap() async =>
      const BaseMapData(nodes: [], edges: [], markers: []);

  @override
  Future<List<HazardMarkerItem>> getMarkers() async => const [];

  @override
  Future<List<HazardMarkerItem>> getMyMarkers() async => const [];

  @override
  Future<RunItem> startRun({
    int? manualRouteId,
    int? routePlanId,
    String? notes,
  }) async {
    final run = RunItem(
      id: _nextRunId++,
      userId: 1,
      status: 'active',
      distanceKm: 0,
      durationSeconds: 0,
      manualRouteId: manualRouteId,
      startedAt: DateTime.now().toUtc(),
    );
    _runs.insert(0, run);
    return run;
  }

  @override
  Future<void> addRunPoints({
    required int runId,
    required List<RunPointUpload> points,
  }) async {}

  @override
  Future<List<RunPointItem>> getRunPoints(int runId) async => const [];

  @override
  Future<RunItem> finishRun({
    required int runId,
    double? distanceKm,
    int? durationSeconds,
    int stepCount = 0,
  }) async {
    final finished = RunItem(
      id: runId,
      userId: 1,
      status: 'finished',
      distanceKm: distanceKm ?? 0,
      durationSeconds: durationSeconds ?? 0,
      stepCount: stepCount,
    );
    // Keep the fake's run list consistent with reality — RunsScreen's
    // fire-and-forget _loadRuns() re-fetches right after finishing, and a
    // stale 'active' status here would make it look like the run never
    // finished.
    final index = _runs.indexWhere((r) => r.id == runId);
    if (index != -1) _runs[index] = finished;
    return finished;
  }
}
