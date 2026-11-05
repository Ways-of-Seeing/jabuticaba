/// Recebe o retorno do OAuth. No desktop abre um servidor local em
/// 127.0.0.1 (o navegador redireciona para ele); onde isso não existe
/// (web) a pessoa cola o código.
library;

export 'loopback_stub.dart' if (dart.library.io) 'loopback_io.dart';
