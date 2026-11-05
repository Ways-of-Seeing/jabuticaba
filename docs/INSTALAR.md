# Como instalar o jabuticaba

O jabuticaba é gratuito e de código aberto. Esta é a **versão 0.1.0**, um pré-lançamento: já dá para usar, mas ainda pode ter arestas.

## Baixar

| Sistema | Arquivo |
|---|---|
| **macOS** 12 (Monterey) ou mais novo (Apple Silicon e Intel) | [jabuticaba-macos.dmg](https://github.com/Ways-of-Seeing/jabuticaba/releases/download/v0.1.0/jabuticaba-macos.dmg) |
| **Windows** 10 ou 11 (64 bits), com instalador | [jabuticaba-windows-instalador.exe](https://github.com/Ways-of-Seeing/jabuticaba/releases/download/v0.1.0/jabuticaba-windows-instalador.exe) |
| **Windows**, versão portátil (sem instalar) | [jabuticaba-windows-x64.zip](https://github.com/Ways-of-Seeing/jabuticaba/releases/download/v0.1.0/jabuticaba-windows-x64.zip) |
| **Linux** 64 bits (Ubuntu 22.04 ou mais novo, ou distribuição equivalente) | [jabuticaba-linux-x64.tar.gz](https://github.com/Ways-of-Seeing/jabuticaba/releases/download/v0.1.0/jabuticaba-linux-x64.tar.gz) |

Todas as versões: <https://github.com/Ways-of-Seeing/jabuticaba/releases>

> **Ainda não tem no Windows e no Linux:** vídeos (Clipes) e áudio (Música e Podcasts) só tocam no macOS por enquanto. O resto do app funciona igual, e o botão "Abrir" leva o vídeo ou o episódio para o navegador.

## macOS

1. Baixe o **jabuticaba-macos.dmg** e abra o arquivo.
2. Arraste o ícone do jabuticaba para a pasta **Aplicativos**.
3. Abra o jabuticaba pela pasta Aplicativos ou pelo Launchpad.

**Se aparecer "não pode ser aberto porque a Apple não pôde verificá-lo":** o app ainda não é assinado pela Apple (assinatura custa caro e vem depois). Ele é seguro e o código está todo aberto. Para liberar uma vez:

1. Feche o aviso.
2. Abra **Ajustes do Sistema → Privacidade e Segurança**.
3. Role até a mensagem sobre o jabuticaba e clique em **Abrir Mesmo Assim**. Confirme com sua senha ou Touch ID.

Depois disso ele abre normalmente.

**Se aparecer "está danificado e não pode ser aberto":** é o mesmo bloqueio, só que mais rígido. Abra o app **Terminal**, cole a linha abaixo e aperte Enter:

```bash
xattr -dr com.apple.quarantine /Applications/jabuticaba.app
```

## Windows

1. Baixe o **jabuticaba-windows-instalador.exe** e abra.
2. Se o Windows mostrar **"O Windows protegeu o computador"** (SmartScreen), clique em **Mais informações → Executar assim mesmo**. O aviso aparece porque o instalador ainda não tem assinatura digital paga.
3. Siga o instalador: ele não pede senha de administrador e cria o atalho no menu Iniciar (e na área de trabalho, se você marcar).

**Versão portátil:** baixe o **.zip**, clique com o botão direito → **Extrair tudo**, e abra o **jabuticaba.exe** de dentro da pasta. Nada é instalado no sistema.

**Para desinstalar:** Configurações → Aplicativos → jabuticaba → Desinstalar.

## Linux

1. Baixe o **jabuticaba-linux-x64.tar.gz**.
2. Extraia (botão direito → Extrair aqui, ou `tar -xzf jabuticaba-linux-x64.tar.gz`).
3. Entre na pasta **jabuticaba** e rode o instalador, que coloca o app no menu só para o seu usuário (sem `sudo`):

```bash
./instalar.sh
```

Pronto: procure **jabuticaba** no menu de aplicativos. Para rodar sem instalar, abra `./jabuticaba` direto da pasta.

**Para desinstalar:**

```bash
rm -rf ~/.local/share/jabuticaba ~/.local/bin/jabuticaba ~/.local/share/applications/jabuticaba.desktop
```

**Se o login não ficar salvo:** o jabuticaba guarda suas contas no cofre de senhas do sistema (o mesmo do GNOME e do KDE). Em instalações mínimas, instale o `gnome-keyring` (ou o `kwallet`) e entre de novo.

## Primeiro uso

1. **Boas-vindas.** O app mostra as redes que ele junta. Toque em **Começar**.
2. **Interesses.** Escolha alguns assuntos (arte, música, natureza…). Eles montam o seu Explorar e dá para mudar depois.
3. **Tema.** Escolha a cara do app: Jabuticaba, Polpa, Paperwhite, Windows 95, ASCII, Matrix, Alto contraste ou seguir o sistema.
4. **Conta.** Escolha entre **criar minha conta**, **já tenho conta** ou **só quero explorar**. Explorar não pede nada: você pode seguir perfis, hashtags, comunidades e podcasts, e tudo fica salvo no aparelho.

### Conectar uma conta que você já tem

Na aba **Você**, toque em **Já tenho conta** e escolha a rede:

- **Mastodon, Pixelfed e compatíveis:** digite seu endereço (por exemplo `@voce@mastodon.social`). O jabuticaba abre a página de login do seu servidor no navegador; a senha é digitada lá, nunca no app. Volte ao app quando o navegador disser que deu certo.
- **Bluesky:** use uma **senha de app**, não a sua senha principal. No Bluesky: Configurações → Privacidade e segurança → Senhas de app → Adicionar. Dê o nome "jabuticaba" e cole a senha gerada.
- **Lemmy:** servidor, usuário e senha. O Lemmy não tem login pelo navegador; o jabuticaba envia a senha direto para o seu servidor e guarda só o código de acesso.
- **Funkwhale (música):** digite o endereço do servidor (por exemplo `tunez.awadwatt.com`) e faça login no navegador.

Dá para conectar várias contas e publicar em mais de uma ao mesmo tempo.

### Criar a primeira conta

Toque em **Criar uma conta**, diga o que quer fazer por lá (conversar, postar fotos, entrar em comunidades, ouvir música…) e o app sugere servidores abertos em português. No Mastodon e no Funkwhale o cadastro é feito dentro do app, mostrando as regras do servidor antes. Depois é só confirmar o e-mail.

## Privacidade

- Sem anúncios, sem rastreamento e **sem nenhum serviço da Meta**.
- O que você segue e seus interesses ficam no aparelho.
- Os códigos de acesso das contas ficam no cofre do sistema (Chaves do macOS, Gerenciador de Credenciais do Windows, Secret Service no Linux).

## Problemas?

Abra um aviso em <https://github.com/Ways-of-Seeing/jabuticaba/issues> dizendo o sistema, a versão e o que aconteceu.
