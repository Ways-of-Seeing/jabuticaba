import 'dart:async';
import 'dart:io';

/// Servidor HTTP efêmero em 127.0.0.1 que captura `?code=` do redirect OAuth.
class Loopback {
  Loopback._(this._server);

  final HttpServer _server;
  final _code = Completer<String>();

  /// Desktop: sim. iOS/Android suspendem o app enquanto o navegador está na
  /// frente, então lá usamos o código colado.
  static bool get supported =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  static Future<Loopback> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final lb = Loopback._(server);
    server.listen(lb._handle);
    return lb;
  }

  String get redirectUri => 'http://127.0.0.1:${_server.port}/callback';

  Future<void> _handle(HttpRequest req) async {
    final code = req.uri.queryParameters['code'];
    final error =
        req.uri.queryParameters['error_description'] ??
        req.uri.queryParameters['error'];
    req.response.headers.contentType = ContentType.html;
    req.response.write(_page(ok: code != null));
    await req.response.close();
    if (_code.isCompleted) return;
    if (code != null) {
      _code.complete(code);
    } else if (error != null) {
      _code.completeError(Exception(error));
    }
  }

  Future<String> waitForCode({Duration timeout = const Duration(minutes: 5)}) =>
      _code.future.timeout(timeout);

  Future<void> close() => _server.close(force: true);

  static String _page({required bool ok}) =>
      '''
<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<title>jabuticaba</title>
<body style="font-family:-apple-system,system-ui,sans-serif;background:#0f0812;color:#fbf6fa;display:grid;place-items:center;height:100vh;margin:0">
<div style="text-align:center">
<div style="font-size:64px">${ok ? '🫐' : '😕'}</div>
<h1>${ok ? 'Conta conectada!' : 'Não deu certo'}</h1>
<p style="opacity:.75">${ok ? 'Pode fechar esta aba e voltar para o jabuticaba.' : 'Volte ao jabuticaba e tente de novo.'}</p>
</div></body></html>''';
}
