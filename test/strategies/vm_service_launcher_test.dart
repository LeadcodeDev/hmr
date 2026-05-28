import 'package:hmr/src/strategies/vm_service_launcher.dart';
import 'package:test/test.dart';

void main() {
  group('wsUriFromHttpUri', () {
    test('converts http to ws and appends /ws', () {
      expect(
        wsUriFromHttpUri('http://127.0.0.1:8181/'),
        'ws://127.0.0.1:8181/ws',
      );
    });

    test('converts https to wss and appends /ws', () {
      expect(
        wsUriFromHttpUri('https://127.0.0.1:8181/'),
        'wss://127.0.0.1:8181/ws',
      );
    });

    test('appends trailing slash if missing before /ws', () {
      expect(
        wsUriFromHttpUri('http://127.0.0.1:8181/abc123'),
        'ws://127.0.0.1:8181/abc123/ws',
      );
    });

    test('handles auth-token path segment', () {
      expect(
        wsUriFromHttpUri('http://127.0.0.1:8181/auth_token=/'),
        'ws://127.0.0.1:8181/auth_token=/ws',
      );
    });

    test('trims trailing whitespace from input', () {
      expect(
        wsUriFromHttpUri('http://127.0.0.1:8181/ '),
        'ws://127.0.0.1:8181/ws',
      );
    });
  });
}
