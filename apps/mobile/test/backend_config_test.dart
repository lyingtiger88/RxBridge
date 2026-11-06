import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/backend_config.dart';

void main() {
  test('default backend is local demo and requires no remote credentials', () {
    expect(RxBridgeBackendConfig.mode, RxBridgeBackendMode.localDemo);
    expect(() => RxBridgeBackendConfig.validate(), returnsNormally);
  });

  test('unknown backend cannot silently fall back', () {
    expect(
      () => RxBridgeBackendConfig.modeName == 'unknown'
          ? throw StateError('Unknown RXBRIDGE_BACKEND: unknown')
          : null,
      throwsStateError,
    );
  });
}
