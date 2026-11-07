
import 'package:codevisualizer/models/animation_style.dart';
import 'package:codevisualizer/providers/settings_provider.dart';
import 'package:flutter/material.dart' hide AnimationStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> createContainer() async {
  SharedPreferences.setMockInitialValues({});

  final prefs = await SharedPreferences.getInstance();

  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

void main() {
  test('Default settings are correct', () async {
    final container = await createContainer();
    addTearDown(container.dispose);

    final settings = container.read(settingsProvider);

    expect(settings.locale.languageCode, 'en');
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.animationStyle, AnimationStyle.neon);
    expect(settings.playbackSpeed, 1.0);
    expect(settings.reducedMotion, false);
  });

  test('Language and animation style can be changed', () async {
    final container = await createContainer();
    addTearDown(container.dispose);

    final controller = container.read(settingsProvider.notifier);

    await controller.setLocale(const Locale('mr'));
    await controller.setAnimationStyle(AnimationStyle.liquid);

    final settings = container.read(settingsProvider);

    expect(settings.locale.languageCode, 'mr');
    expect(settings.animationStyle, AnimationStyle.liquid);
  });
}
