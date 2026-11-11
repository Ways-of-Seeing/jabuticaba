# Distribuição do jabuticaba

Prioridade: **macOS** e **iOS pelo AltStore Classic** agora; Android e Aptoide depois; App Store quando houver conta paga e os requisitos de loja estiverem completos.

> Regras de lojas e taxas da Apple mudam com frequência. Confira os links oficiais antes de cada etapa.

## iOS — AltStore Classic (funciona no Brasil e no mundo)

O AltStore Classic distribui um **IPA sem assinatura**. Cada pessoa assina o app no próprio iPhone com a conta Apple dela, pelo AltServer. Não há revisão da Apple e não é preciso conta paga — o preço é a assinatura de 7 dias por vez na conta gratuita.

O passo a passo completo, com os limites da conta gratuita e os erros mais comuns, está em [ALTSTORE.md](ALTSTORE.md). Resumo:

1. `tool/release/ios.sh` gera `build/ios/ipa/jabuticaba-<versão>-<build>.ipa` (arm64, sem codesign).
2. A tag `vX.Y.Z` dispara o workflow `release`, que anexa o IPA à release do GitHub.
3. `tool/release/altstore/make_source.py` escreve `site/altstore.json` com versão, tamanho, ícone e capturas.
4. O workflow `pages` publica `site/` em `https://ways-of-seeing.github.io/jabuticaba/`.
5. No iPhone: AltStore → Browse → Sources → + → cole `https://ways-of-seeing.github.io/jabuticaba/altstore.json` (ou use o botão do site).

Bundle id definitivo: `social.jabuticaba.jabuticaba`. **Não mude** depois de publicar: o AltStore registra esse App ID na conta de cada pessoa; mudar quebra as atualizações de quem já instalou.

### Conta Apple gratuita: o que dizer a quem instala

- 3 apps no máximo por aparelho;
- assinatura expira em 7 dias (renove no AltStore com o AltServer na mesma rede);
- 10 App IDs por semana (o jabuticaba usa um);
- push, iCloud e Associated Domains não funcionam. O app não usa nenhum dos três.

### AltStore PAL (UE, Japão e Brasil desde 18/06/2026)

O PAL instala apps **notarizados** pela Apple, sem expiração e sem computador, mas exige **conta Apple Developer paga** (US$ 99/ano). No Brasil, requer iOS 26.5+ e o aceite dos termos alternativos da Apple. O caminho:

1. Criar o app no App Store Connect com o bundle id definitivo.
2. Subir o build e escolher **Review Type: Notarization**.
3. Registrar o Developer ID na API do AltStore e autorizar a distribuição por marketplace.
4. Baixar o **ADP** (Alternative Distribution Package) e hospedar preservando a estrutura, ou usar `assetURLs` com GitHub Releases.
5. Na source, acrescentar `marketplaceID` e apontar `downloadURL` para o `manifest.json` do ADP.

A Apple cobra a *Core Technology Commission* (5% sobre bens digitais) no modelo alternativo; a AltStore não cobra comissão. Detalhes: <https://faq.altstore.io/developers/distribute-with-altstore-pal>.

## Android

- **APK/AAB:** `flutter build apk --release` e `flutter build appbundle --release`.
- Lojas: Aptoide, **F-Droid** (exige build reproduzível e só dependências livres: o projeto já é 100% open source), **Obtainium**/GitHub Releases e, depois, a Google Play.
- O manifesto principal declara `INTERNET`; sem isso o build de release fica offline.
- O retorno do OAuth usa `jabuticaba://oauth` (intent-filter já registrado).

## macOS

- Desenvolvimento: `flutter run -d macos`.
- Distribuição fora da Mac App Store: `flutter build macos --release`, assinar com *Developer ID*, **notarizar** (`xcrun notarytool submit … --wait`) e empacotar num `.dmg`. Depois, um cask no Homebrew.
- Rede: o sandbox já pede `com.apple.security.network.client` (em `macos/Runner/*.entitlements`).

## Linux e Windows

- Builds: `flutter build linux --release` / `flutter build windows --release`.
- **Pendência:** o `video_player` oficial não toca vídeo nessas plataformas. Antes de publicar, trocar por `media_kit` (que também cobre macOS/iOS/Android).
- O build Linux agora precisa de WebKitGTK (usado pelo OAuth do `flutter_web_auth_2`): `libwebkit2gtk-4.1-dev` e `libsoup-3.0-dev`, além das dependências do Flutter.
- Linux: Flatpak (Flathub) e AppImage. Windows: MSIX (Microsoft Store) e winget.

## Checklist antes da primeira versão pública

- [x] Ícone do app e tela de abertura (splash nativa ainda é a padrão do Flutter)
- [x] Bundle id definitivo e nome nas lojas
- [x] Denunciar, bloquear e silenciar (exigência de lojas para redes sociais)
- [ ] Política de privacidade publicada (o app não tem servidor próprio; tudo fica no aparelho) — texto pronto no site e no README, falta página dedicada
- [x] Login (Mastodon OAuth com `state` e navegador do sistema; senha de app do Bluesky; Lemmy)
- [ ] `media_kit` para Linux/Windows
- [ ] Capturas no iPhone físico (as atuais vêm do build web em modo demonstração)
