import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/providers/supabase_provider.dart';
import 'package:otakulink/features/chat/domain/entities/chat_room_entity.dart';
import 'package:otakulink/features/chat/domain/repositories/chat_repository_interface.dart';
import 'package:otakulink/features/chat/data/repositories/chat_repository_impl.dart';

final chatRepositoryProvider = Provider<ChatRepositoryInterface>((ref) {
  return ChatRepositoryImpl(client: ref.watch(supabaseClientProvider));
});

final conversationsStreamProvider = StreamProvider<List<ChatRoomEntity>>((ref) {
  return ref.watch(chatRepositoryProvider).getConversationsStream();
});
