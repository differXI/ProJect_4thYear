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

void main() {
  testWidgets(
    'all tabs mount together under IndexedStack without throwing',
    (tester) async {
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

  testWidgets(
    'a route saved on the Routes tab shows up in the already-mounted '
    "Runs tab's route picker",
    (tester) async {
      // Regression test: RunsScreen's route picker list is otherwise only
      // fetched once at initState() (it stays mounted for the app's
      // lifetime), so a route saved on the Routes tab after that would
      // never appear there without RoutesScreen calling notifyRunsChanged()
      // and RunsScreen reacting to it.
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = _FakeAuthController();
      await tester.pumpWidget(_TabbedTestHarness(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final runsScreenFinder = find.byType(RunsScreen);

      // Simulate saving a brand new route on the Routes tab.
      controller.addManualRouteAsIfSavedElsewhere(const ManualRouteItem(
        id: 2,
        userId: 1,
        name: 'Freshly Saved Loop',
        pathJson: '[{"lat":18.82,"lng":98.94},{"lat":18.83,"lng":98.93}]',
        distanceKm: 2.6,
        isShared: false,
        runCount: 0,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Open the route picker sheet and confirm the new route is listed.
      final routePickerLabelFinder = find.descendant(
        of: runsScreenFinder,
        matching: find.text('Manual route'),
      );
      final routePickerFinder = find.ancestor(
        of: routePickerLabelFinder,
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(routePickerFinder);
      await tester.tap(routePickerFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Freshly Saved Loop'), findsOneWidget);
    },
  );

  testWidgets(
    "the route picker excludes routes merged in from another user's "
    '"Run" button that are not actually owned by the signed-in user',
    (tester) async {
      // Regression test: tapping "Run" on a community route (owned by
      // someone else) merges it into RunsScreen's _manualRoutes so it can be
      // preselected for that run — but that merge must not leak into the
      // route picker's selectable list, or routes the user never saved
      // themselves would show up there permanently.
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = _FakeAuthController();
      await tester.pumpWidget(_TabbedTestHarness(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Simulate tapping "Run" on someone else's community route.
      const othersRoute = ManualRouteItem(
        id: 77,
        userId: 999, // not the signed-in user (id 1)
        name: "Someone Else's Route",
        pathJson: '[{"lat":18.79,"lng":98.97},{"lat":18.80,"lng":98.98}]',
        distanceKm: 4.0,
        isShared: true,
        runCount: 5,
      );
      controller.setPendingRunRoute(othersRoute);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final runsScreenFinder = find.byType(RunsScreen);
      // It's preselected — shown as the current selection.
      expect(
        find.descendant(of: runsScreenFinder, matching: find.textContaining("Someone Else's Route")),
        findsWidgets,
      );

      // But opening the picker to choose a *different* route must not offer
      // it as a pick-able entry alongside the user's own saved routes.
      final routePickerLabelFinder = find.descendant(
        of: runsScreenFinder,
        matching: find.text('Manual route'),
      );
      final routePickerFinder = find.ancestor(
        of: routePickerLabelFinder,
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(routePickerFinder);
      await tester.tap(routePickerFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text("Someone Else's Route"), findsNothing);
      expect(find.text('Test Loop'), findsOneWidget);
    },
  );

  testWidgets(
    'signing in after the Runs tab already mounted loads it instead of '
    'leaving it stuck on the sign-in message',
    (tester) async {
      // Regression test: _loadRuns() bailed out with "Please sign in before
      // tracking a run" if the user wasn't authenticated *at the moment
      // this screen first mounted*, and did nothing else. Since this screen
      // now stays mounted for the app's lifetime, logging in afterwards
      // (the normal case on web, which has no persisted session to restore
      // on launch) never re-triggered it — the tab stayed stuck on the
      // sign-in message forever, even after a successful login.
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = _FakeAuthController(startAuthenticated: false);
      await tester.pumpWidget(_TabbedTestHarness(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final runsScreenFinder = find.byType(RunsScreen);
      expect(
        find.descendant(
          of: runsScreenFinder,
          matching: find.text('Please sign in before tracking a run.'),
        ),
        findsOneWidget,
      );

      controller.simulateLogin();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        find.descendant(
          of: runsScreenFinder,
          matching: find.text('Please sign in before tracking a run.'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: runsScreenFinder, matching: find.text('Start run')),
        findsOneWidget,
      );
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
  _FakeAuthController({bool startWithActiveRun = false, bool startAuthenticated = true})
      : _authenticated = startAuthenticated {
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

  late final List<ManualRouteItem> _manualRoutes = [_route];
  final List<RunItem> _runs = [];
  int _nextRunId = 1;

  @override
  UserProfile? get currentUser => const UserProfile(
        id: 1,
        firstName: 'Test',
        lastName: 'Runner',
        username: 'testrunner',
        email: 'test@example.com',
        isActive: true,
        roleId: 1,
        roleName: 'member',
      );

  int communityRoutesFetchCount = 0;
  int manualRoutesFetchCount = 0;

  /// Simulates RoutesScreen._saveRoute() creating a new route: appends it
  /// and bumps notifyRunsChanged(), exactly like the real save flow does.
  void addManualRouteAsIfSavedElsewhere(ManualRouteItem route) {
    _manualRoutes.add(route);
    notifyRunsChanged();
  }

  bool _authenticated;

  @override
  bool get isAuthenticated => _authenticated;

  /// Simulates AuthController.login() succeeding after this screen was
  /// already mounted (e.g. no persisted session on web, so the user only
  /// signs in after the app — and this tab — has already loaded).
  void simulateLogin() {
    _authenticated = true;
    notifyListeners();
  }

  @override
  Future<HealthResponse> getHealth() async => const HealthResponse(status: 'ok');

  @override
  Future<List<RunItem>> getRuns() async => List.unmodifiable(_runs);

  @override
  Future<List<ManualRouteItem>> getManualRoutes() async {
    manualRoutesFetchCount++;
    return List.unmodifiable(_manualRoutes);
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
