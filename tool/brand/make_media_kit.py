"""Gera o media kit do jabuticaba em brand/media-kit/.

Uso (na raiz do projeto, depois de tool/icon/make_icon.py):
    python3 tool/brand/make_media_kit.py

Gera logos (símbolo, ícone, versões mono e wordmark), imagens para redes
sociais, paleta e tokens de cor, e copia as fontes com suas licenças OFL.
"""
import json
import os
import shutil
import urllib.request

from PIL import Image, ImageDraw, ImageFilter, ImageFont

KIT = "brand/media-kit"
BRAND = "assets/brand"
FONTS = "assets/fonts"

# Paleta da marca (mesmos valores de lib/ui/theme.dart).
COLORS = {
    "casca": ("#0F0812", "Fundo do tema escuro; a pele da fruta"),
    "ameixa": ("#7B2D9E", "Cor principal da marca"),
    "uva": ("#9B4DCA", "Variação clara da principal"),
    "brilho": ("#C58AF0", "Destaque sobre fundos escuros"),
    "magenta": ("#E0459B", "Fim do degradê; curtidas e alertas"),
    "folha": ("#5FBF7A", "Confirmações e a folha do símbolo"),
    "polpa": ("#FBF6FA", "Texto sobre escuro; fundo claro"),
}
NETWORKS = {
    "mastodon": "#6364FF",
    "bluesky": "#1185FE",
    "threads": "#8A8A8A",
    "pixelfed": "#F0447A",
    "peertube": "#F1680D",
    "loops": "#00C2A8",
    "lemmy": "#14B88A",
    "funkwhale": "#009FE3",
    "castopod": "#009486",
}
FONT_LICENSES = {
    "Bricolage Grotesque": ("BricolageGrotesque", "bricolagegrotesque"),
    "Plus Jakarta Sans": ("PlusJakartaSans", "plusjakartasans"),
    "Literata": ("Literata", "literata"),
    "Pixelify Sans": ("PixelifySans", "pixelifysans"),
    "IBM Plex Mono": ("IBMPlexMono", "ibmplexmono"),
    "VT323": ("VT323", "vt323"),
}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def font(weight=800, size=100, family="BricolageGrotesque"):
    return ImageFont.truetype(f"{FONTS}/{family}-{weight}.ttf", size)


def trim(img):
    box = img.getbbox()
    return img.crop(box) if box else img


def mono(img, color):
    """Silhueta do símbolo numa cor só, preservando a transparência."""
    alpha = img.getchannel("A")
    solid = Image.new("RGBA", img.size, hex_rgb(color) + (255,))
    solid.putalpha(alpha)
    return solid


def wordmark(symbol, text_color, height=256, vertical=False):
    sym = trim(symbol)
    f = font(800, int(height * 0.62))
    tw = f.getbbox("jabuticaba")
    text_w, text_h = tw[2] - tw[0], tw[3] - tw[1]
    if vertical:
        s = sym.resize((int(height * 1.6 * sym.width / sym.height), int(height * 1.6)), Image.LANCZOS)
        w = max(s.width, text_w) + 40
        canvas = Image.new("RGBA", (w, s.height + text_h + int(height * 0.35)), (0, 0, 0, 0))
        canvas.alpha_composite(s, ((w - s.width) // 2, 0))
        ImageDraw.Draw(canvas).text(((w - text_w) // 2 - tw[0], s.height + int(height * 0.2) - tw[1]), "jabuticaba", font=f, fill=text_color)
        return canvas
    s = sym.resize((int(height * sym.width / sym.height), height), Image.LANCZOS)
    gap = int(height * 0.22)
    canvas = Image.new("RGBA", (s.width + gap + text_w + 20, height), (0, 0, 0, 0))
    canvas.alpha_composite(s, (0, 0))
    ImageDraw.Draw(canvas).text((s.width + gap - tw[0], int(height * 0.56) - text_h // 2 - tw[1]), "jabuticaba", font=f, fill=text_color)
    return canvas


def gradient(size, c1, c2, diagonal=True):
    w, h = size
    g = Image.new("RGB", size)
    a, b = hex_rgb(c1), hex_rgb(c2)
    px = g.load()
    for y in range(h):
        for x in range(w):
            t = ((x / w) + (y / h)) / 2 if diagonal else y / h
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return g


def social_card(size, symbol, title, subtitle):
    w, h = size
    bg = gradient(size, "#140A19", "#3A1347").convert("RGBA")
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((w * 0.45, -h * 0.4, w * 1.3, h * 1.1), fill=hex_rgb("#9B4DCA") + (90,))
    bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(int(h * 0.18))))
    sym = trim(symbol)
    sh = int(h * 0.78)
    sym = sym.resize((int(sh * sym.width / sym.height), sh), Image.LANCZOS)
    bg.alpha_composite(sym, (w - sym.width - int(w * 0.05), (h - sh) // 2))
    d = ImageDraw.Draw(bg)
    pad = int(w * 0.06)
    tf = font(800, int(h * 0.15))
    d.text((pad, int(h * 0.30)), title, font=tf, fill="#FBF6FA")
    sf = font(500, int(h * 0.06), "PlusJakartaSans")
    d.text((pad, int(h * 0.52)), subtitle, font=sf, fill="#D8C6E0")
    # Pílulas das redes
    x, y = pad, int(h * 0.68)
    pf = font(700, int(h * 0.035), "PlusJakartaSans")
    for name, color in NETWORKS.items():
        label = name.capitalize() if name != "peertube" else "PeerTube"
        tw = d.textlength(label, font=pf)
        pw, ph = int(tw + h * 0.05), int(h * 0.065)
        if x + pw > w * 0.62:
            x, y = pad, y + ph + int(h * 0.02)
        d.rounded_rectangle((x, y, x + pw, y + ph), radius=ph // 2, fill=hex_rgb(color) + (60,), outline=color)
        d.text((x + h * 0.025, y + ph / 2), label, font=pf, fill="#FBF6FA", anchor="lm")
        x += pw + int(h * 0.018)
    return bg.convert("RGB")


def main():
    for sub in ["logo", "social", "cores", "fontes", "capturas"]:
        os.makedirs(f"{KIT}/{sub}", exist_ok=True)

    symbol = Image.open(f"{BRAND}/logo.png").convert("RGBA")
    icon = Image.open(f"{BRAND}/icon_full.png").convert("RGBA")
    macos = Image.open(f"{BRAND}/icon_macos.png").convert("RGBA")

    # --- Logos -------------------------------------------------------------
    sym = trim(symbol)
    for size in (1024, 512, 256, 128, 64):
        s = sym.copy()
        s.thumbnail((size, size), Image.LANCZOS)
        s.save(f"{KIT}/logo/simbolo-{size}.png")
    shutil.copy("tool/icon/logo.svg", f"{KIT}/logo/simbolo.svg")
    shutil.copy("tool/icon/icon_full.svg", f"{KIT}/logo/icone-app.svg")
    icon.save(f"{KIT}/logo/icone-app-1024.png")
    icon.resize((512, 512), Image.LANCZOS).save(f"{KIT}/logo/icone-app-512.png")
    macos.save(f"{KIT}/logo/icone-macos-1024.png")
    mono(sym, "#110813").save(f"{KIT}/logo/simbolo-mono-escuro.png")
    mono(sym, "#FBF6FA").save(f"{KIT}/logo/simbolo-mono-claro.png")
    wordmark(symbol, "#1C1020").save(f"{KIT}/logo/wordmark-para-fundo-claro.png")
    wordmark(symbol, "#FBF6FA").save(f"{KIT}/logo/wordmark-para-fundo-escuro.png")
    wordmark(symbol, "#1C1020", vertical=True).save(f"{KIT}/logo/wordmark-vertical-para-fundo-claro.png")
    wordmark(symbol, "#FBF6FA", vertical=True).save(f"{KIT}/logo/wordmark-vertical-para-fundo-escuro.png")

    # --- Redes sociais -----------------------------------------------------
    social_card((1200, 630), symbol, "jabuticaba", "Todas as redes abertas. Um lugar só.").save(
        f"{KIT}/social/compartilhamento-1200x630.png", quality=92
    )
    social_card((1500, 500), symbol, "jabuticaba", "Explore o fediverso").save(f"{KIT}/social/capa-perfil-1500x500.png")
    icon.resize((400, 400), Image.LANCZOS).convert("RGB").save(f"{KIT}/social/avatar-400.png")

    # --- Cores --------------------------------------------------------------
    sw = Image.new("RGB", (1400, 520), "#FBF6FA")
    d = ImageDraw.Draw(sw)
    lf, sf = font(700, 26, "PlusJakartaSans"), font(500, 20, "PlusJakartaSans")
    for i, (name, (hx, _)) in enumerate(COLORS.items()):
        x = 40 + i * 190
        d.rounded_rectangle((x, 40, x + 170, 330), radius=28, fill=hx, outline="#E6DAE4")
        d.text((x, 350), name.capitalize(), font=lf, fill="#1C1020")
        d.text((x, 386), hx, font=sf, fill="#7A6880")
        d.text((x, 414), "RGB " + " ".join(str(v) for v in hex_rgb(hx)), font=sf, fill="#7A6880")
    grad = gradient((1320, 40), "#8E3BB8", "#E0459B", diagonal=False).rotate(0)
    grad = gradient((1320, 40), "#8E3BB8", "#E0459B")
    mask = Image.new("L", grad.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1319, 39), radius=20, fill=255)
    sw.paste(grad, (40, 460), mask)
    sw.save(f"{KIT}/cores/paleta.png")

    tokens = {
        "marca": {k: {"hex": v[0], "uso": v[1]} for k, v in COLORS.items()},
        "degrade": {"de": "#8E3BB8", "para": "#E0459B", "angulo": "135deg"},
        "redes": NETWORKS,
        "fontes": {
            "titulos": "Bricolage Grotesque 700–800",
            "texto": "Plus Jakarta Sans 400–800",
        },
        "raios": {"cartao": 22, "pequeno": 14, "pilula": 999},
        "espacamento": [4, 8, 12, 16, 20, 24, 32],
    }
    with open(f"{KIT}/cores/tokens.json", "w") as f:
        json.dump(tokens, f, indent=2, ensure_ascii=False)
    with open(f"{KIT}/cores/tokens.css", "w") as f:
        f.write("/* Tokens da marca jabuticaba (gerado por tool/brand/make_media_kit.py) */\n:root {\n")
        for k, (hx, _) in COLORS.items():
            f.write(f"  --jabu-{k}: {hx};\n")
        f.write("  --jabu-degrade: linear-gradient(135deg, #8E3BB8, #E0459B);\n")
        for k, hx in NETWORKS.items():
            f.write(f"  --rede-{k}: {hx};\n")
        f.write("  --fonte-titulos: 'Bricolage Grotesque', system-ui, sans-serif;\n")
        f.write("  --fonte-texto: 'Plus Jakarta Sans', system-ui, sans-serif;\n")
        f.write("  --raio-cartao: 22px;\n  --raio-pequeno: 14px;\n}\n")

    # --- Fontes (com licença) ----------------------------------------------
    for fam, (prefix, slug) in FONT_LICENSES.items():
        dest = f"{KIT}/fontes/{fam}"
        os.makedirs(dest, exist_ok=True)
        for fn in os.listdir(FONTS):
            if fn.startswith(prefix) and fn.endswith(".ttf"):
                shutil.copy(f"{FONTS}/{fn}", dest)
        try:
            url = f"https://raw.githubusercontent.com/google/fonts/main/ofl/{slug}/OFL.txt"
            with urllib.request.urlopen(url, timeout=20) as r, open(f"{dest}/OFL.txt", "wb") as out:
                out.write(r.read())
        except Exception as e:  # noqa: BLE001
            print("sem licença para", fam, e)
    build_brandbook()
    print("media kit pronto em", KIT)


def build_brandbook():
    """Monta brand/brandbook.html com os logos embutidos (arquivo único)."""
    import base64
    import io

    def data_uri(path, mime, size=None):
        if size:
            img = Image.open(path).convert("RGBA")
            img.thumbnail((size, size), Image.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, "PNG", optimize=True)
            raw = buf.getvalue()
        else:
            raw = open(path, "rb").read()
        return f"data:{mime};base64," + base64.b64encode(raw).decode()

    html = open("tool/brand/brandbook.template.html", encoding="utf-8").read()
    html = (
        html.replace("{{LOGO_SVG}}", data_uri("tool/icon/logo.svg", "image/svg+xml"))
        .replace("{{ICON_PNG}}", data_uri(f"{BRAND}/icon_full.png", "image/png", 320))
        .replace("{{MACOS_PNG}}", data_uri(f"{BRAND}/icon_macos.png", "image/png", 320))
    )
    with open("brand/brandbook.html", "w", encoding="utf-8") as f:
        f.write(html)


if __name__ == "__main__":
    main()
