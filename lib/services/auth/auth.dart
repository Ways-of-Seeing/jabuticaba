import '../../core/http.dart';
import '../../models/account.dart';

const _appName = 'jabuticaba';
const _website = 'https://jabuticaba.social';
const oobRedirect = 'urn:ietf:wg:oauth:2.0:oob';

final _api = Api.instance;

/// Normaliza o que a pessoa digitou: `https://Mastodon.Social/`,
/// `@ana@mastodon.social` ou `mastodon.social` viram `mastodon.social`.
String normalizeHost(String input) {
  var s = input.trim().toLowerCase();
  if (s.contains('@')) s = s.split('@').where((p) => p.isNotEmpty).last;
  s = s.replaceFirst(RegExp(r'^https?://'), '');
  return s.split('/').first;
}

/// Descobre o software de um servidor pelo NodeInfo (mastodon, pixelfed,
/// lemmy, gotosocial, akkoma, misskey…).
Future<String?> detectSoftware(String host) async {
  try {
    final wk = await _api.get('https://$host/.well-known/nodeinfo');
    final links = (wk['links'] as List).cast<Map>();
    final info = await _api.get(links.last['href'] as String);
    return (info['software'] as Map?)?['name'] as String?;
  } catch (_) {
    return null;
  }
}

/// Informações de cadastro de um servidor Mastodon.
class ServerSignupInfo {
  const ServerSignupInfo({
    required this.host,
    required this.title,
    required this.open,
    required this.approval,
    required this.rules,
    this.description,
    this.thumbnail,
    this.minAge,
    this.reasonRequired = false,
    this.users,
  });

  final String host;
  final String title;
  final bool open;
  final bool approval;
  final bool reasonRequired;
  final List<String> rules;
  final String? description;
  final String? thumbnail;

  /// Idade mínima exigida (Mastodon 4.4+ pede data de nascimento).
  final int? minAge;
  final int? users;
}

class MastodonAuth {
  MastodonAuth._();

  static const scopes = 'read write follow';

  static Future<ServerSignupInfo> signupInfo(String host) async {
    final i = await _api.get('https://$host/api/v2/instance', cache: false);
    final reg = i['registrations'] as Map? ?? const {};
    List<String> rules = const [];
    try {
      final r = await _api.get('https://$host/api/v1/instance/rules');
      rules = [for (final x in r as List) (x as Map)['text'] as String];
    } catch (_) {
      rules = [
        for (final x in (i['rules'] as List? ?? const []))
          (x as Map)['text'] as String,
      ];
    }
    return ServerSignupInfo(
      host: host,
      title: i['title'] as String? ?? host,
      description: i['description'] as String?,
      thumbnail: (i['thumbnail'] as Map?)?['url'] as String?,
      open: reg['enabled'] as bool? ?? false,
      approval: reg['approval_required'] as bool? ?? false,
      reasonRequired:
          reg['reason_required'] as bool? ??
          (reg['approval_required'] as bool? ?? false),
      minAge: reg['min_age'] as int?,
      rules: rules,
      users: (i['usage'] as Map?)?['users']?['active_month'] as int?,
    );
  }

  static Future<(String, String)> registerApp(
    String host,
    String redirectUri,
  ) async {
    final app = await _api.send(
      'POST',
      'https://$host/api/v1/apps',
      form: {
        'client_name': _appName,
        'redirect_uris': redirectUri,
        'scopes': scopes,
        'website': _website,
      },
    );
    return (app['client_id'] as String, app['client_secret'] as String);
  }

  static Uri authorizeUrl(String host, String clientId, String redirectUri) =>
      Uri.https(host, '/oauth/authorize', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes,
      });

  static Future<String> exchangeCode({
    required String host,
    required String clientId,
    required String clientSecret,
    required String code,
    required String redirectUri,
  }) async {
    final t = await _api.send(
      'POST',
      'https://$host/oauth/token',
      form: {
        'grant_type': 'authorization_code',
        'code': code.trim(),
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'scope': scopes,
      },
    );
    return t['access_token'] as String;
  }

  static Future<Account> verify(
    String host,
    String token, {
    String? software,
  }) async {
    final a = await _api.send(
      'GET',
      'https://$host/api/v1/accounts/verify_credentials',
      bearer: token,
    );
    final acct = a['acct'] as String? ?? a['username'] as String;
    return Account(
      kind: AccountKind.mastodon,
      server: host,
      userId: '${a['id']}',
      handle: acct.contains('@') ? acct : '$acct@$host',
      token: token,
      displayName: a['display_name'] as String? ?? '',
      avatar: a['avatar'] as String?,
      software: software,
    );
  }

  /// Cria a conta pela API do Mastodon (o mesmo caminho dos apps oficiais).
  /// A conta só funciona depois que a pessoa confirma o e-mail.
  static Future<Account> register({
    required String host,
    required String username,
    required String email,
    required String password,
    String? reason,
    DateTime? birthDate,
  }) async {
    final (id, secret) = await registerApp(host, oobRedirect);
    final app = await _api.send(
      'POST',
      'https://$host/oauth/token',
      form: {
        'grant_type': 'client_credentials',
        'client_id': id,
        'client_secret': secret,
        'redirect_uri': oobRedirect,
        'scope': scopes,
      },
    );
    final res = await _api.send(
      'POST',
      'https://$host/api/v1/accounts',
      bearer: app['access_token'] as String,
      form: {
        'username': username,
        'email': email,
        'password': password,
        'agreement': 'true',
        'locale': 'pt-BR',
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (birthDate != null)
          'date_of_birth':
              '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
      },
    );
    return Account(
      kind: AccountKind.mastodon,
      server: host,
      userId: '',
      handle: '$username@$host',
      token: res['access_token'] as String,
      displayName: username,
      software: 'mastodon',
      pending: true,
    );
  }

  /// Converte o erro 422 do cadastro em mensagens por campo.
  static Map<String, String> signupErrors(Object error) {
    if (error is! ApiException || error.body is! Map) return {'_': '$error'};
    final details = (error.body as Map)['details'];
    if (details is! Map) return {'_': error.message};
    const known = {
      'ERR_TAKEN': 'Já está em uso',
      'ERR_BLOCKED': 'Não é aceito neste servidor',
      'ERR_UNREACHABLE': 'Não parece existir',
      'ERR_TOO_SHORT': 'Curto demais',
      'ERR_TOO_LONG': 'Longo demais',
      'ERR_INVALID': 'Formato inválido',
      'ERR_RESERVED': 'Reservado',
      'ERR_ACCEPTED': 'É preciso aceitar as regras',
      'ERR_BELOW_LIMIT': 'Idade abaixo do mínimo do servidor',
    };
    return {
      for (final e in details.entries)
        '${e.key}': [
          for (final d in (e.value as List).cast<Map>())
            known[d['error']] ?? d['description'] as String? ?? '${d['error']}',
        ].join(' · '),
    };
  }
}

class BlueskyAuth {
  BlueskyAuth._();

  static const entryway = 'https://bsky.social';

  /// Encontra o PDS (servidor de dados) de uma conta a partir do handle ou DID.
  static Future<String> resolvePds(String identifier) async {
    if (identifier.contains('@') && !identifier.startsWith('did:')) {
      return entryway; // e-mail
    }
    var did = identifier;
    if (!did.startsWith('did:')) {
      final r = await _api.get(
        'https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle',
        query: {'handle': identifier.replaceFirst('@', '')},
      );
      did = r['did'] as String;
    }
    final doc = did.startsWith('did:web:')
        ? await _api.get('https://${did.substring(8)}/.well-known/did.json')
        : await _api.get('https://plc.directory/$did');
    for (final s in (doc['service'] as List? ?? const []).cast<Map>()) {
      if ('${s['id']}'.endsWith('#atproto_pds')) {
        return s['serviceEndpoint'] as String;
      }
    }
    return entryway;
  }

  static Future<Account> login(
    String identifier,
    String appPassword, {
    String? authFactorToken,
  }) async {
    final id = identifier.trim().replaceFirst(RegExp(r'^@'), '');
    final pds = await resolvePds(id);
    final s = await _api.send(
      'POST',
      '$pds/xrpc/com.atproto.server.createSession',
      json: {
        'identifier': id,
        'password': appPassword.trim(),
        if (authFactorToken != null && authFactorToken.isNotEmpty)
          'authFactorToken': authFactorToken.trim(),
      },
    );
    final did = s['did'] as String;
    var account = Account(
      kind: AccountKind.bluesky,
      server: pds,
      userId: did,
      handle: s['handle'] as String,
      token: s['accessJwt'] as String,
      refreshToken: s['refreshJwt'] as String,
    );
    try {
      final p = await _api.get(
        'https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile',
        query: {'actor': did},
      );
      account = account.copyWith(
        displayName: p['displayName'] as String? ?? '',
        avatar: p['avatar'] as String?,
      );
    } catch (_) {}
    return account;
  }

  static Future<Account> refresh(Account a) async {
    final s = await _api.send(
      'POST',
      '${a.server}/xrpc/com.atproto.server.refreshSession',
      bearer: a.refreshToken,
    );
    return a.copyWith(
      token: s['accessJwt'] as String,
      refreshToken: s['refreshJwt'] as String,
    );
  }

  static bool isExpired(Object e) =>
      e is ApiException &&
      (e.status == 400 || e.status == 401) &&
      e.body is Map &&
      const {'ExpiredToken', 'InvalidToken'}.contains((e.body as Map)['error']);
}

class LemmyAuth {
  LemmyAuth._();

  static Future<Account> login(
    String host,
    String user,
    String password, {
    String? totp,
  }) async {
    final r = await _api.send(
      'POST',
      'https://$host/api/v3/user/login',
      json: {
        'username_or_email': user.trim(),
        'password': password,
        if (totp != null && totp.isNotEmpty) 'totp_2fa_token': totp.trim(),
      },
    );
    final jwt = r['jwt'] as String?;
    if (jwt == null) {
      throw ApiException(
        'Login não concluído (verifique o e-mail ou a aprovação da conta)',
      );
    }
    final site = await _api.send(
      'GET',
      'https://$host/api/v3/site',
      bearer: jwt,
    );
    final person =
        site['my_user']?['local_user_view']?['person'] as Map? ?? const {};
    final name = person['name'] as String? ?? user;
    return Account(
      kind: AccountKind.lemmy,
      server: host,
      userId: name,
      handle: '$name@$host',
      token: jwt,
      displayName: person['display_name'] as String? ?? '',
      avatar: person['avatar'] as String?,
      software: 'lemmy',
    );
  }
}

/// Funkwhale: OAuth2 próprio (apps criados sem login) e cadastro pela API.
class FunkwhaleAuth {
  FunkwhaleAuth._();

  static const scopes = 'read write';

  static Future<(String, String)> registerApp(
    String host,
    String redirectUri,
  ) async {
    final app = await _api.send(
      'POST',
      'https://$host/api/v1/oauth/apps/',
      json: {'name': _appName, 'redirect_uris': redirectUri, 'scopes': scopes},
    );
    return (app['client_id'] as String, app['client_secret'] as String);
  }

  static Uri authorizeUrl(String host, String clientId, String redirectUri) =>
      Uri.https(host, '/authorize', {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'scope': scopes,
        'state': 'jabuticaba',
      });

  static Future<String> exchangeCode({
    required String host,
    required String clientId,
    required String clientSecret,
    required String code,
    required String redirectUri,
  }) async {
    final t = await _api.send(
      'POST',
      'https://$host/api/v1/oauth/token/',
      form: {
        'grant_type': 'authorization_code',
        'code': code.trim(),
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
      },
    );
    return t['access_token'] as String;
  }

  static Future<Account> verify(String host, String token) async {
    final u = await _api.send(
      'GET',
      'https://$host/api/v1/users/me/',
      bearer: token,
    );
    final avatar = (u['avatar'] as Map?)?['urls'] as Map?;
    return Account(
      kind: AccountKind.funkwhale,
      server: host,
      userId: '${u['id']}',
      handle: '${u['username']}@$host',
      token: token,
      displayName: u['name'] as String? ?? '',
      avatar: (avatar?['medium_square_crop'] ?? avatar?['original']) as String?,
      software: 'funkwhale',
    );
  }

  /// Informações públicas do pod para a tela de cadastro.
  static Future<ServerSignupInfo> signupInfo(String host) async {
    final n = await _api.get('https://$host/api/v1/instance/nodeinfo/2.0/');
    final meta = n['metadata'] as Map? ?? const {};
    return ServerSignupInfo(
      host: host,
      title: (meta['nodeName'] as String?)?.trim().isNotEmpty ?? false
          ? meta['nodeName'] as String
          : host,
      description:
          meta['shortDescription'] as String? ??
          meta['longDescription'] as String?,
      open: n['openRegistrations'] as bool? ?? false,
      approval: false,
      rules: [
        if ((meta['rules'] as String? ?? '').trim().isNotEmpty)
          meta['rules'] as String,
      ],
      users: (n['usage'] as Map?)?['users']?['activeMonth'] as int?,
    );
  }

  static Future<void> register({
    required String host,
    required String username,
    required String email,
    required String password,
  }) => _api.send(
    'POST',
    'https://$host/api/v1/auth/registration/',
    json: {
      'username': username,
      'email': email,
      'password1': password,
      'password2': password,
    },
  );

  /// Erros do cadastro do Funkwhale vêm como `{campo: [mensagens]}`.
  static Map<String, String> signupErrors(Object error) {
    if (error is! ApiException || error.body is! Map) return {'_': '$error'};
    final out = <String, String>{};
    (error.body as Map).forEach((k, v) {
      final msg = v is List ? v.join(' · ') : '$v';
      out[k == 'password1' || k == 'password2'
              ? 'password'
              : (k == 'non_field_errors' ? '_' : '$k')] =
          msg;
    });
    return out;
  }
}
