"""Gera os ícones do OneSaver (gradiente estilo Instagram + glifo de download).

Saídas em assets/icon/:
  - icon.png            (1024, gradiente + glifo)  -> legacy/iOS
  - icon_background.png  (1024, só gradiente)        -> adaptive background
  - icon_foreground.png  (1024, só glifo, transparente, na zona segura) -> adaptive foreground
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 4  # supersampling para bordas suaves
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
os.makedirs(OUT, exist_ok=True)

# Paleta diagonal estilo Instagram.
STOPS = [
    (0.00, (0xFE, 0xDA, 0x77)),  # amarelo
    (0.25, (0xFA, 0x7E, 0x1E)),  # laranja
    (0.50, (0xD6, 0x29, 0x76)),  # magenta
    (0.75, (0x96, 0x2F, 0xBF)),  # roxo
    (1.00, (0x4F, 0x5B, 0xD5)),  # azul
]


def grad_lut(n=1024):
    xs = [s[0] for s in STOPS]
    cs = np.array([s[1] for s in STOPS], dtype=float)
    ts = np.linspace(0, 1, n)
    out = np.zeros((n, 3))
    for c in range(3):
        out[:, c] = np.interp(ts, xs, cs[:, c])
    return out


def gradient(size):
    lut = grad_lut()
    ii, jj = np.meshgrid(np.arange(size), np.arange(size))
    t = (ii + jj) / (2 * (size - 1))
    idx = (t * (len(lut) - 1)).astype(int)
    arr = lut[idx].astype("uint8")
    return Image.fromarray(arr, "RGB")


def draw_glyph(scale=1.0, color=(255, 255, 255, 255)):
    """Desenha seta de download + bandeja, centralizado, num layer transparente 1024."""
    g = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    cx = SIZE * SS / 2
    cy = SIZE * SS / 2

    def s(v):  # unidade base (1024) -> canvas supersample, relativo ao centro
        return v * SS

    # Eixo da seta
    shaft_w = s(150 * scale)
    shaft_top = cy - s(330 * scale)
    shaft_bot = cy + s(40 * scale)
    d.rounded_rectangle(
        [cx - shaft_w / 2, shaft_top, cx + shaft_w / 2, shaft_bot],
        radius=shaft_w / 2,
        fill=color,
    )
    # Ponta da seta (triângulo)
    head_half = s(200 * scale)
    head_tip = cy + s(230 * scale)
    d.polygon(
        [(cx - head_half, shaft_bot - s(10 * scale)),
         (cx + head_half, shaft_bot - s(10 * scale)),
         (cx, head_tip)],
        fill=color,
    )
    # Bandeja (linha de base "salvar")
    tray_w = s(330 * scale)
    tray_top = cy + s(300 * scale)
    tray_h = s(70 * scale)
    d.rounded_rectangle(
        [cx - tray_w / 2, tray_top, cx + tray_w / 2, tray_top + tray_h],
        radius=tray_h / 2,
        fill=color,
    )
    return g.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    bg = gradient(SIZE).convert("RGBA")
    glyph = draw_glyph(scale=1.0)

    # Sombra suave atrás do glifo para dar profundidade.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sh = draw_glyph(scale=1.0, color=(0, 0, 0, 110))
    shadow = Image.alpha_composite(shadow, sh).filter(ImageFilter.GaussianBlur(10))
    shadow = Image.eval(shadow, lambda a: a)  # mantém
    shadow = shadow.transform(
        (SIZE, SIZE), Image.AFFINE, (1, 0, 0, 0, 1, 12)  # desloca 12px p/ baixo
    )

    icon = Image.alpha_composite(bg, shadow)
    icon = Image.alpha_composite(icon, glyph)
    icon.convert("RGB").save(os.path.join(OUT, "icon.png"))

    # Adaptive background (só gradiente).
    bg.convert("RGB").save(os.path.join(OUT, "icon_background.png"))

    # Adaptive foreground: glifo menor (na zona segura ~60%), transparente.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fg = Image.alpha_composite(fg, draw_glyph(scale=0.62))
    fg.save(os.path.join(OUT, "icon_foreground.png"))

    print("OK: icon.png, icon_background.png, icon_foreground.png em", OUT)


if __name__ == "__main__":
    main()
