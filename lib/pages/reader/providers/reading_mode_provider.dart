import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';

enum ReadingMode { vertical, horizontalLTR, horizontalRTL }

class ReadingModeNotifier extends Notifier<ReadingMode> {
  @override
  ReadingMode build() {
    _loadInitialMode();
    return ReadingMode.vertical;
  }

  Future<void> _loadInitialMode() async {
    final savedMode = await LocalCacheService.getSetting('reading_mode',
        defaultValue: 'vertical');
    if (savedMode == 'horizontalLTR') {
      state = ReadingMode.horizontalLTR;
    } else if (savedMode == 'horizontalRTL') {
      state = ReadingMode.horizontalRTL;
    } else {
      state = ReadingMode.vertical;
    }
  }

  void setMode(ReadingMode mode) {
    state = mode;
    final modeString = mode.toString().split('.').last;
    LocalCacheService.updateLocalSetting('reading_mode', modeString);
  }
}

final readingModeProvider =
    NotifierProvider<ReadingModeNotifier, ReadingMode>(ReadingModeNotifier.new);
