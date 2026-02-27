import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final initialThemeModeProvider = Provider<ThemeMode>((ref) {
  throw UnimplementedError(
      'initialThemeModeProvider must be overridden in main.dart');
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.read(initialThemeModeProvider);
});
