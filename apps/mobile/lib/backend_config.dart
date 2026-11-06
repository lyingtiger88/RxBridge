enum RxBridgeBackendMode { localDemo, supabaseStaging, iranianServer }

/// Selected at build time. Never infer environment from a URL or user role.
class RxBridgeBackendConfig {
  static const modeName = String.fromEnvironment('RXBRIDGE_BACKEND', defaultValue: 'localDemo');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const iranApiBaseUrl = String.fromEnvironment('RXBRIDGE_API_BASE_URL');

  static RxBridgeBackendMode get mode => switch (modeName) {
    'localDemo' => RxBridgeBackendMode.localDemo,
    'supabaseStaging' => RxBridgeBackendMode.supabaseStaging,
    'iranianServer' => RxBridgeBackendMode.iranianServer,
    _ => throw StateError('Unknown RXBRIDGE_BACKEND: $modeName'),
  };

  static void validate() {
    switch (mode) {
      case RxBridgeBackendMode.localDemo:
        return;
      case RxBridgeBackendMode.supabaseStaging:
        if (!supabaseUrl.startsWith('https://') || supabaseAnonKey.isEmpty) {
          throw StateError('Supabase staging requires HTTPS SUPABASE_URL and SUPABASE_ANON_KEY');
        }
      case RxBridgeBackendMode.iranianServer:
        if (!iranApiBaseUrl.startsWith('https://')) {
          throw StateError('Iranian server requires HTTPS RXBRIDGE_API_BASE_URL');
        }
    }
  }
}
