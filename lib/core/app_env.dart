// core/app_env.dart
class AppEnv {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const envName = String.fromEnvironment('ENV_NAME', defaultValue: 'staging');

  static bool get isProd => envName == 'prod';

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. '
        'Run with --dart-define-from-file=env/staging.json',
      );
    }
  }
}
