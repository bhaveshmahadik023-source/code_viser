
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/generated/app_localizations.dart';
import '../../app/theme/app_colors.dart';
import '../../app/routes/app_routes.dart';
import '../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();

    _controller.forward();
    _finishSplash();
  }

  Future<void> _finishSplash() async {
    // Keep the splash screen visible for at least 2 seconds.
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Wait for Firebase's first authentication result.
      final user = await ref.read(authStateProvider.future);

      if (!mounted) return;

      if (user == null) {
        context.go(AppRoutes.login);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      // If authentication checking fails, open Login.
      if (!mounted) return;

      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.85,
              end: 1.0,
            ).animate(fade),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (r) =>
                      AppColors.heroGradient.createShader(r),
                  child: const Icon(
                    Icons.auto_graph_rounded,
                    size: 88,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.appName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(l10n.tagline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
