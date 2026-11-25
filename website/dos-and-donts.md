# DOs & Don'ts

Practical patterns for keeping your dependency graphs clean, modular, and easy to test.

## 1. Keep circuits small and scoped to features

Keep the root circuit focused on shared app-wide dependencies (auth, networking, storage) and place feature-specific wires in a `CircuitProvider` around that feature. Smaller, feature-scoped circuits are faster to build, easier to reason about, and simpler to override in widget tests.

```dart
// ✅ Do: scope feature dependencies to the feature subtree
CircuitProvider(
  tag: AppScope.global,
  wires: [
    Wire(() => ApiClient()),
  ],
  builder: (context, state) => AppShell(
    child: CircuitProvider(
      tag: AppScope.checkout,
      wires: [
        Wire(() => CheckoutRepository(CircuitProvider.of(context, tag: AppScope.global).get<ApiClient>())),
        TriggerWire.takes<CheckoutRepository>().to(PlaceOrderAction.new),
      ],
      builder: (context, _) => const CheckoutScreen(),
    ),
  ),
)

// ❌ Don't: register every feature's services and actions in one monolithic root circuit
CircuitProvider(
  wires: [
    Wire(() => ApiClient()),
    Wire(() => CheckoutRepository(...)),
    Wire(() => ProfileRepository(...)),
    Wire(() => SettingsRepository(...)),
    // ...50 more feature wires loaded at app startup
  ],
  builder: ...,
)
```

---

## 2. Match the wire type to its responsibility

Use `Wire` for synchronous singletons, `AsyncWire` for asynchronous setup, and `TriggerWire` for callable `CircuitAction` classes.

```dart
// ✅ Do: use AsyncWire for async factories and TriggerWire for actions
final wires = [
  AsyncWire(() async => await SharedPreferences.getInstance()),
  TriggerWire.takes<UserService>().to(SendEmailAction.new),
];

// ❌ Don't: return a Future from a sync Wire or register a CircuitAction with Wire
final badWires = [
  Wire(() async => await SharedPreferences.getInstance()), // Bypassed by wave runner
  Wire.takes<UserService>().to(SendEmailAction.new),       // Violates action blueprint
];
```

::: tip Catch this automatically
Enabling [`circuitry_analyzer_plugin`](/tooling#analyzer-plugin) flags both mistakes in your IDE as you type (`circuitry_avoid_async_in_wire` and `circuitry_prefer_trigger_wire`).
:::

---

## 3. Use `Enum` tags instead of wrapper types

When you need multiple instances of the same type (such as two HTTP clients or environment configs), distinguish them with an `Enum` tag rather than creating empty wrapper classes.

```dart
enum ApiTarget { public, authenticated }

// ✅ Do: tag distinct instances of the same type
final wires = [
  Wire.tag(() => HttpClient(baseUrl: 'https://public.api'), tag: ApiTarget.public),
  Wire.tag(() => HttpClient(baseUrl: 'https://auth.api'), tag: ApiTarget.authenticated),
];

final authClient = circuit.getTagged<HttpClient, ApiTarget>(ApiTarget.authenticated);

// ❌ Don't: register the same untagged type twice (throws DuplicateWireException)
final badWires = [
  Wire(() => HttpClient(baseUrl: 'https://public.api')),
  Wire(() => HttpClient(baseUrl: 'https://auth.api')),
];
```

---

## 4. Put side effects in `CircuitProvider.listener`

Keep `builder` purely declarative. Trigger navigation, snackbars, or error logging inside `listener`, which runs once per state transition.

```dart
// ✅ Do: handle one-off side effects in listener
CircuitProvider(
  wires: [...],
  listener: (context, state) {
    if (state case CircuitFailure(:final error)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Initialization failed: $error')),
      );
    }
  },
  builder: (context, state) => switch (state) {
    CircuitReady() => const HomeScreen(),
    CircuitBuilding() => const LoadingScreen(),
    CircuitFailure() => const RetryScreen(),
  },
)

// ❌ Don't: call Navigator or ScaffoldMessenger inside builder
CircuitProvider(
  wires: [...],
  builder: (context, state) {
    if (state is CircuitFailure) {
      ScaffoldMessenger.of(context).showSnackBar(...); // Triggers build-phase error
    }
    return const SizedBox();
  },
)
```

---

## 5. Attach `onDispose` hooks for managed resources

Any service that opens a connection, stream, or controller should declare an `onDispose` callback so `circuit.dispose()` (or `CircuitProvider` unmount) cleans it up in reverse topological order.

```dart
// ✅ Do: pair async/resourceful wires with onDispose
AsyncWire.takes<DatabaseConfig>().to(
  (config) async => DatabaseService.open(config),
  onDispose: (db) => db.close(),
)
```

---

## 6. Treat `Circuit` as DI, not reactive state

Wires hold singletons and do not notify widgets when internal values change. `CircuitBuilder<T>` is simply syntactic sugar for `CircuitProvider.of(context).get<T>()`.

```dart
// ✅ Do: expose a ValueNotifier / Stream from your service and listen to it in the UI
final counter = CircuitProvider.of(context).get<CounterService>();
ValueListenableBuilder<int>(
  valueListenable: counter.count,
  builder: (context, value, _) => Text('$value'),
)

// ❌ Don't: expect CircuitBuilder<CounterService> to rebuild when counter.increment() is called
CircuitBuilder<CounterService>(
  builder: (context, counter) => Text('${counter.rawInt}'), // Won't rebuild on mutation
)
```

---

## 7. Prefer tear-offs over wrapper closures

When wiring a zero-argument or single-dependency constructor (or factory function), pass a tear-off like `ApiClient.new` or `UserService.new` instead of wrapping it in `() => ApiClient()` or `(db) => UserService(db)`. It keeps wire lists concise and easier to scan.

```dart
// ✅ Do: pass constructor or function tear-offs directly
final wires = [
  Wire(ApiClient.new),
  AsyncWire.takes<DatabaseConfig>().to(DatabaseManager.open),
  Wire.takes<DatabaseService>().to(UserService.new),
];

// ❌ Don't: wrap tear-off-compatible constructors in redundant lambdas
final verboseWires = [
  Wire(() => ApiClient()),
  AsyncWire.takes<DatabaseConfig>().to((config) => DatabaseManager.open(config)),
  Wire.takes<DatabaseService>().to((db) => UserService(db)),
];
```

---

## 8. Keep heavy async initialization out of the root circuit

Register only crucial, app-wide async services in your global or root circuit so app startup stays fast. Move slow or heavy async initializations into a scoped sub-circuit near the feature that needs them, and handle the loading/error states by reacting to `CircuitState`.

```dart
// ✅ Do: keep the root circuit fast and defer heavy async work to a feature circuit
CircuitProvider(
  tag: AppScope.global,
  wires: [
    Wire(AuthConfig.new),
    AsyncWire.takes<AuthConfig>().to(SessionStore.open), // Crucial app-wide service
  ],
  builder: (context, state) => switch (state) {
    CircuitReady() => const AppRouter(),
    CircuitBuilding() => const SplashScreen(),
    CircuitFailure(:final error) => FatalErrorScreen(error: error),
  },
)

// Inside the feature that actually needs the heavy service:
CircuitProvider(
  tag: AppScope.analytics,
  wires: [
    AsyncWire(() async => await HeavyAnalyticsEngine.warmUp()),
  ],
  builder: (context, state) => switch (state) {
    CircuitReady() => const AnalyticsDashboard(),
    CircuitBuilding() => const DashboardSkeleton(),
    CircuitFailure(:final error) => RetryView(error: error),
  },
)

// ❌ Don't: block app startup with slow, feature-only async services in the root circuit
CircuitProvider(
  wires: [
    AsyncWire.takes<AuthConfig>().to(SessionStore.open),
    AsyncWire(() async => await HeavyAnalyticsEngine.warmUp()), // Delays entire app launch
    AsyncWire(() async => await SearchIndex.buildFromDisk()),     // Blocks splash screen
  ],
  builder: ...,
)
```
