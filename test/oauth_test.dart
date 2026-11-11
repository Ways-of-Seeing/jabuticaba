import 'package:flutter_test/flutter_test.dart';
import 'package:jabuticaba/core/http.dart';
import 'package:jabuticaba/services/auth/auth.dart';

void main() {
  group('state do OAuth', () {
    test('é aleatório e não vazio', () {
      final states = {for (var i = 0; i < 50; i++) createOAuthState()};
      expect(states, hasLength(50));
      expect(states.every((s) => s.length >= 24), isTrue);
    });
  });

  group('retorno do navegador', () {
    const state = 'abc123';

    test('devolve o código quando o state confere', () {
      expect(
        oauthCodeFromCallback(
          'jabuticaba://oauth?code=xyz&state=abc123',
          expectedState: state,
        ),
        'xyz',
      );
    });

    test('recusa state divergente', () {
      expect(
        () => oauthCodeFromCallback(
          'jabuticaba://oauth?code=xyz&state=outro',
          expectedState: state,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('recusa esquema diferente', () {
      expect(
        () => oauthCodeFromCallback(
          'https://evil.example/oauth?code=xyz&state=abc123',
          expectedState: state,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('propaga erro do servidor', () {
      expect(
        () => oauthCodeFromCallback(
          'jabuticaba://oauth?error=access_denied&state=abc123',
          expectedState: state,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'access_denied',
          ),
        ),
      );
    });

    test('exige código', () {
      expect(
        () => oauthCodeFromCallback(
          'jabuticaba://oauth?state=abc123',
          expectedState: state,
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
