# Identidade do jabuticaba

> Todas as redes abertas. Um lugar só.

## Por que "jabuticaba"

A jabuticabeira é uma árvore brasileira que dá fruto direto no tronco: dezenas de frutinhas grudadas na mesma madeira, cada uma inteira, todas do mesmo pé. É a imagem do que o app faz com o fediverso — muitas redes independentes (Mastodon, Bluesky, Pixelfed, Loops, PeerTube, Lemmy, Funkwhale, Castopod) brotando de um tronco comum, que são os protocolos abertos.

E é coisa nossa. Por isso o app fala português primeiro, com calor e sem jargão.

## Missão

Tornar o fediverso fácil, bonito e acolhedor para qualquer pessoa: explorar sem conta, entrar sem medo e ter todas as redes abertas num lugar só.

## Visão

Redes sociais que funcionem como a jabuticabeira: muitos frutos, de muitos donos, num tronco comum e aberto. Ninguém deveria precisar escolher entre estar com a sua comunidade e ter liberdade sobre a própria vida online.

## Valores

| Valor | O que significa na prática |
|---|---|
| **Aberto por padrão** | Protocolos abertos, código aberto, nada de jardim murado. Se a pessoa sair do jabuticaba, leva tudo com ela. |
| **Acolhimento** | Linguagem simples, português do Brasil primeiro, explicação antes de pedir qualquer coisa. Ninguém fica para trás por não saber o que é "instância". |
| **Autonomia** | A pessoa escolhe onde mora, o que segue e como o app parece. Sugerimos; não decidimos por ela. |
| **Sem Meta** | O app não integra Threads, Instagram, Facebook nem outro serviço da Meta, e descarta o conteúdo do Threads que chega pela federação. Redes abertas de verdade, de gente e comunidades. |
| **Atenção não é produto** | Sem anúncios e sem algoritmo de engajamento. O que aparece em "Em alta" vem das próprias redes, e a gente diz de onde. |
| **Privacidade de verdade** | O que dá para guardar no aparelho fica no aparelho. Senhas são digitadas no site do servidor; tokens ficam no cofre do sistema. |
| **Beleza com propósito** | Cuidado com cada detalhe, mas a favor da leitura e da acessibilidade (alto contraste, movimento reduzido, temas). |
| **Diversidade** | Muitas redes, muitos formatos, muitos jeitos de usar — do TikTok federado ao fórum, do tema Matrix ao Paperwhite. |

## Personalidade

| O jabuticaba é | O jabuticaba não é |
|---|---|
| curioso | sabichão |
| caloroso | meloso |
| brasileiro | caricato |
| brincalhão na medida | bobo ou cheio de piadinha |
| claro e direto | técnico ou burocrático |
| confiável | alarmista |

## Voz e tom

Falamos como uma amiga que entende de tecnologia e quer te ver bem.

- **Você, não "o usuário".** Segunda pessoa, sempre.
- **Frases curtas.** Uma ideia por frase.
- **Explique antes de pedir.** "O Lemmy não tem login por navegador, então a senha vai direto para o seu servidor" antes do campo de senha.
- **Verbo no botão.** "Criar minha conta", "Conectar", "Publicar em 2". Nunca "OK" ou "Enviar" genérico.
- **Erros dizem o que fazer.** "Não consegui falar com esse servidor. Confira o endereço e sua conexão." Sem "Ops!" e sem culpa.
- **Emoji com moderação.** Um por momento especial (🫐, 🎉, 📬), nunca no meio de frase técnica.

### Dizemos / evitamos

| Dizemos | Evitamos |
|---|---|
| servidor | instância |
| conta | perfil federado, handle |
| seu endereço (`@voce@servidor`) | WebFinger, acct |
| entrar no fediverso | fazer onboarding |
| senha de app | token, credencial |
| Fio | timeline, feed (na interface) |
| Clipes | reels, shorts |
| seguir (fica salvo no aparelho) | inscrever-se, subscribe |
| comunidade | sub, subreddit, grupo |

## Público

1. **Curiosas do fediverso:** ouviram falar de Mastodon ou Bluesky e não sabem por onde começar. Prioridade número um: explorar sem conta e um cadastro que não assusta.
2. **Gente que já usa várias redes abertas:** quer tudo num lugar e publicar em mais de uma ao mesmo tempo.
3. **Quem saiu das redes grandes:** procura um lugar sem anúncios e sem algoritmo, mas sem abrir mão de vídeos curtos e fotos.

## Onde está o resto

- **Brandbook visual** (logo, cores, tipografia, temas, componentes): [brandbook.html](brandbook.html)
- **Media kit** (logos, ícones, imagens para redes, paleta, fontes): [media-kit/](media-kit/README.md)
- **Tokens no código:** `lib/ui/theme.dart` (cada tema é um `JabuStyle`)
