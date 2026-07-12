import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_notifier.dart';
import '../ui/screens/app_lock_screen.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/device_management_screen.dart';
import '../ui/screens/disease_scanner_screen.dart';
import '../ui/screens/error_screen.dart';
import '../ui/screens/farm_overview_screen.dart';
import '../ui/screens/farm_form_screen.dart';
import '../ui/screens/forgot_pin_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/language_selection_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/otp_verification_screen.dart';
import '../ui/screens/onboarding_screen.dart';
import '../ui/screens/pin_login_screen.dart';
import '../ui/screens/pin_setup_screen.dart';
import '../ui/screens/profile_screen.dart';
import '../ui/screens/security_logs_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/splash_screen.dart';

// Only reachable when NOT authenticated; an already-logged-in user is bounced to /dashboard.
const _preAuthRoutes = {'/login', '/otp', '/onboarding', '/splash', '/login-pin'};

// Reachable regardless of auth/lock state: forgot-pin works both for a signed-out user
// recovering via OTP and for a signed-in-but-locked user who forgot their app-lock PIN;
// pin-setup and app-lock are the destinations of those flows and must not re-trigger themselves.
const _lockBypassRoutes = {'/forgot-pin', '/pin-setup', '/app-lock'};

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: AuthNotifier.instance,
  errorBuilder: (context, state) => const ErrorScreen(),
  redirect: (context, state) {
    final auth = AuthNotifier.instance;
    final location = state.uri.path;

    if (!auth.initialized) {
      return null;
    }

    if (!auth.isAuthenticated) {
      if (_preAuthRoutes.contains(location) || location == '/forgot-pin') {
        return null;
      }
      return '/login';
    }

    if (_preAuthRoutes.contains(location)) {
      return '/dashboard';
    }

    if (_lockBypassRoutes.contains(location)) {
      return null;
    }

    if (auth.pinEnabled && !auth.appUnlocked) {
      return '/app-lock';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extra = state.extra;
        final phone = extra is Map ? extra['phone']?.toString() : null;
        return OtpVerificationScreen(initialPhone: phone);
      },
    ),
    GoRoute(
      path: '/farm-overview',
      builder: (context, state) {
        final extra = state.extra;
        final rawFarm = extra is Map ? extra['farm'] : null;
        final farm = rawFarm is Map ? Map<String, dynamic>.from(rawFarm) : null;
        return FarmOverviewScreen(initialFarm: farm);
      },
    ),
    GoRoute(
      path: '/farm-overview/:id',
      builder: (context, state) {
        final idString = state.pathParameters['id'];
        final farmId = idString != null ? int.tryParse(idString) : null;
        return FarmOverviewScreen(farmId: farmId);
      },
    ),
    GoRoute(
      path: '/farm-form',
      builder: (context, state) {
        final extra = state.extra;
        final rawFarm = extra is Map ? extra['farm'] : null;
        final farm = rawFarm is Map ? Map<String, dynamic>.from(rawFarm) : null;
        return FarmFormScreen(initialFarm: farm);
      },
    ),
    GoRoute(
      path: '/login-pin',
      builder: (context, state) => const PinLoginScreen(),
    ),
    GoRoute(
      path: '/forgot-pin',
      builder: (context, state) => const ForgotPinScreen(),
    ),
    GoRoute(
      path: '/pin-setup',
      builder: (context, state) {
        final extra = state.extra;
        final fromForgotPin = extra is Map && extra['fromForgotPin'] == true;
        return PinSetupScreen(fromForgotPin: fromForgotPin);
      },
    ),
    GoRoute(
      path: '/app-lock',
      builder: (context, state) => const AppLockScreen(),
    ),
    GoRoute(
      path: '/disease-scanner',
      builder: (context, state) => const DiseaseScannerScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/language',
      builder: (context, state) => const LanguageSelectionScreen(),
    ),
    GoRoute(
      path: '/settings/devices',
      builder: (context, state) => const DeviceManagementScreen(),
    ),
    GoRoute(
      path: '/settings/security-logs',
      builder: (context, state) => const SecurityLogsScreen(),
    ),

    ShellRoute(
      builder: (context, state, child) {
        int _indexForLocation(String loc) {
          if (loc.startsWith('/dashboard')) return 1;
          if (loc.startsWith('/profile')) return 2;
          if (loc.startsWith('/settings')) return 3;
          return 0; // default to home
        }

        final currentIndex = _indexForLocation(state.uri.path);

        return Scaffold(
          body: child,
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: currentIndex,
            onTap: (i) {
              switch (i) {
                case 0:
                  context.go('/home');
                  break;
                case 1:
                  context.go('/dashboard');
                  break;
                case 2:
                  context.go('/profile');
                  break;
                case 3:
                  context.go('/settings');
                  break;
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'முகப்பு'),
              BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'டேஷ்போர்ட்'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'சுயவிவரம்'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'அமைப்புகள்'),
            ],
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),

        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
