import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:circuitry_devtools_extension/src/screens/circuitry_devtools_screen.dart';
import 'package:circuitry_devtools_extension/src/services/mock_circuitry_service_client.dart';
import 'package:circuitry_devtools_extension/src/widgets/circuit_navigator.dart';
import 'package:circuitry_devtools_extension/src/widgets/dag_canvas.dart';
import 'package:circuitry_devtools_extension/src/widgets/toolbar.dart';
import 'package:circuitry_devtools_extension/src/widgets/wave_waterfall_profiler.dart';
import 'package:circuitry_devtools_extension/src/widgets/wire_detail_drawer.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Circuitry DevTools UI Widgets', () {
    late MockCircuitryServiceClient client;
    late CircuitryDevToolsController controller;

    setUp(() async {
      client = .new();
      controller = .new(client);
      await controller.init();
    });

    tearDown(() {
      controller.dispose();
      client.dispose();
    });

    testWidgets('CircuitNavigator renders circuit list and handles selection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: CircuitNavigator(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Circuits'), findsOneWidget);
      expect(find.text('AppScope.global'), findsOneWidget);
      expect(find.text('FeatureScope.orders'), findsOneWidget);

      // Tap on orders circuit
      await tester.tap(find.text('FeatureScope.orders'));
      await tester.pumpAndSettle();

      expect(controller.selectedCircuitId, 'circuit_1');
    });

    testWidgets('DevToolsToolbar interacts with filters and view switchers', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DevToolsToolbar(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Enters search text
      await tester.enterText(find.byType(TextField), 'analytics');
      await tester.pumpAndSettle();
      expect(controller.searchQuery, 'analytics');

      // Taps filter chips
      await tester.tap(find.text('Unresolved Only'));
      await tester.pumpAndSettle();
      expect(controller.showUnresolvedOnly, isTrue);

      await tester.tap(find.text('Async Only'));
      await tester.pumpAndSettle();
      expect(controller.showAsyncOnly, isTrue);

      await tester.ensureVisible(find.text('Critical Path'));
      await tester.tap(find.text('Critical Path'));
      await tester.pumpAndSettle();
      expect(controller.highlightCriticalPath, isTrue);

      // Switches to Waterfall view
      await tester.ensureVisible(find.text('Startup Waterfall'));
      await tester.tap(find.text('Startup Waterfall'));
      await tester.pumpAndSettle();
      expect(controller.isWaterfallView, isTrue);
    });

    testWidgets('DagCanvas displays wave columns and selects nodes on tap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DagCanvas(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wave 0'), findsOneWidget);
      expect(find.text('Wave 1'), findsOneWidget);
      expect(find.text('AppConfig'), findsOneWidget);
      expect(find.text('DatabaseConnection'), findsOneWidget);

      // Tap on AppConfig node
      await tester.tap(find.text('AppConfig'));
      await tester.pumpAndSettle();

      expect(controller.selectedWire?.key, 'AppConfig');
    });

    testWidgets(
      'WireDetailDrawer inspects wire and triggers Force Initialize',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: WireDetailDrawer(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();

        // When no wire selected
        expect(find.textContaining('Select a wire node'), findsOneWidget);

        // Select uninitialized lazy wire
        controller.selectWireByKey('AnalyticsService#prod');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: WireDetailDrawer(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(AreaPaneHeader, 'AnalyticsService'),
          findsOneWidget,
        );
        expect(find.text('Wire Metadata'), findsOneWidget);
        expect(find.text('Force Initialize Singleton'), findsOneWidget);

        // Tap Force Initialize
        await tester.tap(find.text('Force Initialize Singleton'));
        await tester.pumpAndSettle();

        expect(controller.selectedWire?.isInitialized, isTrue);
        expect(
          find.text('Active instance resides in heap memory.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('WaveWaterfallProfiler renders timeline metrics and bars', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WaveWaterfallProfiler(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Startup Latency'), findsOneWidget);
      expect(find.text('Topological Waves'), findsOneWidget);
      expect(find.text('Async Singletons'), findsOneWidget);
      expect(find.textContaining('Wave 0'), findsOneWidget);
    });

    testWidgets('CircuitryDevToolsScreen renders full dashboard integration', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(home: CircuitryDevToolsScreen(serviceClient: client)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Circuits'), findsOneWidget);
      expect(find.text('AppScope.global'), findsOneWidget);
      expect(find.text('DAG Canvas'), findsOneWidget);
      expect(find.text('AppConfig'), findsOneWidget);
    });
  });
}
