#!/usr/bin/env python3
"""Fotografa cada tela do jabuticaba e monta o catálogo docs/TELAS.md.

Pré-requisitos:
  1. build web em modo demonstração, servido em http://localhost:8791 (com
     `python3 tool/screens/feed_proxy.py` rodando, para os podcasts)
       flutter build web --release --dart-define=DEMO=true \
         --dart-define=CASTOPOD_INDEX=http://localhost:8791/podcastindex.json \
         --dart-define=FEED_PROXY=http://localhost:8793/?url=
       curl -L -o build/web/podcastindex.json https://index.castopod.org/podcastindex.json
       (cd build/web && python3 -m http.server 8791)
  2. uma ferramenta de captura que aceite `<url> <saida.png> <largura> <altura> <espera>`
     em $SNAPSHOT (no estúdio: o snapshot WKWebView do dashboard).

Uso:
  python3 tool/screens/capture.py              # captura tudo e gera o catálogo
  python3 tool/screens/capture.py explorar fio # só essas cenas
  python3 tool/screens/capture.py --doc        # só regenera docs/TELAS.md

As cenas ficam em tool/screens/scenes.tsv. O conteúdo é real e público,
vindo das redes no momento da captura; revise antes de publicar.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "telas"
BASE = os.environ.get("JABU_URL", "http://localhost:8791/")
SIZES = {"d": ("desktop", 1440, 900), "m": ("celular", 390, 844)}


def scenes():
    for line in (Path(__file__).parent / "scenes.tsv").read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            kind, name, query, section, caption = line.split("\t")
            yield kind, name, query, section, caption


def shoot(snap, kind, name, query):
    from PIL import Image

    folder, w, h = SIZES[kind]
    (OUT / folder).mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "shot.png"
        r = subprocess.run([snap, f"{BASE}?{query}", str(png), str(w), str(h), os.environ.get("WAIT", "16")],
                           capture_output=True, text=True)
        if r.returncode != 0 or not png.exists():
            return f"falhou: {folder}/{name}"
        Image.open(png).convert("RGB").save(OUT / folder / f"{name}.jpg", quality=82, optimize=True)
        return f"ok: {folder}/{name}"


def capture(only):
    from concurrent.futures import ThreadPoolExecutor

    snap = os.environ.get("SNAPSHOT")
    if not snap:
        sys.exit("Defina SNAPSHOT com o caminho da ferramenta de captura.")
    todo = [(k, n, q) for k, n, q, _, _ in scenes() if not only or n in only]
    with ThreadPoolExecutor(int(os.environ.get("JOBS", "4"))) as pool:
        for line in pool.map(lambda t: shoot(snap, *t), todo):
            print(line, flush=True)


def doc():
    by_section = {}
    for kind, name, _, section, caption in scenes():
        folder = SIZES[kind][0]
        if (OUT / folder / f"{name}.jpg").exists():
            by_section.setdefault(section, []).append((folder, name, caption))
    lines = [
        "# Telas do jabuticaba",
        "",
        "Capturas de todas as abas, telas, menus e fluxos do app, feitas com o build web em modo",
        "demonstração (`--dart-define=DEMO=true`) em novembro de 2026. O conteúdo é real e público, vindo das redes no",
        "momento da captura. Para refazer: `python3 tool/screens/capture.py` (veja o cabeçalho do script).",
        "",
        "O jabuticaba não integra Threads nem nenhum serviço da Meta; nada disso aparece aqui.",
        "",
    ]
    for section, items in by_section.items():
        lines += [f"## {section}", ""]
        if all(folder == "celular" for folder, _, _ in items):
            # Telas de celular lado a lado, em linhas de quatro.
            for i in range(0, len(items), 4):
                row = items[i:i + 4]
                lines.append("| " + " | ".join(c for _, _, c in row) + " |")
                lines.append("|" + "---|" * len(row))
                lines.append("| " + " | ".join(
                    f'<img src="telas/{f}/{n}.jpg" width="190" alt="{c}">' for f, n, c in row) + " |")
                lines.append("")
            continue
        for folder, name, caption in items:
            lines += [f"### {caption}", "", f"![{caption}](telas/{folder}/{name}.jpg)", ""]
    (ROOT / "docs" / "TELAS.md").write_text("\n".join(lines))
    print("docs/TELAS.md atualizado")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--doc" not in args:
        capture(set(args))
    doc()
