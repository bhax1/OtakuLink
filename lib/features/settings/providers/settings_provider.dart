import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:otakulink/core/providers/shared_prefs_provider.dart';

class SettingsState {
  final ThemeMode themeMode;
  final bool showAdultContent;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.showAdultContent = false,
  });

  SettingsState copyWith({ThemeMode? themeMode, bool? showAdultContent}) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      showAdultContent: showAdultContent ?? this.showAdultContent,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _themeKey = 'settings_theme_mode';
  static const String _adultContentKey = 'settings_adult_content';

  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _prefs = ref.watch(sharedPrefsProvider);

    final themeIndex = _prefs.getInt(_themeKey);
    final themeMode = themeIndex != null
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;

    final showAdultContent = _prefs.getBool(_adultContentKey) ?? false;

    return SettingsState(
      themeMode: themeMode,
      showAdultContent: showAdultContent,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_themeKey, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> toggleAdultContent(bool show) async {
    await _prefs.setBool(_adultContentKey, show);
    state = state.copyWith(showAdultContent: show);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
