import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'monetization_state.dart';

abstract interface class MonetizationRepository {
  Future<MonetizationState> fetchMyState();
}

final monetizationRepositoryProvider = Provider<MonetizationRepository?>(
  (ref) => null,
);
