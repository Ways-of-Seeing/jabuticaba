import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/http.dart';
import '../../models/account.dart';
import '../../models/models.dart';
import '../../services/auth/auth.dart';
import '../../services/auth/loopback.dart';
import '../../services/directory.dart';
import '../../services/funkwhale.dart';
import '../../state/accounts.dart';
import '../../state/settings.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/basics.dart';

/// Abre o fluxo "Entrar no fediverso". Devolve `true` se uma conta foi
/// conectada ou criada.
Future<bool> openFediverse(
  BuildContext context, {
  FediStart start = FediStart.choose,
  String? host,
}) async {
  final r = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      settings: const RouteSettings(name: _flowRoot),
      builder: (_) => switch (start) {
        FediStart.choose => const _StartPage(),
        FediStart.connect => const _ConnectPickPage(),
        FediStart.create => const _CreatePickPage(),
        FediStart.music => const _MusicSignupPickPage(),
        FediStart.musicConnect => const _MastodonConnectPage(funkwhale: true),
        FediStart.podcaster => const _PodcasterPage(),
        FediStart.mastodonConnect => const _MastodonConnectPage(),
        FediStart.blueskyConnect => const _BlueskyConnectPage(),
        FediStart.lemmyConnect => const _LemmyConnectPage(),
        FediStart.servers => const _ServerPickPage(),
        FediStart.signup => _SignupPage(host: host ?? 'organica.social'),
      },
    ),
  );
  return r ?? false;
}

enum FediStart {
  choose,
  connect,
  create,

  /// Criar conta de música (Funkwhale).
  music,

  /// Conectar conta Funkwhale existente.
  musicConnect,

  /// Quem quer publicar um podcast.
  podcaster,

  // Páginas internas, abertas diretamente.
  mastodonConnect,
  blueskyConnect,
  lemmyConnect,
  servers,

  /// Cadastro num servidor Mastodon (`host` em [openFediverse]).
  signup,
}

const _flowRoot = '/fediverso';

void _finish(BuildContext context, {required bool ok}) {
  final nav = Navigator.of(context, rootNavigator: true);
  nav.popUntil((r) => r.settings.name == _flowRoot || r.isFirst);
  if (nav.canPop()) nav.pop(ok);
}

void _go(BuildContext context, Widget page) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute(builder: (_) => page));

// -----------------------------------------------------------------------------
// Estrutura comum das páginas do fluxo
// -----------------------------------------------------------------------------

class _FlowPage extends StatelessWidget {
  const _FlowPage({
    required this.title,
    this.subtitle,
    required this.children,
    this.step,
    this.bottom,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String? step;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: step == null
            ? null
            : Text(
                step!,
                style: context.tt.labelLarge?.copyWith(
                  color: context.jc.onTitleBar,
                ),
              ),
        actions: [
          TextButton(
            // Na barra de título colorida (Win95) o texto precisa contrastar.
            style: TextButton.styleFrom(
              foregroundColor: context.jc.onTitleBar ?? context.jc.brand,
              shape: context.jc.bevel ? const RoundedRectangleBorder() : null,
            ),
            onPressed: () => _finish(context, ok: false),
            child: const Text('Agora não'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
              children: [
                Text(
                  context.jc.headline(title),
                  style: context.tt.displaySmall,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    subtitle!,
                    style: context.tt.bodyLarge?.copyWith(
                      color: context.jc.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                ...children,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                    child: bottom,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Cartão de escolha grande (ícone, título, explicação).
class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
    this.color,
    this.badge,
  });
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;
  final Color? color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final c = color ?? jc.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: jc.r(22),
          child: Ink(
            decoration: jc.panel(),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: .16),
                    borderRadius: jc.r(16),
                  ),
                  child: Icon(icon, color: c, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title, style: context.tt.titleMedium),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: ShapeDecoration(
                                gradient: jc.accent,
                                shape: jc.pill(),
                              ),
                              child: Text(
                                badge!,
                                style: TextStyle(
                                  color: jc.onAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        text,
                        style: context.tt.bodyMedium?.copyWith(color: jc.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: jc.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.icon = Icons.lightbulb_outline_rounded});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: context.jc.panel(color: context.jc.cardHigh, base: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.jc.brand),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: context.tt.bodyMedium)),
      ],
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.jc.hot.withValues(alpha: .12),
      borderRadius: context.jc.r(16),
      border: Border.all(color: context.jc.hot.withValues(alpha: .5)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: context.jc.hot),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: context.tt.bodyMedium)),
      ],
    ),
  );
}

String _friendlyError(Object e) {
  if (e is TimeoutException) {
    return 'O servidor demorou demais para responder. Tente de novo.';
  }
  if (e is ApiException) {
    if (e.status == 401 || e.status == 403) {
      return 'Usuário ou senha não conferem.';
    }
    if (e.status == 404) return 'Não encontrei esse servidor ou endereço.';
    if (e.status == 429) {
      return 'Muitas tentativas seguidas. Espere um pouco e tente de novo.';
    }
    return e.message;
  }
  final s = '$e';
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('ClientException')) {
    return 'Não consegui falar com esse servidor. Confira o endereço e sua conexão.';
  }
  return s.replaceFirst('Exception: ', '');
}

// -----------------------------------------------------------------------------
// Início
// -----------------------------------------------------------------------------

class _StartPage extends StatelessWidget {
  const _StartPage();

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      title: 'Entrar no fediverso',
      subtitle: 'Uma conta no fediverso é como um e-mail: você escolhe onde ela mora e fala com todo mundo, de qualquer servidor.',
      children: [
        _Choice(
          icon: Icons.link_rounded,
          title: 'Já tenho conta',
          text: 'Mastodon, Pixelfed, Bluesky, Lemmy e outros. Conecte e use tudo daqui.',
          onTap: () => _go(context, const _ConnectPickPage()),
        ),
        _Choice(
          icon: Icons.auto_awesome_rounded,
          title: 'Quero criar uma conta',
          text: 'A gente te ajuda a escolher onde e cria junto, em poucos passos.',
          badge: 'fácil',
          onTap: () => _go(context, const _CreatePickPage()),
        ),
        const SizedBox(height: 8),
        const _Hint(
          'Você pode conectar várias contas — por exemplo, uma no Mastodon e outra no Bluesky — e publicar nas duas de uma vez.',
          icon: Icons.layers_rounded,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Conectar conta existente
// -----------------------------------------------------------------------------

class _ConnectPickPage extends StatelessWidget {
  const _ConnectPickPage();

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return _FlowPage(
      step: 'Conectar conta',
      title: 'Onde fica sua conta?',
      children: [
        _Choice(
          icon: Icons.forum_rounded,
          color: jc.network(Network.mastodon),
          title: 'Mastodon e compatíveis',
          text: 'Mastodon, Pixelfed, GoToSocial, Akkoma, Pleroma… Login pelo seu próprio servidor.',
          onTap: () => _go(context, const _MastodonConnectPage()),
        ),
        _Choice(
          icon: Icons.cloud_rounded,
          color: jc.network(Network.bluesky),
          title: 'Bluesky',
          text: 'Com uma senha de app — sua senha principal fica guardada só com você.',
          onTap: () => _go(context, const _BlueskyConnectPage()),
        ),
        _Choice(
          icon: Icons.groups_rounded,
          color: jc.network(Network.lemmy),
          title: 'Lemmy',
          text: 'Comunidades e discussões. Login com usuário e senha do seu servidor.',
          onTap: () => _go(context, const _LemmyConnectPage()),
        ),
        _Choice(
          icon: Icons.album_rounded,
          color: jc.network(Network.funkwhale),
          title: 'Funkwhale',
          text: 'Música: favoritos e biblioteca. Login pelo seu servidor, como no Mastodon.',
          onTap: () =>
              _go(context, const _MastodonConnectPage(funkwhale: true)),
        ),
        const _Hint(
          'O Loops ainda não permite que outros apps entrem na sua conta. Você continua vendo e seguindo os vídeos de lá por aqui.',
          icon: Icons.info_outline_rounded,
        ),
      ],
    );
  }
}

class _MastodonConnectPage extends ConsumerStatefulWidget {
  const _MastodonConnectPage({this.initialHost, this.funkwhale = false});
  final String? initialHost;

  /// O Funkwhale tem OAuth próprio, mas o fluxo é igual ao do Mastodon.
  final bool funkwhale;

  @override
  ConsumerState<_MastodonConnectPage> createState() =>
      _MastodonConnectPageState();
}

enum _OAuthPhase { input, waiting, paste }

class _MastodonConnectPageState extends ConsumerState<_MastodonConnectPage> {
  late final _server = TextEditingController(text: widget.initialHost ?? '');
  final _code = TextEditingController();
  _OAuthPhase _phase = _OAuthPhase.input;
  bool _busy = false;
  String? _error;
  Loopback? _loopback;
  String? _host;
  String? _software;
  (String, String)? _client;
  Uri? _authUrl;

  @override
  void dispose() {
    _server.dispose();
    _code.dispose();
    _loopback?.close();
    super.dispose();
  }

  Future<void> _start() async {
    final host = normalizeHost(_server.text);
    if (!host.contains('.')) {
      setState(
        () => _error = 'Digite o endereço do servidor, por exemplo mastodon.social, ou seu @usuario@servidor.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final software = await detectSoftware(host);
      if (!mounted) return;
      final funk = widget.funkwhale || software == 'funkwhale';
      if (software == 'lemmy') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _LemmyConnectPage(initialHost: host),
          ),
        );
        return;
      }
      if (software == 'misskey' ||
          software == 'sharkey' ||
          software == 'firefish' ||
          software == 'iceshrimp') {
        throw ApiException(
          'Servidores $software ainda não são suportados para login. Dá para seguir as pessoas de lá normalmente.',
        );
      }
      final loop = Loopback.supported ? await Loopback.start() : null;
      final redirect = loop?.redirectUri ?? oobRedirect;
      final client = funk
          ? await FunkwhaleAuth.registerApp(host, redirect)
          : await MastodonAuth.registerApp(host, redirect);
      final url = funk
          ? FunkwhaleAuth.authorizeUrl(host, client.$1, redirect)
          : MastodonAuth.authorizeUrl(host, client.$1, redirect);
      setState(() {
        _loopback = loop;
        _host = host;
        _software = software;
        _client = client;
        _authUrl = url;
        _phase = loop == null ? _OAuthPhase.paste : _OAuthPhase.waiting;
        _busy = false;
      });
      await openUrl(url.toString());
      if (loop != null) {
        final code = await loop.waitForCode();
        await _finishWith(code);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _phase = _OAuthPhase.input;
          _error = _friendlyError(e);
        });
      }
    }
  }

  Future<void> _finishWith(String code) async {
    final host = _host!, client = _client!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final redirect = _loopback?.redirectUri ?? oobRedirect;
      final funk = widget.funkwhale || _software == 'funkwhale';
      final token = funk
          ? await FunkwhaleAuth.exchangeCode(
              host: host,
              clientId: client.$1,
              clientSecret: client.$2,
              code: code,
              redirectUri: redirect,
            )
          : await MastodonAuth.exchangeCode(
              host: host,
              clientId: client.$1,
              clientSecret: client.$2,
              code: code,
              redirectUri: redirect,
            );
      final account = funk
          ? await FunkwhaleAuth.verify(host, token)
          : await MastodonAuth.verify(host, token, software: _software);
      await ref.read(accountsProvider.notifier).add(account);
      if (mounted) _go(context, _ConnectedPage(account: account));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _OAuthPhase.input => _FlowPage(
        step: widget.funkwhale ? 'Funkwhale' : 'Mastodon e compatíveis',
        title: widget.funkwhale
            ? 'Qual é o seu servidor de música?'
            : 'Qual é o seu servidor?',
        subtitle: widget.funkwhale
            ? 'É o endereço onde você criou a conta Funkwhale, por exemplo tunez.awadwatt.com.'
            : 'É a parte depois do segundo @ no seu endereço. Em @ana@mastodon.social, o servidor é mastodon.social.',
        bottom: FilledButton(
          onPressed: _busy ? null : _start,
          child: Text(_busy ? 'Conectando…' : 'Continuar'),
        ),
        children: [
          if (_error != null) _ErrorBox(_error!),
          TextField(
            controller: _server,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _start(),
            decoration: InputDecoration(
              hintText: widget.funkwhale
                  ? 'tunez.awadwatt.com'
                  : '@voce@mastodon.social',
              prefixIcon: Icon(
                widget.funkwhale
                    ? Icons.dns_rounded
                    : Icons.alternate_email_rounded,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h
                  in widget.funkwhale
                      ? FunkwhaleApi.signupPods
                      : const [
                          'mastodon.social',
                          'pixelfed.social',
                          'masto.donte.com.br',
                          'bolha.us',
                        ])
                ActionChip(label: Text(h), onPressed: () => _server.text = h),
            ],
          ),
          const SizedBox(height: 20),
          const _Hint(
            'Vamos abrir a página de login do seu servidor no navegador. Sua senha é digitada lá, nunca aqui.',
            icon: Icons.lock_outline_rounded,
          ),
        ],
      ),
      _OAuthPhase.waiting => _FlowPage(
        step: _host,
        title: 'Autorize no navegador',
        subtitle: 'Entre na sua conta e toque em "Autorizar". Assim que terminar, a conexão é concluída aqui sozinha.',
        children: [
          if (_error != null) _ErrorBox(_error!),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: _busy
                  ? const CircularProgressIndicator()
                  : const SizedBox.square(
                      dimension: 46,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => openUrl(_authUrl.toString()),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Abrir a página de novo'),
          ),
        ],
      ),
      _OAuthPhase.paste => _FlowPage(
        step: _host,
        title: 'Cole o código',
        subtitle: 'Depois de autorizar no navegador, o servidor mostra um código. Copie e cole aqui.',
        bottom: FilledButton(
          onPressed: _busy ? null : () => _finishWith(_code.text),
          child: Text(_busy ? 'Conectando…' : 'Conectar'),
        ),
        children: [
          if (_error != null) _ErrorBox(_error!),
          TextField(
            controller: _code,
            autofocus: true,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Código de autorização',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                tooltip: 'Colar',
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: () async {
                  final d = await Clipboard.getData('text/plain');
                  if (d?.text != null) _code.text = d!.text!.trim();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => openUrl(_authUrl.toString()),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Abrir a página de novo'),
          ),
        ],
      ),
    };
  }
}

class _BlueskyConnectPage extends ConsumerStatefulWidget {
  const _BlueskyConnectPage();

  @override
  ConsumerState<_BlueskyConnectPage> createState() =>
      _BlueskyConnectPageState();
}

class _BlueskyConnectPageState extends ConsumerState<_BlueskyConnectPage> {
  final _handle = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _needCode = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final a = await BlueskyAuth.login(
        _handle.text,
        _password.text,
        authFactorToken: _needCode ? _code.text : null,
      );
      await ref.read(accountsProvider.notifier).add(a);
      if (mounted) _go(context, _ConnectedPage(account: a));
    } catch (e) {
      final needs =
          e is ApiException &&
          e.body is Map &&
          (e.body as Map)['error'] == 'AuthFactorTokenRequired';
      if (mounted) {
        setState(() {
          _busy = false;
          _needCode = _needCode || needs;
          _error = needs
              ? 'Enviamos um código para o seu e-mail. Digite abaixo.'
              : _friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      step: 'Bluesky',
      title: 'Conecte seu Bluesky',
      subtitle: 'Use uma senha de app: ela só serve para apps como o jabuticaba e pode ser revogada quando quiser.',
      bottom: FilledButton(
        onPressed: _busy ? null : _login,
        child: Text(_busy ? 'Conectando…' : 'Conectar'),
      ),
      children: [
        if (_error != null) _ErrorBox(_error!),
        TextField(
          controller: _handle,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'voce.bsky.social',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _hide,
          autocorrect: false,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            hintText: 'Senha de app (xxxx-xxxx-xxxx-xxxx)',
            prefixIcon: const Icon(Icons.key_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _hide ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              ),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        if (_needCode) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'Código do e-mail',
              prefixIcon: Icon(Icons.mark_email_read_rounded),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => openUrl('https://bsky.app/settings/app-passwords'),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Criar uma senha de app no Bluesky'),
        ),
        const SizedBox(height: 16),
        const _Hint(
          'No Bluesky: Configurações → Privacidade e segurança → Senhas de app → Adicionar. Dê o nome "jabuticaba" e copie a senha gerada.',
        ),
      ],
    );
  }
}

class _LemmyConnectPage extends ConsumerStatefulWidget {
  const _LemmyConnectPage({this.initialHost});
  final String? initialHost;

  @override
  ConsumerState<_LemmyConnectPage> createState() => _LemmyConnectPageState();
}

class _LemmyConnectPageState extends ConsumerState<_LemmyConnectPage> {
  late final _server = TextEditingController(text: widget.initialHost ?? '');
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  bool _need2fa = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_server, _user, _password, _totp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final a = await LemmyAuth.login(
        normalizeHost(_server.text),
        _user.text,
        _password.text,
        totp: _totp.text,
      );
      await ref.read(accountsProvider.notifier).add(a);
      if (mounted) _go(context, _ConnectedPage(account: a));
    } catch (e) {
      final missing2fa =
          e is ApiException && '${e.body}'.contains('missing_totp_token');
      if (mounted) {
        setState(() {
          _busy = false;
          _need2fa = _need2fa || missing2fa;
          _error = missing2fa
              ? 'Sua conta usa verificação em duas etapas. Digite o código do app autenticador.'
              : _friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      step: 'Lemmy',
      title: 'Conecte seu Lemmy',
      bottom: FilledButton(
        onPressed: _busy ? null : _login,
        child: Text(_busy ? 'Conectando…' : 'Conectar'),
      ),
      children: [
        if (_error != null) _ErrorBox(_error!),
        TextField(
          controller: _server,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'lemmy.world',
            prefixIcon: Icon(Icons.dns_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _user,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Usuário ou e-mail',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _hide,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            hintText: 'Senha',
            prefixIcon: const Icon(Icons.key_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _hide ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              ),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        if (_need2fa) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _totp,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Código de 6 dígitos',
              prefixIcon: Icon(Icons.pin_rounded),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const _Hint(
          'O Lemmy não oferece login por navegador, então a senha vai direto para o seu servidor, por conexão segura. O jabuticaba guarda só o token de acesso, no cofre do sistema.',
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}

class _ConnectedPage extends StatelessWidget {
  const _ConnectedPage({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      title: 'Prontinho!',
      subtitle: 'Sua conta está conectada. Agora você pode curtir, compartilhar, seguir e publicar daqui.',
      bottom: FilledButton(
        onPressed: () => _finish(context, ok: true),
        child: const Text('Começar a usar'),
      ),
      children: [
        _AccountRow(account: account),
        const SizedBox(height: 20),
        const _Hint(
          'No Fio, a aba "Minhas contas" mostra a linha do tempo das suas contas, todas juntas.',
          icon: Icons.view_agenda_rounded,
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: context.jc.panel(),
    child: Row(
      children: [
        Avatar(
          url: account.avatar,
          size: 52,
          network: account.network,
          label: account.name,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.name, style: context.tt.titleMedium),
              Text('@${account.handle}', style: context.tt.bodySmall),
            ],
          ),
        ),
        NetworkPill(account.network),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// Criar conta
// -----------------------------------------------------------------------------

class _CreatePickPage extends StatelessWidget {
  const _CreatePickPage();

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return _FlowPage(
      step: 'Criar conta',
      title: 'O que você quer fazer por lá?',
      subtitle: 'Não tem resposta errada — dá para criar outras contas depois e conectar todas.',
      children: [
        _Choice(
          icon: Icons.forum_rounded,
          color: jc.network(Network.mastodon),
          title: 'Conversar e acompanhar pessoas',
          text: 'Mastodon: posts curtos, como o antigo Twitter. É a porta de entrada mais comum do fediverso.',
          badge: 'recomendado',
          onTap: () => _go(context, const _ServerPickPage()),
        ),
        _Choice(
          icon: Icons.photo_camera_rounded,
          color: jc.network(Network.pixelfed),
          title: 'Compartilhar fotos',
          text: 'Pixelfed: álbuns e fotos, como o Instagram, sem anúncios.',
          onTap: () => _go(
            context,
            const _ExternalSignupPage(network: Network.pixelfed),
          ),
        ),
        _Choice(
          icon: Icons.groups_rounded,
          color: jc.network(Network.lemmy),
          title: 'Participar de comunidades',
          text: 'Lemmy: fóruns por assunto, como o Reddit.',
          onTap: () =>
              _go(context, const _ExternalSignupPage(network: Network.lemmy)),
        ),
        _Choice(
          icon: Icons.cloud_rounded,
          color: jc.network(Network.bluesky),
          title: 'Bluesky',
          text: 'Rede aberta com feeds personalizados. O cadastro pede confirmação por telefone ou e-mail no site deles.',
          onTap: () =>
              _go(context, const _ExternalSignupPage(network: Network.bluesky)),
        ),
        _Choice(
          icon: Icons.all_inclusive_rounded,
          color: jc.network(Network.loops),
          title: 'Postar vídeos curtos',
          text: 'Loops: vídeos verticais, como TikTok e Reels.',
          onTap: () =>
              _go(context, const _ExternalSignupPage(network: Network.loops)),
        ),
        _Choice(
          icon: Icons.album_rounded,
          color: jc.network(Network.funkwhale),
          title: 'Ouvir e guardar música',
          text: 'Funkwhale: favoritos, biblioteca e, se quiser, publicar suas músicas.',
          onTap: () => _go(context, const _MusicSignupPickPage()),
        ),
        _Choice(
          icon: Icons.mic_rounded,
          color: jc.network(Network.castopod),
          title: 'Publicar um podcast',
          text: 'Castopod ou canal no Funkwhale: seu podcast vira uma conta do fediverso.',
          onTap: () => _go(context, const _PodcasterPage()),
        ),
      ],
    );
  }
}

/// Escolha de servidor Mastodon com recomendação baseada em idioma e interesses.
class _ServerPickPage extends ConsumerStatefulWidget {
  const _ServerPickPage();

  @override
  ConsumerState<_ServerPickPage> createState() => _ServerPickPageState();
}

class _ServerPickPageState extends ConsumerState<_ServerPickPage> {
  late final Future<List<Community>> _servers = _load();
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<List<Community>> _load() async {
    final cats = {
      for (final i in ref.read(settingsProvider).chosen)
        if (i.category != null) i.category!,
    };
    final results = await Future.wait([
      ServerDirectory.servers(language: 'pt').catchError((_) => <Community>[]),
      for (final c in cats.take(2))
        ServerDirectory.servers(category: c).catchError((_) => <Community>[]),
      ServerDirectory.servers(category: 'general')
          .catchError((_) => <Community>[]),
    ]);
    final seen = <String>{};
    final all = [for (final l in results) ...l]
        .where((s) => seen.add(s.id))
        .toList();
    // Português e cadastro imediato primeiro; depois os mais ativos.
    int score(Community s) =>
        (s.language == 'pt' ? 2000000 : 0) +
        (s.approvalRequired ? 0 : 1000000) +
        (cats.contains(s.category) ? 500000 : 0) +
        (s.activeMembers ?? 0).clamp(0, 400000);
    all.sort((a, b) => score(b).compareTo(score(a)));
    return all.take(24).toList();
  }

  void _pick(String host) =>
      _go(context, _SignupPage(host: normalizeHost(host)));

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      step: 'Criar conta · Mastodon',
      title: 'Escolha sua casa',
      subtitle: 'Cada servidor tem suas regras e seu clima, mas todos conversam entre si. Você pode se mudar depois e levar seus seguidores.',
      children: [
        FutureBuilder<List<Community>>(
          future: _servers,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Column(
                children: [
                  Skeleton(height: 150, radius: 22),
                  SizedBox(height: 12),
                  Skeleton(height: 90, radius: 22),
                  SizedBox(height: 12),
                  Skeleton(height: 90, radius: 22),
                ],
              );
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return const _Hint(
                'Não consegui carregar a lista agora. Digite um servidor abaixo.',
              );
            }
            return Column(
              children: [
                _ServerOption(
                  server: list.first,
                  recommended: true,
                  onTap: () => _pick(list.first.name),
                ),
                for (final s in list.skip(1))
                  _ServerOption(server: s, onTap: () => _pick(s.name)),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Text('Já tem um servidor em mente?', style: context.tt.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _custom,
                autocorrect: false,
                keyboardType: TextInputType.url,
                onSubmitted: _pick,
                decoration: const InputDecoration(
                  hintText: 'exemplo.social',
                  prefixIcon: Icon(Icons.dns_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => _pick(_custom.text),
              child: const Text('Usar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ServerOption extends StatelessWidget {
  const _ServerOption({
    required this.server,
    required this.onTap,
    this.recommended = false,
  });
  final Community server;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final s = server;
    final reasons = <(IconData, String)>[
      if (s.language == 'pt') (Icons.translate_rounded, 'Em português'),
      (
        s.approvalRequired ? Icons.hourglass_top_rounded : Icons.bolt_rounded,
        s.approvalRequired ? 'Cadastro com aprovação' : 'Cadastro na hora',
      ),
      if (s.activeMembers != null)
        (Icons.people_alt_rounded, '${compact(s.activeMembers)} ativos'),
      if (s.category != null)
        (
          Icons.sell_rounded,
          ServerDirectory.categoryLabels[s.category] ?? s.category!,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: jc.r(22),
          child: Ink(
            decoration: recommended && !jc.bevel
                ? BoxDecoration(
                    color: jc.card,
                    borderRadius: jc.r(22),
                    border: Border.all(color: jc.brand, width: 2),
                  )
                : jc.panel(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (recommended && s.banner != null)
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(jc.square ? 0 : 20),
                    ),
                    child: SizedBox(
                      height: 110,
                      child: NetImage(s.banner, blurhash: s.blurhash),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(s.name, style: context.tt.titleMedium),
                          ),
                          if (recommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: ShapeDecoration(
                                gradient: jc.accent,
                                shape: jc.pill(),
                              ),
                              child: Text(
                                'Escolha do jabuticaba',
                                style: TextStyle(
                                  color: jc.onAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if ((s.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          s.description!,
                          style: context.tt.bodyMedium?.copyWith(
                            color: jc.muted,
                          ),
                          maxLines: recommended ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          for (final (icon, label) in reasons)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 15, color: jc.muted),
                                const SizedBox(width: 4),
                                Text(label, style: context.tt.labelMedium),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cadastro dentro do app, pela API oficial do Mastodon.
class _SignupPage extends ConsumerStatefulWidget {
  const _SignupPage({required this.host});
  final String host;

  @override
  ConsumerState<_SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<_SignupPage> {
  late final Future<ServerSignupInfo> _info = MastodonAuth.signupInfo(
    widget.host,
  );
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _reason = TextEditingController();
  DateTime? _birth;
  bool _agree = false;
  bool _hide = true;
  bool _busy = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    for (final c in [_user, _email, _password, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(ServerSignupInfo info) {
    if (!RegExp(r'^[a-zA-Z0-9_]{1,30}$').hasMatch(_user.text)) {
      return 'O nome de usuário aceita letras, números e _ (até 30).';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      return 'Confira o e-mail.';
    }
    if (_password.text.length < 8) {
      return 'A senha precisa de pelo menos 8 caracteres.';
    }
    if (info.minAge != null && _birth == null) {
      return 'Este servidor pede sua data de nascimento.';
    }
    if (info.reasonRequired && _reason.text.trim().isEmpty) {
      return 'Conte em uma frase por que quer entrar.';
    }
    if (!_agree) return 'É preciso aceitar as regras do servidor.';
    return null;
  }

  Future<void> _submit(ServerSignupInfo info) async {
    final problem = _validate(info);
    if (problem != null) {
      setState(() => _errors = {'_': problem});
      return;
    }
    setState(() {
      _busy = true;
      _errors = const {};
    });
    try {
      final a = await MastodonAuth.register(
        host: info.host,
        username: _user.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        reason: info.reasonRequired ? _reason.text : null,
        birthDate: _birth,
      );
      await ref.read(accountsProvider.notifier).add(a);
      if (mounted) {
        _go(
          context,
          _ConfirmEmailPage(
            account: a,
            email: _email.text.trim(),
            approval: info.approval,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errors = e is ApiException && e.status == 422
              ? MastodonAuth.signupErrors(e)
              : {'_': _friendlyError(e)};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ServerSignupInfo>(
      future: _info,
      builder: (context, snap) {
        if (snap.hasError) {
          return _FlowPage(
            step: widget.host,
            title: 'Servidor indisponível',
            children: [_ErrorBox(_friendlyError(snap.error!))],
          );
        }
        if (!snap.hasData) {
          return _FlowPage(
            step: widget.host,
            title: 'Conferindo o servidor…',
            children: const [LinearProgressIndicator()],
          );
        }
        final info = snap.data!;
        if (!info.open) {
          return _FlowPage(
            step: info.host,
            title: 'Cadastro fechado',
            subtitle:
                '${info.title} não está aceitando contas novas agora. Volte e escolha outro — todos conversam entre si.',
            children: const [],
          );
        }
        String? fieldError(String k) => _errors[k];
        return _FlowPage(
          step: 'Criar conta · ${info.host}',
          title: 'Sua conta em ${info.title}',
          subtitle: info.approval
              ? 'Este servidor revisa os pedidos de cadastro. Costuma levar de algumas horas a um dia.'
              : 'Leva um minuto. Depois é só confirmar o e-mail.',
          bottom: FilledButton(
            onPressed: _busy ? null : () => _submit(info),
            child: Text(_busy ? 'Criando…' : 'Criar minha conta'),
          ),
          children: [
            if (_errors['_'] != null) _ErrorBox(_errors['_']!),
            TextField(
              controller: _user,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'nome de usuário',
                prefixText: '@',
                errorText: fieldError('username'),
                helperText: _user.text.isEmpty
                    ? 'Seu endereço vai ser @usuario@${info.host}'
                    : 'Seu endereço: @${_user.text}@${info.host}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'e-mail',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
                errorText: fieldError('email'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hide,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'senha (mínimo 8 caracteres)',
                prefixIcon: const Icon(Icons.key_rounded),
                errorText: fieldError('password'),
                suffixIcon: IconButton(
                  icon: Icon(
                    _hide
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            _PasswordMeter(text: _password.text),
            if (info.minAge != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime(now.year - 110),
                    lastDate: now,
                    initialDate: DateTime(now.year - 20),
                    helpText: 'Data de nascimento',
                  );
                  if (d != null) setState(() => _birth = d);
                },
                icon: const Icon(Icons.cake_rounded),
                label: Text(
                  _birth == null
                      ? 'Data de nascimento (mínimo ${info.minAge} anos)'
                      : '${_birth!.day.toString().padLeft(2, '0')}/${_birth!.month.toString().padLeft(2, '0')}/${_birth!.year}',
                ),
              ),
              if (fieldError('date_of_birth') != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    fieldError('date_of_birth')!,
                    style: TextStyle(color: context.jc.hot),
                  ),
                ),
            ],
            if (info.reasonRequired) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Por que você quer entrar? (a moderação lê isto)',
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (info.rules.isNotEmpty)
              Container(
                decoration: context.jc.panel(),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(Icons.gavel_rounded),
                  title: Text('Regras de ${info.host}'),
                  subtitle: Text(
                    '${info.rules.length} regras · leia antes de aceitar',
                  ),
                  children: [
                    for (final (i, r) in info.rules.indexed)
                      ListTile(
                        dense: true,
                        leading: Text('${i + 1}', style: context.tt.titleSmall),
                        title: Text(r),
                      ),
                  ],
                ),
              ),
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Li e aceito as regras e a política de privacidade do servidor',
              ),
              subtitle: fieldError('agreement') == null
                  ? null
                  : Text(
                      fieldError('agreement')!,
                      style: TextStyle(color: context.jc.hot),
                    ),
            ),
            TextButton.icon(
              onPressed: () => openUrl('https://${info.host}/privacy-policy'),
              icon: const Icon(Icons.policy_outlined, size: 18),
              label: const Text('Ver política de privacidade'),
            ),
          ],
        );
      },
    );
  }
}

class _PasswordMeter extends StatelessWidget {
  const _PasswordMeter({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox(height: 8);
    var score = 0;
    if (text.length >= 8) score++;
    if (text.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(text) && RegExp(r'[a-z]').hasMatch(text)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(text)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(text)) score++;
    final label = [
      'Muito fraca',
      'Fraca',
      'Ok',
      'Boa',
      'Forte',
      'Excelente',
    ][score];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: context.jc.r(8),
              child: LinearProgressIndicator(
                value: (score + 1) / 6,
                minHeight: 6,
                backgroundColor: context.jc.cardHigh,
                color: score < 2
                    ? context.jc.hot
                    : (score < 4 ? context.jc.brand : Jabu.leaf),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: context.tt.labelMedium),
        ],
      ),
    );
  }
}

class _ConfirmEmailPage extends ConsumerStatefulWidget {
  const _ConfirmEmailPage({
    required this.account,
    required this.email,
    required this.approval,
  });
  final Account account;
  final String email;
  final bool approval;

  @override
  ConsumerState<_ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends ConsumerState<_ConfirmEmailPage> {
  bool _checking = false;
  String? _msg;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _msg = null;
    });
    final ok = await ref
        .read(accountsProvider.notifier)
        .checkPending(widget.account);
    if (!mounted) return;
    if (ok) {
      _finish(context, ok: true);
    } else {
      setState(() {
        _checking = false;
        _msg = widget.approval
            ? 'Ainda não liberada. Depois de confirmar o e-mail, a moderação precisa aprovar seu pedido.'
            : 'Ainda não confirmada. Abra o e-mail e toque no link de confirmação.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      title: 'Confira seu e-mail 📬',
      subtitle:
          'Mandamos um link de confirmação para ${widget.email}. Toque nele e volte aqui.',
      bottom: FilledButton(
        onPressed: _checking ? null : _check,
        child: Text(_checking ? 'Verificando…' : 'Já confirmei'),
      ),
      children: [
        _AccountRow(account: widget.account),
        const SizedBox(height: 18),
        if (_msg != null) _Hint(_msg!, icon: Icons.schedule_rounded),
        const _Hint(
          'Não chegou? Olhe a caixa de spam. A conta fica salva aqui; você pode confirmar depois em Você → Contas.',
        ),
        TextButton(
          onPressed: () => _finish(context, ok: true),
          child: const Text('Confirmo depois'),
        ),
      ],
    );
  }
}

/// Redes cujo cadastro precisa acontecer no site (captcha, telefone…).
class _ExternalSignupPage extends StatelessWidget {
  const _ExternalSignupPage({required this.network});
  final Network network;

  @override
  Widget build(BuildContext context) {
    final (title, text, servers, connect) = switch (network) {
      Network.pixelfed => (
        'Pixelfed',
        'O cadastro é feito no site do servidor. Depois, volte e conecte — o Pixelfed usa o mesmo login do Mastodon.',
        const [('pixelfed.social', 'https://pixelfed.social/register')],
        () => _go(
          context,
          const _MastodonConnectPage(initialHost: 'pixelfed.social'),
        ),
      ),
      Network.lemmy => (
        'Lemmy',
        'Escolha um servidor e crie a conta no site dele (alguns pedem uma resposta curta para evitar spam).',
        const [
          ('lemmy.eco.br', 'https://lemmy.eco.br/signup'),
          ('lemmy.world', 'https://lemmy.world/signup'),
          ('lemmy.ml', 'https://lemmy.ml/signup'),
        ],
        () => _go(context, const _LemmyConnectPage()),
      ),
      Network.bluesky => (
        'Bluesky',
        'O Bluesky confirma contas novas no site deles. Crie lá, gere uma senha de app e conecte aqui.',
        const [('bsky.app', 'https://bsky.app')],
        () => _go(context, const _BlueskyConnectPage()),
      ),
      _ => (
        'Loops',
        'Crie sua conta no Loops pelo site. O login do Loops em outros apps ainda não existe; por enquanto você assiste e segue pelo jabuticaba.',
        const [('loops.video', 'https://loops.video')],
        null,
      ),
    };
    return _FlowPage(
      step: 'Criar conta',
      title: 'Criar conta no $title',
      subtitle: text,
      bottom: connect == null
          ? FilledButton(
              onPressed: () => _finish(context, ok: false),
              child: const Text('Voltar a explorar'),
            )
          : FilledButton(
              onPressed: connect,
              child: const Text('Já criei — conectar'),
            ),
      children: [
        for (final (host, url) in servers)
          _Choice(
            icon: Icons.open_in_new_rounded,
            color: context.jc.network(network),
            title: host,
            text: 'Abrir a página de cadastro',
            onTap: () => openUrl(url),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Música (Funkwhale) e podcasts
// -----------------------------------------------------------------------------

/// Escolha de servidor Funkwhale com cadastro aberto.
class _MusicSignupPickPage extends StatelessWidget {
  const _MusicSignupPickPage();

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      step: 'Criar conta · Funkwhale',
      title: 'Escolha onde guardar sua música',
      subtitle: 'Todos os servidores Funkwhale conversam entre si. Esses estão aceitando contas novas.',
      children: [
        for (final host in FunkwhaleApi.signupPods)
          FutureBuilder<ServerSignupInfo>(
            future: FunkwhaleAuth.signupInfo(host),
            builder: (context, snap) {
              final info = snap.data;
              return _Choice(
                icon: Icons.album_rounded,
                color: context.jc.network(Network.funkwhale),
                title: info?.title ?? host,
                text: [
                  host,
                  if (info?.users != null)
                    '${compact(info!.users)} ativos no mês',
                  if ((info?.description ?? '').isNotEmpty)
                    htmlToText(info!.description),
                ].join(' · '),
                badge: host == FunkwhaleApi.signupPods.first
                    ? 'sugestão'
                    : null,
                onTap: () => _go(context, _MusicSignupPage(host: host)),
              );
            },
          ),
        const _Hint(
          'Já tem conta Funkwhale? Volte e escolha "Já tenho conta".',
          icon: Icons.info_outline_rounded,
        ),
      ],
    );
  }
}

/// Cadastro no Funkwhale pela API do servidor.
class _MusicSignupPage extends StatefulWidget {
  const _MusicSignupPage({required this.host});
  final String host;

  @override
  State<_MusicSignupPage> createState() => _MusicSignupPageState();
}

class _MusicSignupPageState extends State<_MusicSignupPage> {
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    for (final c in [_user, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!RegExp(r'^[a-zA-Z0-9_.-]{2,30}$').hasMatch(_user.text.trim())) {
      setState(
        () => _errors = {
          '_': 'O nome de usuário aceita letras, números, ponto, hífen e _.',
        },
      );
      return;
    }
    if (_password.text.length < 8) {
      setState(
        () => _errors = {'_': 'A senha precisa de pelo menos 8 caracteres.'},
      );
      return;
    }
    setState(() {
      _busy = true;
      _errors = const {};
    });
    try {
      await FunkwhaleAuth.register(
        host: widget.host,
        username: _user.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        _go(
          context,
          _MusicConfirmPage(host: widget.host, email: _email.text.trim()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errors = e is ApiException && e.status == 400
              ? FunkwhaleAuth.signupErrors(e)
              : {'_': _friendlyError(e)};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      step: 'Criar conta · ${widget.host}',
      title: 'Sua conta de música',
      subtitle: 'Depois de criar, confirme o e-mail e conecte a conta aqui no jabuticaba.',
      bottom: FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'Criando…' : 'Criar minha conta'),
      ),
      children: [
        if (_errors['_'] != null) _ErrorBox(_errors['_']!),
        TextField(
          controller: _user,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'nome de usuário',
            prefixText: '@',
            errorText: _errors['username'],
            helperText:
                'Seu endereço: @${_user.text.isEmpty ? 'usuario' : _user.text}@${widget.host}',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'e-mail',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            errorText: _errors['email'],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _hide,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'senha (mínimo 8 caracteres)',
            prefixIcon: const Icon(Icons.key_rounded),
            errorText: _errors['password'],
            suffixIcon: IconButton(
              icon: Icon(
                _hide ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              ),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        _PasswordMeter(text: _password.text),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => openUrl('https://${widget.host}/about'),
          icon: const Icon(Icons.gavel_rounded, size: 18),
          label: const Text('Ler as regras do servidor'),
        ),
      ],
    );
  }
}

class _MusicConfirmPage extends StatelessWidget {
  const _MusicConfirmPage({required this.host, required this.email});
  final String host;
  final String email;

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      title: 'Confira seu e-mail 📬',
      subtitle:
          'Mandamos um link de confirmação para $email. Depois de confirmar, conecte a conta para favoritar músicas daqui.',
      bottom: FilledButton(
        onPressed: () => _go(
          context,
          _MastodonConnectPage(initialHost: host, funkwhale: true),
        ),
        child: const Text('Já confirmei — conectar'),
      ),
      children: [
        const _Hint(
          'Alguns servidores revisam contas novas antes de liberar. Se o login não funcionar, espere um pouco e tente de novo.',
        ),
        TextButton(
          onPressed: () => _finish(context, ok: false),
          child: const Text('Conecto depois'),
        ),
      ],
    );
  }
}

/// Para quem quer publicar: Castopod (hospedagem de podcast) ou canal Funkwhale.
class _PodcasterPage extends StatelessWidget {
  const _PodcasterPage();

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return _FlowPage(
      step: 'Publicar um podcast',
      title: 'Seu podcast no fediverso',
      subtitle: 'No fediverso, seu podcast vira uma conta: as pessoas seguem pelo Mastodon e comentam os episódios de lá. Os comentários chegam no seu site.',
      children: [
        _Choice(
          icon: Icons.podcasts_rounded,
          color: jc.network(Network.castopod),
          title: 'Castopod',
          text: 'Feito para podcasts: RSS para Spotify e Apple, estatísticas e comentários do fediverso. Você instala ou contrata uma hospedagem.',
          badge: 'recomendado',
          onTap: () => openUrl('https://castopod.org'),
        ),
        _Choice(
          icon: Icons.album_rounded,
          color: jc.network(Network.funkwhale),
          title: 'Canal no Funkwhale',
          text: 'Mais simples: crie uma conta de música e abra um canal de podcast nela. Também gera RSS.',
          onTap: () => _go(context, const _MusicSignupPickPage()),
        ),
        const _Hint(
          'Para ouvir e comentar podcasts você não precisa de nada disso: basta uma conta no Mastodon. Volte e escolha "Conversar e acompanhar pessoas".',
          icon: Icons.headphones_rounded,
        ),
      ],
    );
  }
}
