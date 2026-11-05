import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/account.dart';
import '../models/models.dart';
import '../services/account_api.dart';
import '../services/auth/auth.dart';
import 'loaders.dart';

/// Tokens ficam no cofre do sistema (Keychain, Keystore, libsecret, DPAPI).
class TokenStore {
  TokenStore._();

  static const _key = 'jabuticaba.accounts';
  static const _storage = FlutterSecureStorage(
    // No macOS, o Keychain clássico dispensa perfil de provisionamento.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static Future<List<Account>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return const [];
      return [
        for (final j in jsonDecode(raw) as List)
          Account.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<Account> accounts) => _storage.write(
    key: _key,
    value: jsonEncode([for (final a in accounts) a.toJson()]),
  );
}

/// Sobrescrito em `main()` com as contas lidas do cofre.
final initialAccountsProvider = Provider<List<Account>>((_) => const []);

class AccountsNotifier extends Notifier<List<Account>> {
  @override
  List<Account> build() => ref.watch(initialAccountsProvider);

  Future<void> add(Account a) async {
    state = [a, ...state.where((x) => x.id != a.id)];
    await TokenStore.save(state);
  }

  Future<void> remove(Account a) async {
    state = state.where((x) => x.id != a.id).toList();
    await TokenStore.save(state);
  }

  Future<void> _replace(Account a) async {
    state = [for (final x in state) x.id == a.id ? a : x];
    await TokenStore.save(state);
  }

  /// Executa uma ação com a conta, renovando a sessão do Bluesky se expirou.
  Future<T> run<T>(Account a, Future<T> Function(Account) action) async {
    try {
      return await action(a);
    } catch (e) {
      if (a.kind == AccountKind.bluesky && BlueskyAuth.isExpired(e)) {
        final fresh = await BlueskyAuth.refresh(a);
        await _replace(fresh);
        return action(fresh);
      }
      rethrow;
    }
  }

  /// Contas criadas no app ficam "pendentes" até o e-mail ser confirmado.
  Future<bool> checkPending(Account a) async {
    try {
      final full = await MastodonAuth.verify(
        a.server,
        a.token,
        software: a.software,
      );
      await _replace(full);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Primeira conta ativa capaz de interagir com posts desta rede.
  Account? forNetwork(Network n) {
    for (final a in state) {
      if (!a.pending && a.network == n) return a;
    }
    for (final a in state) {
      if (!a.pending && a.canReach(n)) return a;
    }
    return null;
  }

  Future<void> like(Post p) =>
      _withAccountFor(p.network, (a) => AccountApi.like(a, p));
  Future<void> boost(Post p) =>
      _withAccountFor(p.network, (a) => AccountApi.boost(a, p));
  Future<void> follow(Author who) =>
      _withAccountFor(who.network, (a) => AccountApi.followPerson(a, who));

  Future<void> _withAccountFor(Network n, Future<void> Function(Account) f) {
    final a = forNetwork(n);
    if (a == null) throw NoAccountException(n);
    return run(a, f);
  }

  /// Linha do tempo "Minhas contas": as home timelines misturadas.
  Loader<Post> homeLoader() => mix({
    for (final a in state)
      if (!a.pending) a.id: (c) => run(a, (acc) => AccountApi.home(acc, c)),
  });
}

class NoAccountException implements Exception {
  NoAccountException(this.network);
  final Network network;
}

final accountsProvider = NotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
);
