import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/learning/engine/tracer_registry.dart';
import '../../features/learning/screens/dry_run_screen.dart';
import '../../features/learning/screens/learning_path_screen.dart';
import '../../features/playground/screens/python_playground_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Used to tell the router to re-check redirects when login state changes.
  final refreshNotifier = ValueNotifier<int>(0);

  ref.listen(authStateProvider, (previous, next) {
    refreshNotifier.value++;
  });

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,

    // Authentication-based navigation
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentLocation = state.matchedLocation;

      final isSplash = currentLocation == AppRoutes.splash;

      final isAuthRoute = currentLocation == AppRoutes.login ||
          currentLocation == AppRoutes.signup ||
          currentLocation == AppRoutes.forgotPassword;

      // Allow splash screen to finish.
      if (isSplash) {
        return null;
      }

      // Wait for Firebase authentication.
      if (authState.isLoading) {
        return AppRoutes.splash;
      }

      // Handle authentication errors.
      if (authState.hasError) {
        return isAuthRoute ? null : AppRoutes.login;
      }

      final user = authState.asData?.value;

      // User is not logged in.
      if (user == null) {
        return isAuthRoute ? null : AppRoutes.login;
      }

      // User is already logged in.
      if (isAuthRoute) {
        return AppRoutes.home;
      }

      return null;
    },

    // Application routes
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),

      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // Learning Path screen
      GoRoute(
        path: AppRoutes.learningPath,
        builder: (context, state) => const LearningPathScreen(),
      ),

      // Python playground screen
      GoRoute(
        path: AppRoutes.pythonPlayground,
        builder: (context, state) => const PythonPlaygroundScreen(),
      ),

      // Dry run animation screen.
      // :id is the algorithm id, for example bubble-sort.
      // The old '/dry-run' route is removed because the screen now
      // needs a tracer.
      GoRoute(
        path: '/dry-run/:id',
        builder: (context, state) {
          // Find the tracer for this id.
          final create = tracerRegistry[state.pathParameters['id']];

          // Show a message if the id is not found.
          if (create == null) {
            return const Scaffold(
              body: Center(child: Text('Algorithm not found')),
            );
          }

          // Open the animation screen with the chosen algorithm.
          return DryRunScreen(tracer: create());
        },
      ),
    ],
  );

  // Clean up when the provider is removed.
  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });

  return router;
});