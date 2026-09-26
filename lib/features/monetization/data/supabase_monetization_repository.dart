import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/repository_error_mapper.dart';
import '../domain/monetization_repository.dart';
import '../domain/monetization_state.dart';

class SupabaseMonetizationRepository implements MonetizationRepository {
  SupabaseMonetizationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<MonetizationState> fetchMyState() async {
    if (_client.auth.currentUser == null) throw const SessionExpiredAppError();
    try {
      final response = await _client.rpc<Object?>('get_my_monetization_state');
      return MonetizationState.fromJson(
        Map<String, Object?>.from(response! as Map),
      );
    } catch (error) {
      if (error is AppError) rethrow;
      throw RepositoryErrorMapper.profileLoad(error);
    }
  }
}
