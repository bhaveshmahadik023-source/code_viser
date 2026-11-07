import 'package:flutter/material.dart' hide AnimationStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/animation_style.dart';

/// Overridden in main() with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

@immutable
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.locale,
    required this.animationStyle,
    required this.reducedMotion,
    required this.playbackSpeed,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final AnimationStyle animationStyle;
  final bool reducedMotion;
  final double playbackSpeed;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    AnimationStyle? animationStyle,
    bool? reducedMotion,
    double? playbackSpeed,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
        animationStyle: animationStyle ?? this.animationStyle,
        reducedMotion: reducedMotion ?? this.reducedMotion,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      );
}

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final code = _prefs.getString(PrefsKeys.locale);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == _prefs.getString(PrefsKeys.themeMode),
        orElse: () => ThemeMode.dark,
      ),
      locale: Locale(
        AppConstants.supportedLanguageCodes.contains(code) ? code! : 'en',
      ),
      animationStyle:
          AnimationStyle.fromName(_prefs.getString(PrefsKeys.animationStyle)),
      reducedMotion: _prefs.getBool(PrefsKeys.reducedMotion) ?? false,
      playbackSpeed: _prefs.getDouble(PrefsKeys.playbackSpeed) ?? 1.0,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(PrefsKeys.themeMode, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _prefs.setString(PrefsKeys.locale, locale.languageCode);
  }

  Future<void> setAnimationStyle(AnimationStyle style) async {
    state = state.copyWith(animationStyle: style);
    await _prefs.setString(PrefsKeys.animationStyle, style.name);
  }

  Future<void> setReducedMotion(bool value) async {
    state = state.copyWith(reducedMotion: value);
    await _prefs.setBool(PrefsKeys.reducedMotion, value);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _prefs.setDouble(PrefsKeys.playbackSpeed, speed);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);