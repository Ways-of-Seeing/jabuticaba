import '../core/http.dart';
import '../models/account.dart';
import '../models/models.dart';

/// Motivos de denúncia mostrados na interface.
enum ReportReason {
  spam('Spam ou golpe'),
  abuse('Assédio, ódio ou violência'),
  sensitive('Conteúdo sensível mostrado sem aviso'),
  other('Outro motivo');

  const ReportReason(this.label);
  final String label;
}

/// Ações de moderação nas redes que oferecem API para isso.
///
/// Mastodon/Pixelfed e Lemmy resolvem contas e posts remotos no servidor da
/// conta antes de agir; o Bluesky usa os procedimentos do AT Protocol.
class ModerationApi {
  ModerationApi._();

  static final _api = Api.instance;

  static bool canBlock(Network n) =>
      n == Network.mastodon ||
      n == Network.pixelfed ||
      n == Network.bluesky ||
      n == Network.lemmy;

  static bool canMute(Network n) =>
      n == Network.mastodon || n == Network.pixelfed || n == Network.bluesky;

  static bool canReport(Network n) =>
      n == Network.mastodon ||
      n == Network.pixelfed ||
      n == Network.bluesky ||
      n == Network.lemmy;

  static Future<void> block(Account a, Author who) async {
    switch (a.kind) {
      case AccountKind.mastodon:
        final id = await _mastodonAccountId(a, who);
        await _api.send(
          'POST',
          'https://${a.server}/api/v1/accounts/$id/block',
          bearer: a.token,
        );
      case AccountKind.bluesky:
        await _api.send(
          'POST',
          '${a.server}/xrpc/com.atproto.repo.createRecord',
          bearer: a.token,
          json: {
            'repo': a.userId,
            'collection': 'app.bsky.graph.block',
            'record': {
              r'$type': 'app.bsky.graph.block',
              'subject': who.id,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            },
          },
        );
      case AccountKind.lemmy:
        final id = await _lemmyPersonId(a, who);
        await _api.send(
          'POST',
          'https://${a.server}/api/v3/user/block',
          bearer: a.token,
          json: {'person_id': id, 'block': true},
        );
      case AccountKind.funkwhale:
        throw ApiException('Sua conta Funkwhale não bloqueia pessoas');
    }
  }

  static Future<void> mute(Account a, Author who) async {
    switch (a.kind) {
      case AccountKind.mastodon:
        final id = await _mastodonAccountId(a, who);
        await _api.send(
          'POST',
          'https://${a.server}/api/v1/accounts/$id/mute',
          bearer: a.token,
          form: {'notifications': 'true'},
        );
      case AccountKind.bluesky:
        await _api.send(
          'POST',
          '${a.server}/xrpc/app.bsky.graph.muteActor',
          bearer: a.token,
          json: {'actor': who.id},
        );
      case AccountKind.lemmy:
      case AccountKind.funkwhale:
        throw ApiException('Esta rede não tem silenciar pela API');
    }
  }

  static Future<void> report(
    Account a, {
    required Author author,
    Post? post,
    required ReportReason reason,
    String? detail,
  }) async {
    final comment = (detail ?? '').trim();
    switch (a.kind) {
      case AccountKind.mastodon:
        final accountId = await _mastodonAccountId(a, author);
        String? statusId;
        if (post != null) {
          statusId = await _mastodonStatusId(a, post);
        }
        await _api.send(
          'POST',
          'https://${a.server}/api/v1/reports',
          bearer: a.token,
          form: {
            'account_id': accountId,
            'comment': comment,
            'category': _mastodonCategory(reason),
            'status_ids[]': ?statusId,
          },
        );
      case AccountKind.bluesky:
        final subject = post?.ref != null && post?.cid != null
            ? {
                r'$type': 'com.atproto.repo.strongRef',
                'uri': post!.ref,
                'cid': post.cid,
              }
            : {r'$type': 'com.atproto.admin.defs#repoRef', 'did': author.id};
        await _api.send(
          'POST',
          '${a.server}/xrpc/com.atproto.moderation.createReport',
          bearer: a.token,
          json: {
            'reasonType': _blueskyReason(reason),
            'subject': subject,
            if (comment.isNotEmpty) 'reason': comment,
          },
        );
      case AccountKind.lemmy:
        if (post == null) {
          throw ApiException('O Lemmy não denuncia perfis, só posts');
        }
        final id = await _lemmyPostId(a, post);
        await _api.send(
          'POST',
          'https://${a.server}/api/v3/post/report',
          bearer: a.token,
          json: {
            'post_id': id,
            'reason': comment.isEmpty ? reason.label : comment,
          },
        );
      case AccountKind.funkwhale:
        throw ApiException('O Funkwhale não tem denúncia pelo app');
    }
  }

  static String _mastodonCategory(ReportReason r) => switch (r) {
    ReportReason.spam => 'spam',
    ReportReason.abuse => 'violation',
    ReportReason.sensitive => 'violation',
    ReportReason.other => 'other',
  };

  static String _blueskyReason(ReportReason r) => switch (r) {
    ReportReason.spam => 'com.atproto.moderation.defs#reasonSpam',
    ReportReason.abuse => 'com.atproto.moderation.defs#reasonViolation',
    ReportReason.sensitive => 'com.atproto.moderation.defs#reasonMisleading',
    ReportReason.other => 'com.atproto.moderation.defs#reasonOther',
  };

  static Future<String> _mastodonAccountId(Account a, Author who) async {
    final localHost = Uri.tryParse(who.url ?? '')?.host;
    if (localHost == a.server) return who.id;
    final r = await _api.send(
      'GET',
      'https://${a.server}/api/v2/search',
      bearer: a.token,
      query: {
        'q': '@${who.handle}',
        'resolve': 'true',
        'type': 'accounts',
        'limit': '1',
      },
    );
    final list = r['accounts'] as List? ?? const [];
    if (list.isEmpty) {
      throw ApiException('Seu servidor não encontrou @${who.handle}');
    }
    return '${(list.first as Map)['id']}';
  }

  static Future<String> _mastodonStatusId(Account a, Post p) async {
    if (p.instance == a.server) return p.id;
    final url = p.url;
    if (url == null) throw ApiException('Post sem endereço público');
    final r = await _api.send(
      'GET',
      'https://${a.server}/api/v2/search',
      bearer: a.token,
      query: {'q': url, 'resolve': 'true', 'type': 'statuses', 'limit': '1'},
    );
    final list = r['statuses'] as List? ?? const [];
    if (list.isEmpty) {
      throw ApiException('Seu servidor não encontrou este post');
    }
    return '${(list.first as Map)['id']}';
  }

  static Future<int> _lemmyPersonId(Account a, Author who) async {
    if (who.network == Network.lemmy &&
        Uri.tryParse(who.url ?? '')?.host == a.server) {
      return int.parse(who.id);
    }
    final q = who.url;
    if (q == null) throw ApiException('Perfil sem endereço público');
    final r = await _api.send(
      'GET',
      'https://${a.server}/api/v3/resolve_object',
      bearer: a.token,
      query: {'q': q},
    );
    final person = r['person'];
    final id = person is Map
        ? (person['person'] is Map ? person['person']['id'] : person['id'])
        : null;
    if (id == null) {
      throw ApiException('Seu servidor não encontrou @${who.handle}');
    }
    return int.parse('$id');
  }

  static Future<int> _lemmyPostId(Account a, Post p) async {
    if (p.instance == a.server) return int.parse(p.id);
    final q = p.url;
    if (q == null) throw ApiException('Post sem endereço público');
    final r = await _api.send(
      'GET',
      'https://${a.server}/api/v3/resolve_object',
      bearer: a.token,
      query: {'q': q},
    );
    final post = r['post'];
    final id = post is Map
        ? (post['post'] is Map ? post['post']['id'] : post['id'])
        : null;
    if (id == null) {
      throw ApiException('Seu servidor não encontrou este post');
    }
    return int.parse('$id');
  }
}
