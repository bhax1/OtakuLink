import 'package:shared_preferences/shared_preferences.dart';

abstract class SearchLocalDataSource {
  Future<List<String>> getSearchHistory();
  Future<void> saveSearchHistory(String query);
  Future<void> clearSearchHistory();
}

class SearchLocalDataSourceImpl implements SearchLocalDataSource {
  static const _keyRecent = 'searchHistory_recent';
  static const _maxHistory = 10;

  @override
  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRecent) ?? <String>[];
  }

  @override
  Future<void> saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_keyRecent) ?? <String>[];

    history.remove(query);
    history.insert(0, query);

    if (history.length > _maxHistory) {
      history = history.sublist(0, _maxHistory);
    }

    await prefs.setStringList(_keyRecent, history);
  }

  @override
  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecent);
  }
}
