import 'package:flutter_test/flutter_test.dart';
import 'package:jabuticaba/models/models.dart';
import 'package:jabuticaba/services/moderation.dart';
import 'package:jabuticaba/ui/nav.dart';

void main() {
  group('links externos', () {
    test('aceita apenas http e https com host', () {
      expect(isSafeExternalUrl('https://mastodon.social/@ana'), isTrue);
      expect(isSafeExternalUrl('http://example.com/a'), isTrue);
      expect(isSafeExternalUrl('javascript:alert(1)'), isFalse);
      expect(isSafeExternalUrl('file:///etc/passwd'), isFalse);
      expect(isSafeExternalUrl('tel:+5511999999999'), isFalse);
      expect(isSafeExternalUrl('intent://scan/#Intent;end'), isFalse);
      expect(isSafeExternalUrl('https://'), isFalse);
      expect(isSafeExternalUrl('  '), isFalse);
    });
  });

  group('moderação por rede', () {
    test('bloqueio cobre ActivityPub e Bluesky', () {
      expect(ModerationApi.canBlock(Network.mastodon), isTrue);
      expect(ModerationApi.canBlock(Network.pixelfed), isTrue);
      expect(ModerationApi.canBlock(Network.lemmy), isTrue);
      expect(ModerationApi.canBlock(Network.bluesky), isTrue);
      expect(ModerationApi.canBlock(Network.loops), isFalse);
      expect(ModerationApi.canBlock(Network.peertube), isFalse);
    });

    test('silenciar não aparece no Lemmy', () {
      expect(ModerationApi.canMute(Network.mastodon), isTrue);
      expect(ModerationApi.canMute(Network.bluesky), isTrue);
      expect(ModerationApi.canMute(Network.lemmy), isFalse);
    });

    test('denúncia não aparece em rede sem API', () {
      expect(ModerationApi.canReport(Network.mastodon), isTrue);
      expect(ModerationApi.canReport(Network.bluesky), isTrue);
      expect(ModerationApi.canReport(Network.lemmy), isTrue);
      expect(ModerationApi.canReport(Network.funkwhale), isFalse);
      expect(ModerationApi.canReport(Network.castopod), isFalse);
    });
  });
}
