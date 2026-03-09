import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/providers/supabase_provider.dart';
import 'package:otakulink/features/reader/domain/repositories/reader_repository_interface.dart';
import 'reader_repository_impl.dart';

final readerRepositoryProvider = Provider<ReaderRepositoryInterface>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReaderRepositoryImpl(client);
});
