# Publicar o jabuticaba no AltStore (iOS)

Este é o caminho **gratuito e imediato**: AltStore Classic. O app sai como um IPA
sem assinatura, hospedado no GitHub Releases, e cada pessoa assina no próprio
iPhone com a conta Apple dela. Nós não precisamos de conta paga nem de revisão
da Apple.

> Existe também o **AltStore PAL**, que desde junho de 2026 funciona no Brasil.
> Ele instala apps notarizados, não expiram e dispensam computador — mas exige
> conta Apple Developer paga (US$ 99/ano) e notarização. Quando houver conta
> paga, o caminho está no fim deste documento.

## O que é publicado

| Peça | Onde fica | URL |
|---|---|---|
| Source (JSON do AltStore) | GitHub Pages, pasta `site/` | `https://ways-of-seeing.github.io/jabuticaba/altstore.json` |
| IPA | GitHub Releases, tag `vX.Y.Z` | `https://github.com/Ways-of-Seeing/jabuticaba/releases/download/vX.Y.Z/jabuticaba-X.Y.Z-N.ipa` |
| Ícone 512×512 | GitHub Pages | `https://ways-of-seeing.github.io/jabuticaba/icon.png` |
| Capturas | GitHub Pages | `https://ways-of-seeing.github.io/jabuticaba/screenshots/…` |
| Página para o público | GitHub Pages | `https://ways-of-seeing.github.io/jabuticaba/` |

O bundle id é `social.jabuticaba.jabuticaba` e **não pode mudar** depois da
primeira publicação: é por ele que o AltStore registra o App ID na conta de cada
usuário. (Se mudar, quem já instalou perde as atualizações.)

## Passo a passo de uma versão

1. **Suba a versão** em `pubspec.yaml` (`version: 0.1.0+1` → `0.1.1+2`). Os dois
   números precisam bater com `CFBundleShortVersionString` e `CFBundleVersion`
   do IPA; o script confere.
2. **Gere o IPA sem assinatura**, no macOS com Xcode:

   ```bash
   tool/release/ios.sh
   ```

   Sai `build/ios/ipa/jabuticaba-<versão>-<build>.ipa`, com tamanho e SHA-256
   impressos. O script falha se a versão do pacote não bater com o `pubspec.yaml`.
3. **Publique a release** com a tag e anexe o IPA:

   ```bash
   git tag v0.1.1 && git push origin v0.1.1
   ```

   O workflow `.github/workflows/release.yml` compila o IPA e anexa à release
   (junto dos instaladores de desktop). Também dá para anexar à mão:

   ```bash
   gh release upload v0.1.1 build/ios/ipa/jabuticaba-0.1.1-2.ipa
   ```
4. **Atualize a source** (o JSON que o AltStore lê):

   ```bash
   tool/release/altstore/make_source.py \
     --ipa build/ios/ipa/jabuticaba-0.1.1-2.ipa \
     --url https://github.com/Ways-of-Seeing/jabuticaba/releases/download/v0.1.1/jabuticaba-0.1.1-2.ipa \
     --notes "O que mudou nesta versão"
   ```

   Isso escreve `site/altstore.json`. Confira as capturas em `site/screenshots/`
   (a primeira é a que aparece no Browse) e faça commit:

   ```bash
   git add site/altstore.json && git commit -m "release(ios): 0.1.1 no AltStore"
   git push
   ```

   O workflow `pages` publica o `site/` no GitHub Pages.
5. **Confira no aparelho**: abra a URL da source no Safari do iPhone e toque em
   “Adicionar ao AltStore”, ou adicione à mão em AltStore → Browse → Sources → +.

## Regras do AltStore que fazem a instalação falhar

- **`appPermissions` tem que bater com o IPA.** O jabuticaba não usa
  entitlements nem permissões de privacidade, então a source declara
  `{"entitlements": [], "privacy": {}}`. Se um dia entrar câmera, microfone,
  fotos ou App Groups, atualize o JSON **e** o IPA; divergência faz o AltStore
  recusar a instalação.
- **`bundleIdentifier`, `version` e `buildVersion` diferenciam maiúsculas de
  minúsculas** e precisam ser idênticos aos do `Info.plist`.
- **`size` em bytes** (o gerador pega do arquivo).
- **A ordem de `versions` importa**: a primeira é a “última”. O gerador mantém
  uma versão só; ao publicar a segunda, mova a antiga para baixo no JSON ou
  regenere a lista.
- **Capturas**: proporção 9:19.5 (iPhone com Face ID) pode ser só a URL; outros
  formatos precisam de `width`/`height`. As nossas são 1290×2796.
- **IPA é zip com `Payload/Runner.app` na raiz.** O `tool/release/ios.sh` monta
  assim; zipar o `.app` direto dá erro 1007/2007.

## Conta Apple gratuita: o que avisar a quem instala

- O app **expira em 7 dias** e precisa ser renovado no AltStore (com o AltServer
  no Mac/PC, na mesma rede).
- No máximo **3 apps** por aparelho com conta gratuita.
- **10 App IDs por semana**; cada extensão consome um. O jabuticaba não tem
  extensões, então gasta um só.
- **Push, iCloud e Associated Domains não funcionam** com conta gratuita. O app
  não usa nenhum dos três.
- **Tokens ficam no Keychain** e são vinculados ao Team ID de quem assinou. Se a
  pessoa trocar de conta Apple e reinstalar, precisa entrar de novo nas contas
  do fediverso (não há dado irrecuperável além disso).

## Testar antes de publicar

```bash
# 1. O pacote abre e tem a estrutura certa?
unzip -l build/ios/ipa/jabuticaba-*.ipa | head

# 2. Versão, build, bundle id e iOS mínimo
unzip -p build/ios/ipa/jabuticaba-*.ipa Payload/Runner.app/Info.plist > /tmp/i.plist
plutil -p /tmp/i.plist | grep -E "CFBundleIdentifier|CFBundleShortVersionString|CFBundleVersion|MinimumOSVersion"

# 3. A source é JSON válido e aponta para arquivos que existem?
python3 -m json.tool site/altstore.json > /dev/null && echo "JSON ok"
curl -sI "$(python3 -c 'import json;print(json.load(open("site/altstore.json"))["apps"][0]["versions"][0]["downloadURL"])')" | head -3

# 4. No iPhone (cabo, Developer Mode ligado)
flutter run -d <device-id> --release
```

O teste que importa é no aparelho: instalar pelo AltStore, abrir, conectar uma
conta Mastodon pelo navegador do sistema (OAuth com `jabuticaba://oauth`),
curtir, publicar, denunciar e bloquear alguém, e renovar o app depois de 7 dias.

## AltStore PAL (quando houver conta paga)

O PAL está disponível no Brasil desde 18/06/2026 (iOS 26.5+), mas continua
exigindo conta Apple Developer paga. O resumo do fluxo:

1. App Store Connect → criar o app com o bundle id definitivo.
2. Aceitar o *Alternative Terms Addendum* (UE) quando aplicável.
3. Subir o build pelo Xcode/Transporter e escolher **Review Type: Notarization**.
4. Registrar o Developer ID na API do AltStore e autorizar o marketplace.
5. Baixar o **ADP** e hospedar preservando a estrutura (ou usar `assetURLs` com
   GitHub Releases).
6. Na source, acrescentar `marketplaceID` (o “Apple ID” do app) e apontar
   `downloadURL` para o `manifest.json` do ADP.

No PAL os apps não expiram, não há limite de 3 e o usuário não precisa de
computador. A taxa da Apple no modelo alternativo é a *Core Technology
Commission* (5% sobre bens digitais); a AltStore não cobra comissão.

## Descobribilidade (opcional)

Para aparecer no <https://explore.alt.store>, acrescente `fediUsername` à source
e federe a source pela API do AltStore. O nome de usuário é imutável — escolha
com calma (ex.: `jabuticaba`). Isso não substitui a notarização no PAL.
