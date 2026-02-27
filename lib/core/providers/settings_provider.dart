import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';
import 'package:otakulink/services/settings_service.dart';
import 'package:otakulink/core/api/mangadex_service.dart';

// 1. Strongly Typed State
class AppSettingsState {
  final bool isNsfw;
  final bool isDataSaver;
  final ThemeMode themeMode;

  AppSettingsState({
    required this.isNsfw,
    required this.isDataSaver,
    required this.themeMode,
  });

  AppSettingsState copyWith({
    bool? isNsfw,
    bool? isDataSaver,
    ThemeMode? themeMode,
  }) {
    return AppSettingsState(
      isNsfw: isNsfw ?? this.isNsfw,
      isDataSaver: isDataSaver ?? this.isDataSaver,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

// 2. The Notifier that manages the logic
class SettingsNotifier extends AsyncNotifier<AppSettingsState> {
  @override
  Future<AppSettingsState> build() async {
    // Load initial values from cache
    final nsfw =
        await LocalCacheService.getSetting('nsfw', defaultValue: false);
    final dataSaver =
        await LocalCacheService.getSetting('data_saver', defaultValue: false);
    final themeStr =
        await LocalCacheService.getSetting('theme', defaultValue: 'light');

    return AppSettingsState(
      isNsfw: nsfw,
      isDataSaver: dataSaver,
      themeMode: themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light,
    );
  }

  Future<void> updateTheme(bool isDark) async {
    final themeStr = isDark ? 'dark' : 'light';
    // Instantly update the UI state
    state = AsyncData(state.value!
        .copyWith(themeMode: isDark ? ThemeMode.dark : ThemeMode.light));
    // Save to backend/cache
    await SettingsService.updateSetting('theme', themeStr);
  }

  Future<void> updateNsfw(bool isNsfw) async {
    state = AsyncData(state.value!.copyWith(isNsfw: isNsfw));
    await SettingsService.updateSetting('nsfw', isNsfw);
    await MangaDexService.cleanCache(); // Wipe safe cache to allow new results
  }

  Future<void> updateDataSaver(bool isDataSaver) async {
    state = AsyncData(state.value!.copyWith(isDataSaver: isDataSaver));
    await SettingsService.updateSetting('data_saver', isDataSaver);
    await MangaDexService.cleanCache();
  }
}

// 3. The Global Provider
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettingsState>(() {
  return SettingsNotifier();
});
