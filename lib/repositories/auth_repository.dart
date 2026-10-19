// repositories/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../core/app_exception.dart';
import '../models/app_user.dart';

class AuthRepository {
  AuthRepository(this._db);
  final SupabaseClient _db;

  Future<AppUser> login(String username, String password) async {
    final res = await _db.rpc(
      'app_login',
      params: {
        'p_username': username,
        'p_password': password,
      },
    );
    final rows = res as List;
    if (rows.isEmpty) throw const AppException('Wrong username or password.');
    return AppUser.fromJson(rows.first as Map<String, dynamic>);
  }
}
