#!/usr/bin/env python3
"""Gera o source JSON do AltStore Classic a partir do IPA e das capturas.

Uso:
    tool/release/altstore/make_source.py --ipa build/ios/ipa/jabuticaba-0.1.0-1.ipa \
        --url https://example.com/jabuticaba-0.1.0-1.ipa

O JSON vai para site/altstore.json (publicado pelo GitHub Pages). As capturas
ficam em site/screenshots/ e o ícone em site/icon.png.
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
import sys
import zipfile
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SITE = ROOT / "site"
SCREENSHOTS = SITE / "screenshots"
ICON = SITE / "icon.png"
PUBSPEC = ROOT / "pubspec.yaml"

BASE_URL = "https://ways-of-seeing.github.io/jabuticaba"
BUNDLE_ID = "social.jabuticaba.jabuticaba"
TINT = "#7B2D9E"

NAME = "jabuticaba"
DEVELOPER = "Ways of Seeing"
SUBTITLE = "O fediverso num lugar só"
DESCRIPTION = (
    "Vídeos curtos, fotos, conversas e comunidades das redes abertas num app só. "
    "Mastodon, Bluesky, Pixelfed, PeerTube, Lemmy, Funkwhale, Loops e Castopod no "
    "mesmo fio, sem anúncios e sem rastreamento.\n\n"
    "Explore e siga sem conta. Quando quiser curtir, responder ou publicar, conecte "
    "a conta que você já tem ou crie uma com o passo a passo do app.\n\n"
    "Oito temas, do Paperwhite ao Windows 95. Tudo fica no seu aparelho: o jabuticaba "
    "não tem servidor próprio e não coleta seus dados."
)


def read_pubspec() -> tuple[str, int]:
    text = PUBSPEC.read_text()
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", text, re.M)
    if not m:
        sys.exit("pubspec.yaml sem version: x.y.z+build")
    return m.group(1), int(m.group(2))


def read_ipa(ipa: Path) -> dict:
    with zipfile.ZipFile(ipa) as z:
        with z.open("Payload/Runner.app/Info.plist") as f:
            info = plistlib.load(f)
    return info


def screenshot_entries() -> list[str]:
    if not SCREENSHOTS.is_dir():
        return []
    files = sorted(
        p
        for pattern in ("*.png", "*.jpg", "*.jpeg")
        for p in SCREENSHOTS.glob(pattern)
        if not p.name.startswith(".")
    )
    return [f"{BASE_URL}/screenshots/{p.name}" for p in files]


def build_source(version: str, build: int, date_str: str, url: str, size: int,
                 min_os: str, notes: str) -> dict:
    screenshots = screenshot_entries()
    if not screenshots:
        print("aviso: nenhuma captura em site/screenshots — o AltStore exige pelo menos uma",
              file=sys.stderr)
    header = SITE / "header.png"
    return {
        "name": "jabuticaba",
        "identifier": "social.jabuticaba.altstore",
        "subtitle": SUBTITLE,
        "description": DESCRIPTION,
        "iconURL": f"{BASE_URL}/icon.png",
        **({"headerURL": f"{BASE_URL}/header.png"} if header.is_file() else {}),
        "website": BASE_URL,
        "tintColor": TINT,
        "nsfw": False,
        "apps": [
            {
                "name": NAME,
                "bundleIdentifier": BUNDLE_ID,
                "developerName": DEVELOPER,
                "subtitle": SUBTITLE,
                "localizedDescription": DESCRIPTION,
                "iconURL": f"{BASE_URL}/icon.png",
                "tintColor": TINT,
                "category": "social",
                "screenshots": screenshots,
                # O AltStore recusa instalar se estes campos não baterem com o
                # IPA. O jabuticaba não usa entitlements nem permissões de
                # privacidade (sem câmera, microfone, contatos ou localização).
                "appPermissions": {"entitlements": [], "privacy": {}},
                "versions": [
                    {
                        "version": version,
                        "buildVersion": str(build),
                        "date": date_str,
                        "downloadURL": url,
                        "size": size,
                        "minOSVersion": min_os,
                        "localizedDescription": notes,
                    }
                ],
            }
        ],
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ipa", type=Path, help="caminho do IPA (lê versão e tamanho)")
    ap.add_argument("--url", help="URL pública do IPA")
    ap.add_argument("--size", type=int, help="tamanho em bytes (se não usar --ipa)")
    ap.add_argument("--version", help="sobrescreve a versão")
    ap.add_argument("--build", type=int, help="sobrescreve o build")
    ap.add_argument("--min-os", default=None, help="sobrescreve o iOS mínimo")
    ap.add_argument("--date", default=date.today().isoformat())
    ap.add_argument("--notes", default="")
    ap.add_argument("--out", type=Path, default=SITE / "altstore.json")
    args = ap.parse_args()

    pub_version, pub_build = read_pubspec()
    version = args.version or pub_version
    build = args.build or pub_build
    size = args.size
    min_os = args.min_os

    if args.ipa:
        if not args.ipa.is_file():
            sys.exit(f"IPA não encontrado: {args.ipa}")
        info = read_ipa(args.ipa)
        version = args.version or info.get("CFBundleShortVersionString", version)
        build = args.build or int(info.get("CFBundleVersion", build))
        min_os = min_os or info.get("MinimumOSVersion")
        size = size or args.ipa.stat().st_size
        if info.get("CFBundleIdentifier") != BUNDLE_ID:
            print(f"aviso: bundle id do IPA é {info.get('CFBundleIdentifier')}, "
                  f"esperado {BUNDLE_ID}", file=sys.stderr)

    if not size:
        sys.exit("informe --ipa ou --size")
    if not args.url:
        sys.exit("informe --url com o endereço público do IPA")
    if not min_os:
        min_os = "15.0"

    if not ICON.is_file():
        sys.exit(f"ícone ausente: {ICON}")

    source = build_source(version, build, args.date, args.url, size, min_os,
                          args.notes or f"jabuticaba {version}")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
    print(f"✓ {args.out}  ({version} build {build}, {size} bytes)")


if __name__ == "__main__":
    main()
