import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'application/controllers/allocation_controller.dart';
import 'application/controllers/analytics_controller.dart';
import 'application/controllers/authentication_controller.dart';
import 'application/controllers/asset_controller.dart';
import 'application/controllers/budget_controller.dart';
import 'application/controllers/category_controller.dart';
import 'application/controllers/config_controller.dart';
import 'application/auth_guard_state.dart';
import 'application/controllers/shortcut_controller.dart';
import 'application/controllers/settings_controller.dart';
import 'application/controllers/transaction_controller.dart';
import 'application/controllers/recurring_controller.dart';
import 'application/controllers/theme_controller.dart';

import 'core/utils/theme.dart';
import 'data/services/account_service.dart';
import 'data/services/allocation_service.dart';
import 'data/services/auth_service.dart';
import 'data/services/backup_service.dart';
import 'data/services/budget_service.dart';
import 'data/services/category_service.dart';
import 'data/services/lazy_mode_allocation_service.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/pdf_service.dart';
import 'data/services/recurring_service.dart';
import 'data/services/shortcut_service.dart';
import 'data/services/transaction_service.dart';

import 'firebase_options.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
  }

  if (firebaseReady) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  final authService = AuthService();
  final localStorage = LocalStorageService();
  final accountService = AccountService();
  final shortcutService = ShortcutService();
  final themeController = ThemeController(localStorage);

  final configController = ConfigController(
    localStorage,
    authService,
    accountService,
    shortcutService,
  );
  await configController.loadCurrentMode();
  await themeController.loadThemeMode();

  runApp(
    MyApp(
      authService: authService,
      localStorage: localStorage,
      accountService: accountService,
      shortcutService: shortcutService,
      configController: configController,
      themeController: themeController,
      firebaseReady: firebaseReady,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final LocalStorageService localStorage;
  final AccountService accountService;
  final ShortcutService shortcutService;
  final ConfigController configController;
  final ThemeController themeController;
  final bool firebaseReady;

  const MyApp({
    super.key,
    required this.authService,
    required this.localStorage,
    required this.accountService,
    required this.shortcutService,
    required this.configController,
    required this.themeController,
    required this.firebaseReady,
  });

  @override
  Widget build(BuildContext context) {
    return _MyAppBody(
      configController: configController,
      authService: authService,
      localStorage: localStorage,
      accountService: accountService,
      shortcutService: shortcutService,
      themeController: themeController,
      firebaseReady: firebaseReady,
    );
  }
}

class _MyAppBody extends StatefulWidget {
  final AuthService authService;
  final LocalStorageService localStorage;
  final AccountService accountService;
  final ShortcutService shortcutService;
  final ConfigController configController;
  final ThemeController themeController;
  final bool firebaseReady;

  const _MyAppBody({
    required this.authService,
    required this.localStorage,
    required this.accountService,
    required this.shortcutService,
    required this.configController,
    required this.themeController,
    required this.firebaseReady,
  });

  @override
  State<_MyAppBody> createState() => _MyAppBodyState();
}

class _MyAppBodyState extends State<_MyAppBody> {
  static const MethodChannel _screenCaptureChannel = MethodChannel(
    'smart_pocket/screen_capture',
  );

  late final AppLifecycleListener _lifecycleListener;
  late final AuthenticationController _authController;
  late final TransactionController _transactionController;
  late final ShortcutController _shortcutController;
  late final CategoryController _categoryController;
  late final BudgetController _budgetController;
  late final RecurringController _recurringController;
  late final AllocationController _allocationController;
  late final AnalyticsController _analyticsController;
  late final AssetController _assetController;
  late final SettingsController _settingsController;
  late final ThemeController _themeController;
  StreamSubscription<User?>? _authStateSub;

  void _lockIfNeeded() {
    if (!AuthGuardState.biometricPromptInProgress) {
      AuthGuardState.setUnlocked(false);
    }
  }

  void _resetSessionLock() {
    if (!mounted) return;
    _lockIfNeeded();
    AuthGuardState.routerRefresh.ping();
  }

  @override
  void initState() {
    super.initState();
    _authController = AuthenticationController(
      widget.authService,
      widget.localStorage,
    );
    final accountService = widget.accountService;
    final shortcutService = widget.shortcutService;
    final transactionService = TransactionService();
    _transactionController = TransactionController(
      transactionService,
      accountService,
      LazyModeAllocationService(accountService),
      widget.authService,
    );
    _analyticsController = AnalyticsController(
      transactionService,
      accountService,
      PdfService(),
      widget.authService,
    );
    _allocationController = AllocationController(
      AssetAllocationService(),
      widget.authService,
    );
    _assetController = AssetController(
      accountService,
      widget.authService,
      transactionService,
    );
    _settingsController = SettingsController(
      widget.authService,
      BackupService(),
      transactionService,
    );
    _shortcutController = ShortcutController(
      shortcutService,
      _transactionController,
    );
    _categoryController = CategoryController(CategoryService());
    _budgetController = BudgetController(BudgetService());
    _recurringController = RecurringController(
      RecurringService(),
      widget.authService,
    );
    _themeController = widget.themeController;

    _screenCaptureChannel.setMethodCallHandler((call) async {
      if (call.method == 'screenCaptureDetected') {
        _resetSessionLock();
      }
    });

    _lifecycleListener = AppLifecycleListener(
      onPause: () {
        _lockIfNeeded();
      },
      onResume: () {
        if (AuthGuardState.biometricPromptInProgress) return;
        AuthGuardState.routerRefresh.ping();
      },
    );

    if (widget.firebaseReady) {
      _authStateSub = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) async {
        await widget.configController.handleAuthChanged(user?.uid);
        await _transactionController.handleAuthChanged();
        await _categoryController.handleAuthChanged();
        await _budgetController.handleAuthChanged();
        _shortcutController.rebind();
        _recurringController.resetBinding();
        if (user != null) {
          _recurringController.bind();
        }
      });
    }
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    _lifecycleListener.dispose();
    _screenCaptureChannel.setMethodCallHandler(null);
    _authController.dispose();
    widget.configController.dispose();
    _transactionController.dispose();
    _shortcutController.dispose();
    _categoryController.dispose();
    _budgetController.dispose();
    _recurringController.dispose();
    _allocationController.dispose();
    _analyticsController.dispose();
    _assetController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    _resetSessionLock();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConfigController>.value(
          value: widget.configController,
        ),
        ChangeNotifierProvider<ThemeController>.value(value: _themeController),

        ChangeNotifierProvider<AuthenticationController>.value(
          value: _authController,
        ),

        ChangeNotifierProvider<TransactionController>.value(
          value: _transactionController,
        ),

        ChangeNotifierProvider<ShortcutController>.value(
          value: _shortcutController,
        ),

        ChangeNotifierProvider<CategoryController>.value(
          value: _categoryController,
        ),

        ChangeNotifierProvider<BudgetController>.value(
          value: _budgetController,
        ),

        ChangeNotifierProvider<RecurringController>.value(
          value: _recurringController,
        ),

        ChangeNotifierProvider<AllocationController>.value(
          value: _allocationController,
        ),

        ChangeNotifierProvider<AnalyticsController>.value(
          value: _analyticsController,
        ),

        ChangeNotifierProvider<SettingsController>.value(
          value: _settingsController,
        ),

        ChangeNotifierProvider<AssetController>.value(value: _assetController),
      ],
      child: Builder(
        builder: (context) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: context.watch<ThemeController>().themeMode,
          routerConfig: AppRouter.router(authController: _authController),
        ),
      ),
    );
  }
}
