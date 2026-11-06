import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';
import 'backend_contracts.dart';
import 'supabase_backend.dart';

/// Composition root. The UI receives this abstraction, never a vendor client.
class RxBridgeBackendFactory {
  static RxBridgeBackend? _instance;

  static RxBridgeBackend? get instance => _instance;

  static Future<RxBridgeBackend?> initialize() async {
    RxBridgeBackendConfig.validate();
    switch (RxBridgeBackendConfig.mode) {
      case RxBridgeBackendMode.localDemo:
        _instance = null; // Existing demo store remains the local prototype.
        return null;
      case RxBridgeBackendMode.supabaseStaging:
        await Supabase.initialize(
          url: RxBridgeBackendConfig.supabaseUrl,
          anonKey: RxBridgeBackendConfig.supabaseAnonKey,
        );
        _instance = SupabaseRxBridgeBackend(Supabase.instance.client);
        return _instance;
      case RxBridgeBackendMode.iranianServer:
        throw UnsupportedError(
          'Iranian REST adapter is not implemented yet. Refusing silent fallback.',
        );
    }
  }
}
