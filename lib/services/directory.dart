import '../core/http.dart';
import '../models/models.dart';

/// Diretório oficial de servidores Mastodon (joinmastodon.org).
class ServerDirectory {
  ServerDirectory._();

  static const _base = 'https://api.joinmastodon.org';

  static const categoryLabels = {
    'general': 'Geral',
    'regional': 'Regional',
    'tech': 'Tecnologia',
    'art': 'Arte',
    'music': 'Música',
    'games': 'Games',
    'academia': 'Academia',
    'activism': 'Ativismo',
    'lgbt': 'LGBTQIA+',
    'books': 'Livros',
    'hobby': 'Hobbies',
    'journalism': 'Jornalismo',
    'food': 'Comida',
    'sports': 'Esportes',
    'furry': 'Furry',
    'bipoc': 'Pessoas negras e indígenas',
    'religion': 'Religião',
  };

  static Future<List<Community>> servers({
    String? language,
    String? category,
  }) async {
    final data = await Api.instance.get(
      '$_base/servers',
      query: {'language': ?language, 'category': ?category},
    ) as List;
    final list = [
      for (final s in data)
        if (s is Map)
          Community(
            id: s['domain'] as String,
            kind: CommunityKind.server,
            network: Network.mastodon,
            name: s['domain'] as String,
            title: s['domain'] as String,
            description: s['description'] as String?,
            banner: s['proxied_thumbnail'] as String?,
            blurhash: s['blurhash'] as String?,
            members: s['total_users'] as int?,
            activeMembers: s['last_week_users'] as int?,
            url: 'https://${s['domain']}',
            language: s['language'] as String?,
            category: s['category'] as String?,
            instance: s['domain'] as String,
            approvalRequired: s['approval_required'] as bool? ?? false,
          ),
    ];
    list.sort((a, b) => (b.activeMembers ?? 0).compareTo(a.activeMembers ?? 0));
    return list;
  }
}
