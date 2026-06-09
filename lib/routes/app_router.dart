import 'package:go_router/go_router.dart';

import '../application/auth_guard_state.dart';
import '../presentation/views/account/accounts_page.dart';
import '../presentation/views/allocation/allocation_page.dart';
import '../presentation/views/authentication/app_lock_page.dart';
import '../presentation/views/authentication/forgot_password_page.dart';
import '../presentation/views/authentication/login_page.dart';
import '../presentation/views/authentication/register_page.dart';
import '../presentation/views/authentication/smart_survey_page.dart';
import '../presentation/views/budget/budget_page.dart';
import '../presentation/views/category/category_page.dart';
import '../presentation/views/dashboard/dashboard_page.dart';
import '../presentation/views/settings/mode_page.dart';
import '../presentation/views/settings/settings_page.dart';
import '../presentation/views/shortcut/shortcut_page.dart';
import '../presentation/views/stats/stats_page.dart';
import '../presentation/views/transaction/add_transaction_page.dart';
import '../presentation/views/transaction/transaction_page.dart';
import '../presentation/views/recurring/recurring_page.dart';
import '../application/controllers/authentication_controller.dart';

class AppRouter {
  static GoRouter router({required AuthenticationController authController}) {
    return GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: AuthGuardState.routerRefresh,
      redirect: (context, state) async {
        final uid = authController.currentUserId;
        final loggedIn = uid != null;
        final loc = state.matchedLocation;
        final isAuth =
            loc == '/login' || loc == '/register' || loc == '/forgot-password';
        final isSurvey = loc == '/smart-survey';
        final isLock = loc == '/app-lock';

        if (!loggedIn && !isAuth) return '/login';
        if (!loggedIn && isLock) return '/login';
        if (loggedIn) {
          bool completed = false;
          bool biometricEnabled = false;
          try {
            completed = await authController.isSurveyCompleted(uid);
            biometricEnabled = await authController.isBiometricEnabledFor(uid);
          } catch (_) {
            completed = true;
            biometricEnabled = false;
          }
          final stillLoggedIn = authController.currentUserId != null;
          if (!stillLoggedIn) return '/login';

          if (biometricEnabled && !AuthGuardState.biometricUnlockedInSession) {
            if (!isLock) return '/app-lock';
          } else if (isLock) {
            return '/dashboard';
          }

          if (!completed && !isSurvey) return '/smart-survey';
          if (completed && (isAuth || isSurvey)) return '/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/app-lock', builder: (_, __) => const AppLockPage()),
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: '/smart-survey',
          builder: (_, __) => const SmartSurveyPage(),
        ),
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
        GoRoute(
          path: '/add-transaction',
          builder: (_, __) => const AddTransactionPage(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (_, __) => const TransactionsPage(),
        ),
        GoRoute(path: '/shortcuts', builder: (_, __) => const ShortcutsPage()),
        GoRoute(path: '/categories', builder: (_, __) => const CategoryPage()),
        GoRoute(path: '/budget', builder: (_, __) => const BudgetPage()),
        GoRoute(path: '/stats', builder: (_, __) => const StatsPage()),
        GoRoute(path: '/accounts', builder: (_, __) => const AccountPage()),
        GoRoute(path: '/mode', builder: (_, __) => const ModePage()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        GoRoute(path: '/recurring', builder: (_, __) => const RecurringPage()),
        GoRoute(
          path: '/allocation-goals',
          builder: (_, __) => const AllocationGoalPage(),
        ),
      ],
    );
  }
}
