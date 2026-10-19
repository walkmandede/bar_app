// core/app_exception.dart
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns any error into a short message that is safe to show to the user.
String errorMessage(Object error) {
  if (error is AppException) return error.message;
  if (error is PostgrestException) {
    if (error.code == '23505') {
      return 'This value already exists. Please use a different one.';
    }
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}
