# Auditoria — 11/11/2026

Revisão de segurança, performance e UX antes da primeira publicação no AltStore.
Branch: `release/altstore`. Base: `flutter analyze` limpo, 18 testes passando.

## Segurança

| Achado | Gravidade | Estado |
|---|---|---|
| OAuth sem `state` (Mastodon e Funkwhale), inclusive no loopback `127.0.0.1` | Alta (CSRF de login) | Corrigido: `state` aleatório por tentativa, validado no callback do sistema e no loopback |
| `openUrl` abria qualquer esquema vindo de HTML remoto (`javascript:`, `file:`, deep links) | Média | Corrigido: só `http`/`https`, com host e sem credenciais embutidas |
| Tokens no Keychain com acessibilidade padrão (podiam entrar em backup) | Média | Corrigido: `first_unlock_this_device` |
| Cache HTTP sem limite, sem eviction e gravando mesmo com `cache: false` | Média (memória/privacidade) | Corrigido: LRU de 150 entradas/8 MB, expiração, teto de 512 KB por resposta e deduplicação de requisições |
| Corpo de RSS/XML sem limite de tamanho | Baixa (DoS de memória) | Corrigido: corte em 8 MB |
| Android release sem permissão `INTERNET` | Alta (app offline) | Corrigido no manifesto principal |
| Ausência de denúncia/bloqueio/filtro (diretriz 1.2 da App Store) | Alta para loja | Corrigido: denunciar, silenciar e bloquear + conteúdo sensível escondido por padrão |
| OAuth móvel exigia colar código | UX/segurança | Corrigido com `ASWebAuthenticationSession`/Custom Tabs e redirect `jabuticaba://oauth`; fallback de código mantido |

Verificações feitas:

- `mastodon.social` aceita `redirect_uris=jabuticaba://oauth` (teste real na API de apps, HTTP 200).
- IPA sem assinatura (`code object is not signed at all`), com `Payload/Runner.app`, arm64, `MinimumOSVersion 15.0`.
- `Info.plist` sem ATS frouxo; só HTTPS nas APIs.
- Nenhum segredo em texto no repositório; tokens só no Keychain e em memória.
- `PrivacyInfo.xcprivacy` incluído no bundle (sem rastreamento, `UserDefaults` com motivo `CA92.1`).

### Pendências de segurança

- Desbloquear/desfazer silêncio ainda é pelo site da rede (o app não guarda o `rkey`/ID do bloqueio).
- Não há PKCE no OAuth do Mastodon; o `client_secret` é público por natureza em app nativo. Adicionar PKCE exige checar suporte por versão de servidor.
- Não há certificate pinning (não é prática obrigatória e dificulta rotação de CDNs).

## Performance

| Achado | Impacto | Estado |
|---|---|---|
| `MasonrySliver` construía **todas** as fotos já carregadas num `SliverToBoxAdapter` | Memória cresce sem limite; jank e risco de OOM | Corrigido: `SliverCrossAxisGroup` + `SliverList.builder` por coluna |
| Fotos do visualizador e previews de vídeo decodificados em resolução original | Picos de 40+ MB por imagem | Corrigido: `cacheWidth` baseado na tela; logo 1024 px também |
| `BackdropFilter` sigma 24 na barra inferior sobre véu 80–85% opaco | `saveLayer` por frame, jank em 120 Hz | Corrigido: véu quase opaco sem blur (aparência preservada) |
| Abas ocultas mantinham `AnimationController` rodando (`IndexedStack` sem `TickerMode`) | CPU/bateria em repouso | Corrigido: `TickerMode` por aba e `HeroController` memoizado |
| Índice de podcasts (≈4 MB) decodificado e 2.000 `htmlToText` na UI thread | Congelamento de 1–3 s | Corrigido: `Isolate.run` + `Api.text` sem reter o JSON bruto |
| Busca de podcasts sem debounce, 2 sorts e haystacks a cada tecla | Engasgo ao digitar | Corrigido: debounce de 300 ms, derivados memoizados e haystack por objeto |
| `RichContent` reparseava HTML e recriava `TapGestureRecognizer` a cada build | Custo por card em scroll | Corrigido: spans memoizados por assinatura |
| `buildTheme` recriado a cada build do player de clipes | Rebuild de subtree | Corrigido: cache por `JabuStyle` |
| Video controller atribuído antes de `initialize()`; `_paused` não resetava | Exceções e "preto + spinner" ao voltar | Corrigido: controller só é exposto pronto, proteção contra dispose e reset de pausa |

Ainda no radar (não bloqueia publicar): streaming progressivo no `mix()` (hoje espera a fonte mais lenta), cache de imagem em disco, `TickerMode` com descarte de abas antigas, subset de fontes.

## UX / iOS

- Alvos de toque de curtir/compartilhar/responder tinham 30 pt; agora mínimo de 44 pt com rótulos de acessibilidade.
- Barra inferior: `Semantics` com `selected` e rótulo por aba.
- Visualizador de mídia: botão fechar com rótulo.
- Denúncia com motivo, detalhes e confirmação de bloqueio; ações não suportadas pela rede são escondidas em vez de dar erro.
- Login móvel agora explica que a autorização abre no navegador do sistema e volta sozinha, com opção de colar código.

Validação visual: capturas 1290×2796 geradas do build web em modo demonstração (Explorar, Fio, Fotos, Música, onboarding e temas). **Falta rodar no iPhone físico** para conferir Dynamic Type, safe areas, gesto de voltar e o fluxo real do AltStore.

## Testes

- `flutter test`: 18 testes (core, OAuth/state, links externos, moderação por rede).
- `flutter analyze`: sem issues.
- `tool/release/ios.sh`: IPA 0.1.1 (2), 11.576.533 bytes, SHA-256 `bc57b47a…`.
- `site/altstore.json` validado contra o IPA: bundle id, versão, build, tamanho, `minOSVersion`, ícone, header e capturas existentes.

## Próximos passos recomendados

1. Instalar no iPhone por cabo ou pelo AltStore e testar login, publicar, denunciar e renovação de 7 dias.
2. Publicar a branch, criar a tag `v0.1.1` e habilitar o GitHub Pages.
3. Rodar o build Linux com WebKitGTK (`libwebkit2gtk-4.1-dev`) antes de anunciar Linux.
4. Trocar `video_player` por `media_kit` para vídeo no Linux/Windows.
