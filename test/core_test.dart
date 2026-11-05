import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jabuticaba/models/account.dart';
import 'package:jabuticaba/models/models.dart';
import 'package:jabuticaba/services/auth/auth.dart';
import 'package:jabuticaba/ui/theme.dart';

void main() {
  group('normalizeHost', () {
    test('aceita endereço completo, URL e domínio', () {
      expect(normalizeHost('@ana@Mastodon.Social'), 'mastodon.social');
      expect(normalizeHost('https://pixelfed.social/i/web'), 'pixelfed.social');
      expect(normalizeHost('  lemmy.world '), 'lemmy.world');
    });
  });

  group('Account', () {
    const a = Account(
      kind: AccountKind.mastodon,
      server: 'pixelfed.social',
      userId: '1',
      handle: 'ana@pixelfed.social',
      token: 't',
      software: 'pixelfed',
    );

    test('ida e volta em JSON preserva os campos', () {
      final b = Account.fromJson(a.toJson());
      expect(b.id, a.id);
      expect(b.software, 'pixelfed');
      expect(b.network, Network.pixelfed);
    });

    test('conta Mastodon alcança redes ActivityPub, mas não o Bluesky', () {
      expect(a.canReach(Network.threads), isTrue);
      expect(a.canReach(Network.lemmy), isTrue);
      expect(a.canReach(Network.bluesky), isFalse);
    });

    test('limite do Bluesky é 300', () {
      const bsky = Account(kind: AccountKind.bluesky, server: 'x', userId: 'did', handle: 'a.bsky.social', token: 't');
      expect(bsky.charLimit, 300);
    });
  });

  group('JabuStyle', () {
    test('temas quadrados zeram os cantos', () {
      expect(JabuStyle.win95.r(22), BorderRadius.zero);
      expect(JabuStyle.matrix.r(14), BorderRadius.zero);
      expect(JabuStyle.jabuticaba.r(22), BorderRadius.circular(22));
    });

    test('temas monocromáticos não usam a cor da rede', () {
      expect(JabuStyle.paperwhite.network(Network.bluesky), JabuStyle.paperwhite.ink);
      expect(JabuStyle.polpa.network(Network.bluesky), isNot(JabuStyle.polpa.ink));
    });

    test('todo tema gera um ThemeData', () {
      for (final id in JabuThemeId.values) {
        final t = buildTheme(JabuStyle.of(id));
        expect(t.extension<JabuStyle>(), isNotNull, reason: id.name);
      }
    });
  });
}
