# Distribuição do jabuticaba

Prioridade combinada: **macOS** para testar agora; **iOS** primeiro em **AltStore PAL** e **Aptoide**, depois App Store.

> Regras de lojas e taxas da Apple mudam com frequência. Confira os links oficiais antes de cada etapa.

## iOS — marketplaces alternativos na UE (AltStore PAL e Aptoide)

Os dois só funcionam na União Europeia, pela DMA. Mesmo fora da App Store, o app passa pela Apple: ela faz a **notarização** (revisão básica de segurança, mais leve que a da App Store) e gera o pacote assinado que o marketplace instala.

### O que vale para os dois

1. **Conta Apple Developer** (paga) em nome de uma pessoa ou empresa.
2. Em App Store Connect → *Business*, aceitar o **Alternative Terms Addendum for Apps in the EU**. Os termos alternativos trazem taxas próprias da Apple (o modelo atual é a *Core Technology Commission*). Leia antes de aceitar.
3. Criar o app no App Store Connect com o bundle id `social.jabuticaba.jabuticaba` (ou o definitivo: troque antes da primeira submissão).
4. Gerar o build: `flutter build ipa --release` e enviar pelo Transporter ou Xcode.
5. Submeter para **notarização** (não para revisão da App Store) e, depois de aprovado, **autorizar o marketplace** a distribuir o app (*Distribution → Alternative Distribution → Marketplaces*).
6. A Apple gera o **ADP** (*Alternative Distribution Package*); o marketplace busca esse pacote.

### AltStore PAL

- Você publica uma **source** (um JSON hospedado num site seu) que lista o app, as versões e o `marketplaceID`. O AltStore PAL lê a source e instala o ADP autorizado.
- Documentação: <https://faq.altstore.io/developers/distribute-with-altstore-pal>
- Sugestão: hospedar a source em `https://jabuticaba.social/altstore.json` e fazer um botão “Adicionar ao AltStore” no site.

### Aptoide (iOS)

- Cadastro no portal de desenvolvedor da Aptoide, autorização da Aptoide como marketplace no App Store Connect e envio do app pelo portal deles.
- Informações: <https://en.aptoide.com/company/ios>
- A Aptoide também distribui **Android**, então a mesma conta cobre o APK.

### App Store (depois)

- Mesmo build e mesma conta; submeter para a **revisão completa da App Store**.
- Pontos que costumam travar apps de rede social: moderação e denúncia de conteúdo (diretriz 1.2 — precisaremos de “denunciar”, “bloquear” e filtro de conteúdo sensível, que já começa desfocado) e login/conta.

## Android

- **APK/AAB:** `flutter build apk --release` e `flutter build appbundle --release`.
- Lojas: Aptoide, **F-Droid** (exige build reproduzível e só dependências livres: o projeto já é 100% open source), **Obtainium**/GitHub Releases e, depois, a Google Play.

## macOS

- Desenvolvimento: `flutter run -d macos`.
- Distribuição fora da Mac App Store: `flutter build macos --release`, assinar com *Developer ID*, **notarizar** (`xcrun notarytool submit … --wait`) e empacotar num `.dmg`. Depois, um cask no Homebrew.
- Rede: o sandbox já pede `com.apple.security.network.client` (em `macos/Runner/*.entitlements`).

## Linux e Windows

- Builds: `flutter build linux --release` / `flutter build windows --release`.
- **Pendência:** o `video_player` oficial não toca vídeo nessas plataformas. Antes de publicar, trocar por `media_kit` (que também cobre macOS/iOS/Android).
- Linux: Flatpak (Flathub) e AppImage. Windows: MSIX (Microsoft Store) e winget.

## Checklist antes da primeira versão pública

- [ ] Ícone do app e tela de abertura
- [ ] Bundle id definitivo e nome nas lojas
- [ ] Denunciar, bloquear e silenciar (exigência de lojas para redes sociais)
- [ ] Política de privacidade (o app não tem servidor próprio; tudo fica no aparelho)
- [ ] Login (Mastodon OAuth, senha de app do Bluesky)
- [ ] `media_kit` para Linux/Windows
