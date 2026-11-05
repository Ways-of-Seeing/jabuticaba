"""Gera os SVGs do ícone do jabuticaba e exporta PNGs com o Inkscape.

Uso: python3 tool/icon/make_icon.py   (a partir da raiz do projeto)
Saída: assets/brand/icon_full.png (iOS/Android/Windows/web),
       assets/brand/icon_macos.png (squircle com margem, padrão macOS),
       assets/brand/logo.png (só as frutas, fundo transparente).
"""
import os
import subprocess

OUT = "assets/brand"
TMP = "tool/icon"

DEFS = """
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFF8EE"/>
    <stop offset="1" stop-color="#F5D6EE"/>
  </linearGradient>
  <radialGradient id="glow" cx="0.5" cy="0.42" r="0.55">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.9"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="fruit" cx="0.36" cy="0.32" r="0.78">
    <stop offset="0" stop-color="#C88AF2"/>
    <stop offset="0.28" stop-color="#8E3CC0"/>
    <stop offset="0.7" stop-color="#4F1468"/>
    <stop offset="1" stop-color="#250630"/>
  </radialGradient>
  <radialGradient id="fruitBack" cx="0.38" cy="0.32" r="0.8">
    <stop offset="0" stop-color="#A964DA"/>
    <stop offset="0.35" stop-color="#6E2596"/>
    <stop offset="1" stop-color="#1E0528"/>
  </radialGradient>
  <linearGradient id="rim" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0.55" stop-color="#E7B6FF" stop-opacity="0"/>
    <stop offset="1" stop-color="#E7B6FF" stop-opacity="0.85"/>
  </linearGradient>
  <linearGradient id="leaf" x1="0" y1="1" x2="1" y2="0">
    <stop offset="0" stop-color="#2F9A55"/>
    <stop offset="1" stop-color="#8BE39A"/>
  </linearGradient>
  <filter id="soft" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="18"/>
  </filter>
  <filter id="blur6" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="6"/>
  </filter>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="150%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="26"/>
    <feOffset dy="22" result="b"/>
    <feFlood flood-color="#3A0B4C" flood-opacity="0.28"/>
    <feComposite in2="b" operator="in" result="s"/>
    <feMerge><feMergeNode in="s"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
"""


def berry(cx, cy, r, grad):
    """Uma jabuticaba: corpo, luz de borda, brilhos e a coroinha do topo."""
    crown_y = cy - r * 0.93
    star = []
    import math
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r * (0.12 if i % 2 == 0 else 0.05)
        star.append(f"{cx + rr * math.cos(a):.1f},{crown_y + rr * math.sin(a) * 0.55:.1f}")
    return f"""
  <circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#{grad})"/>
  <circle cx="{cx}" cy="{cy}" r="{r - 6}" fill="none" stroke="url(#rim)" stroke-width="{r * 0.09:.1f}" filter="url(#blur6)"/>
  <ellipse cx="{cx - r * 0.34:.1f}" cy="{cy - r * 0.42:.1f}" rx="{r * 0.30:.1f}" ry="{r * 0.17:.1f}"
           transform="rotate(-32 {cx - r * 0.34:.1f} {cy - r * 0.42:.1f})" fill="#FFFFFF" opacity="0.9"/>
  <circle cx="{cx - r * 0.06:.1f}" cy="{cy - r * 0.62:.1f}" r="{r * 0.05:.1f}" fill="#FFFFFF" opacity="0.75"/>
  <ellipse cx="{cx}" cy="{crown_y + r * 0.02:.1f}" rx="{r * 0.15:.1f}" ry="{r * 0.06:.1f}" fill="#2A0734" opacity="0.55"/>
  <polygon points="{' '.join(star)}" fill="#1A0421"/>
  <circle cx="{cx}" cy="{crown_y:.1f}" r="{r * 0.025:.1f}" fill="#7A3A8F"/>
"""


LEAF = """
  <g transform="translate(572 356) rotate(-38)">
    <path d="M0 0 C 40 -10 70 -14 95 -12" stroke="#2C7A45" stroke-width="16" fill="none" stroke-linecap="round"/>
    <path d="M 90 -12 C 160 -110 330 -120 400 -40 C 330 40 170 70 90 -12 Z" fill="url(#leaf)"/>
    <path d="M 95 -12 C 190 -40 300 -50 392 -40" stroke="#E8FFEA" stroke-width="9" fill="none" stroke-linecap="round" opacity="0.85"/>
    <g stroke="#E8FFEA" stroke-width="6" stroke-linecap="round" opacity="0.6" fill="none">
      <path d="M 170 -30 C 190 -60 210 -75 232 -86"/>
      <path d="M 240 -38 C 262 -64 282 -78 304 -86"/>
      <path d="M 310 -43 C 326 -60 340 -68 356 -72"/>
      <path d="M 180 -26 C 205 -6 225 6 246 12"/>
      <path d="M 252 -34 C 276 -16 296 -6 318 0"/>
    </g>
  </g>
"""

FRUITS = (
    '<ellipse cx="540" cy="884" rx="250" ry="34" fill="#5A1A73" opacity="0.22" filter="url(#soft)"/>'
    + '<g filter="url(#shadow)">'
    + berry(352, 470, 168, "fruitBack")
    + berry(566, 612, 268, "fruit")
    + "</g>"
    + LEAF
)


def svg(body, size=1024):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">{DEFS}{body}</svg>'


full = svg(
    '<rect width="1024" height="1024" fill="url(#bg)"/>'
    '<circle cx="512" cy="470" r="470" fill="url(#glow)"/>'
    + f'<g transform="translate(512 512) scale(0.86) translate(-512 -540)">{FRUITS}</g>'
)

macos = svg(
    '<g filter="url(#shadow)"><rect x="100" y="100" width="824" height="824" rx="186" fill="url(#bg)"/></g>'
    '<clipPath id="sq"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath>'
    '<g clip-path="url(#sq)"><circle cx="512" cy="470" r="400" fill="url(#glow)"/>'
    + f'<g transform="translate(512 512) scale(0.69) translate(-512 -540)">{FRUITS}</g></g>'
)

logo = svg(f'<g transform="translate(512 512) scale(1.28) translate(-512 -540)">{FRUITS}</g>')

# Android adaptativo: só 66% centrais ficam garantidamente visíveis.
adaptive = svg(f'<g transform="translate(512 512) scale(0.62) translate(-512 -540)">{FRUITS}</g>')

os.makedirs(OUT, exist_ok=True)
for name, content in [("icon_full", full), ("icon_macos", macos), ("logo", logo), ("logo_adaptive", adaptive)]:
    path = f"{TMP}/{name}.svg"
    with open(path, "w") as f:
        f.write(content)
    subprocess.run(
        ["inkscape", path, "--export-type=png", f"--export-filename={OUT}/{name}.png", "-w", "1024", "-h", "1024"],
        check=True,
        capture_output=True,
    )
    print("ok", name)

# --- Variações para web e desktop ------------------------------------------
# Favicon vetorial (nítido em qualquer tamanho), PNGs pequenos com mais
# contraste e um .ico multi-tamanho.
from PIL import Image  # noqa: E402

subprocess.run(["cp", f"{TMP}/logo.svg", "web/favicon.svg"], check=True)
full_png = Image.open(f"{OUT}/icon_full.png").convert("RGBA")
for size, path in [(32, "web/favicon.png"), (180, "web/icons/apple-touch-icon.png")]:
    full_png.resize((size, size), Image.LANCZOS).save(path)
logo_png = Image.open(f"{OUT}/logo.png").convert("RGBA")
logo_png.save("web/favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
# Ícone da janela no Linux (o runner carrega este arquivo).
full_png.resize((256, 256), Image.LANCZOS).save("linux/runner/app_icon.png")
print("ok web/linux")
