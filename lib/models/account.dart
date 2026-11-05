import 'models.dart';

/// Família de API de uma conta conectada. Mastodon cobre também Pixelfed,
/// GoToSocial, Akkoma e outros servidores compatíveis.
enum AccountKind {
  mastodon('Mastodon e compatíveis'),
  bluesky('Bluesky'),
  lemmy('Lemmy'),
  funkwhale('Funkwhale');

  const AccountKind(this.label);
  final String label;
}

class Account {
  const Account({
    required this.kind,
    required this.server,
    required this.userId,
    required this.handle,
    required this.token,
    this.displayName = '',
    this.avatar,
    this.refreshToken,
    this.software,
    this.pending = false,
  });

  final AccountKind kind;

  /// Host do servidor (Mastodon/Lemmy) ou URL do PDS (Bluesky).
  final String server;

  /// ID da conta no servidor (Mastodon), DID (Bluesky) ou nome (Lemmy).
  final String userId;

  /// `@usuario@servidor` ou `usuario.bsky.social`.
  final String handle;
  final String token;
  final String? refreshToken;
  final String displayName;
  final String? avatar;

  /// Software do servidor quando conhecido (mastodon, pixelfed…).
  final String? software;

  /// Conta criada pelo app que ainda aguarda confirmação de e-mail.
  final bool pending;

  String get id => '${kind.name}:$handle';
  String get name => displayName.trim().isEmpty ? handle : displayName;

  /// Rede mostrada na interface (Pixelfed aparece como Pixelfed).
  Network get network => switch (kind) {
    AccountKind.bluesky => Network.bluesky,
    AccountKind.lemmy => Network.lemmy,
    AccountKind.mastodon =>
      software == 'pixelfed' ? Network.pixelfed : Network.mastodon,
    AccountKind.funkwhale => Network.funkwhale,
  };

  /// Esta conta consegue interagir com posts desta rede?
  bool canReach(Network n) => switch (kind) {
    AccountKind.bluesky => n == Network.bluesky,
    AccountKind.lemmy => n == Network.lemmy,
    // Pelo ActivityPub, uma conta Mastodon alcança Pixelfed, Lemmy, PeerTube…
    AccountKind.mastodon => n != Network.bluesky && n != Network.loops,
    // Conta Funkwhale serve para favoritar e montar a biblioteca de música.
    AccountKind.funkwhale => n == Network.funkwhale,
  };

  /// Limite de caracteres para posts novos.
  int get charLimit => switch (kind) {
    AccountKind.bluesky => 300,
    AccountKind.lemmy => 10000,
    AccountKind.mastodon => software == 'pixelfed' ? 2000 : 500,
    AccountKind.funkwhale => 0,
  };

  Account copyWith({
    String? token,
    String? refreshToken,
    String? displayName,
    String? avatar,
    bool? pending,
  }) => Account(
    kind: kind,
    server: server,
    userId: userId,
    handle: handle,
    token: token ?? this.token,
    refreshToken: refreshToken ?? this.refreshToken,
    displayName: displayName ?? this.displayName,
    avatar: avatar ?? this.avatar,
    software: software,
    pending: pending ?? this.pending,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'server': server,
    'userId': userId,
    'handle': handle,
    'token': token,
    'refreshToken': refreshToken,
    'displayName': displayName,
    'avatar': avatar,
    'software': software,
    'pending': pending,
  };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    kind: AccountKind.values.byName(j['kind'] as String),
    server: j['server'] as String,
    userId: j['userId'] as String,
    handle: j['handle'] as String,
    token: j['token'] as String,
    refreshToken: j['refreshToken'] as String?,
    displayName: j['displayName'] as String? ?? '',
    avatar: j['avatar'] as String?,
    software: j['software'] as String?,
    pending: j['pending'] as bool? ?? false,
  );
}
