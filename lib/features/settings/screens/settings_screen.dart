
import 'package:flutter/material.dart' hide AnimationStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../models/animation_style.dart';
import '../../../providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to log out?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted) return;

    try {
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.asData?.value != null;

    String styleLabel(AnimationStyle st) => switch (st) {
          AnimationStyle.neon => l10n.styleNeon,
          AnimationStyle.floating3d => l10n.style3d,
          AnimationStyle.liquid => l10n.styleLiquid,
          AnimationStyle.particle => l10n.styleParticle,
          AnimationStyle.minimal => l10n.styleMinimal,
          AnimationStyle.cinematic => l10n.styleCinematic,
        };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.language,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'hi', label: Text('हिंदी')),
              ButtonSegment(value: 'mr', label: Text('मराठी')),
            ],
            selected: {s.locale.languageCode},
            onSelectionChanged: (v) =>
                ctrl.setLocale(Locale(v.first)),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.theme,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.themeDark),
              ),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) =>
                ctrl.setThemeMode(v.first),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.animationStyle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final st in AnimationStyle.values)
                ChoiceChip(
                  label: Text(styleLabel(st)),
                  selected: s.animationStyle == st,
                  onSelected: (_) =>
                      ctrl.setAnimationStyle(st),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.reducedMotion),
            value: s.reducedMotion,
            onChanged: ctrl.setReducedMotion,
          ),

          // Logout section
          if (isLoggedIn) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Account',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
              ),
              title: Text(
                l10n.logout,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Sign out of your account'),
              onTap: () => _logout(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
