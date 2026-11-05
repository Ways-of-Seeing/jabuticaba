import 'dart:async';

/// Sem servidor local nesta plataforma: o fluxo cai para "colar o código".
class Loopback {
  Loopback._();

  static bool get supported => false;

  static Future<Loopback> start() => throw UnsupportedError('loopback');

  String get redirectUri => throw UnsupportedError('loopback');

  Future<String> waitForCode({Duration timeout = const Duration(minutes: 5)}) =>
      throw UnsupportedError('loopback');

  Future<void> close() async {}
}
