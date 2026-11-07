import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/backend_config.dart';

void main() {
  test('default backend is local demo and requires no remote credentials', () {
    expect(RxBridgeBackendConfig.mode, RxBridgeBackendMode.localDemo);
    expect(() => RxBridgeBackendConfig.validate(), returnsNormally);
  });

  test('unknown backend cannot silently fall back', () {
    expect(() => RxBridgeBackendConfig.parseMode('unknown'), throwsStateError);
    expect(RxBridgeBackendConfig.parseMode('supabaseStaging'),
        RxBridgeBackendMode.supabaseStaging);
    expect(RxBridgeBackendConfig.parseMode('iranianServer'),
        RxBridgeBackendMode.iranianServer);
  });
}
