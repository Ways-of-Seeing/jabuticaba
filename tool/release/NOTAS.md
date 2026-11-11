Primeiro pré-lançamento do jabuticaba: todas as redes abertas do fediverso num app só, sem anúncios e sem nada da Meta.

## Baixar

- **iPhone** (iOS 15+): `jabuticaba-0.1.1-2.ipa` — instale pelo AltStore, que assina o app no aparelho com a sua conta Apple. Guia: [docs/ALTSTORE.md](https://github.com/Ways-of-Seeing/jabuticaba/blob/main/docs/ALTSTORE.md).
- **macOS** (Apple Silicon e Intel): `jabuticaba-macos.dmg`
- **Windows** 10/11: `jabuticaba-windows-instalador.exe` (ou `jabuticaba-windows-x64.zip`, portátil)
- **Linux** 64 bits: `jabuticaba-linux-x64.tar.gz` (rode `./instalar.sh` dentro da pasta)

Os arquivos ainda não têm assinatura paga da Apple nem da Microsoft, então o sistema pode avisar na primeira abertura. No iPhone, a conta Apple gratuita vale 7 dias por assinatura e até 3 apps; renove pelo AltStore. O passo a passo está em [docs/INSTALAR.md](https://github.com/Ways-of-Seeing/jabuticaba/blob/main/docs/INSTALAR.md) e [docs/ALTSTORE.md](https://github.com/Ways-of-Seeing/jabuticaba/blob/main/docs/ALTSTORE.md).

## O que tem

- Explorar, Fio, Clipes, Fotos, Música, Podcasts, Comunidades e Você.
- Mastodon, Bluesky, Pixelfed, Loops, PeerTube, Lemmy, Funkwhale e Castopod.
- Explorar e seguir sem conta; criar ou conectar contas com ajuda; publicar em várias redes de uma vez.
- **iPhone:** login Mastodon/Funkwhale pelo navegador seguro do sistema, voltando sozinho por `jabuticaba://oauth` (com `state` contra CSRF).
- **Moderação:** denunciar, silenciar e bloquear nas redes que oferecem API; conteúdo sensível começa escondido.
- **Privacidade:** sem servidor próprio, sem analytics. Tokens no Keychain, presos ao aparelho.
- Oito temas, do Paperwhite ao Windows 95.

## Correções desta versão

- Performance: grade de fotos virtualizada, cache HTTP com teto e deduplicação, índice de podcasts fora do isolate de UI, busca de podcasts com debounce, menos blur por frame e vídeo que não reinicializa à toa.
- Segurança: links externos restritos a `http`/`https`, validação de `state` no OAuth (inclusive no loopback do desktop), tokens com `first_unlock_this_device`, manifesto de privacidade do iOS.
- Android: permissão `INTERNET` no manifesto principal (o release ficava offline) e retorno do OAuth registrado.

## Ainda não

- Vídeo e áudio no Windows e no Linux (no macOS e no iOS funcionam).
- Responder posts e anexar mídia ao publicar.
- Build público para Android.
- Assinatura de código e lojas oficiais (App Store e Google Play).

Telas de tudo: [docs/TELAS.md](https://github.com/Ways-of-Seeing/jabuticaba/blob/main/docs/TELAS.md). Site do iPhone: <https://ways-of-seeing.github.io/jabuticaba/>.
