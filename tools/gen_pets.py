#!/usr/bin/env python3
"""Mascotas premium: assets/sprites/pet_<id>.png (cuadros de 24x24, 4 columnas x 6 filas:
idle abajo/arriba/lado, caminar abajo/arriba/lado; 'lado' mira a la derecha).
Todo es pixel art procedural con Pillow, sin tomar nada de fuera.
Uso: python3 tools/gen_pets.py [--preview ARCHIVO.png]"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sprites")
W = H = 24
OL = (22, 17, 30, 255)
EYE = (20, 16, 24, 255)


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


class Cv:
    def __init__(self):
        self.p = {}

    def put(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.p[(x, y)] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def blob(self, x0, y0, x1, y1, c):
        """Rectangulo con esquinas redondeadas."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if (x in (x0, x1)) and (y in (y0, y1)):
                    continue
                self.put(x, y, c)

    def image(self, shadow_w=7, shadow_y=21, shadow_a=70):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cx = W // 2
        for x in range(cx - shadow_w // 2, cx + shadow_w // 2 + 1):
            for y in (shadow_y, shadow_y + 1):
                if y == shadow_y + 1 and abs(x - cx) > shadow_w // 2 - 2:
                    continue
                img.putpixel((x, y), (0, 0, 0, shadow_a))
        for (x, y), c in self.p.items():
            img.putpixel((x, y), c)
        src = img.copy()
        for (x, y), c in list(self.p.items()):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in self.p:
                    img.putpixel((nx, ny), OL)
        return img


SPECIES = {
    "ceniza": dict(kind="dog", body="8d929e", dark="5b606c", light="dfe2e8", accent="c8412f", eye="2a6fb0", ear="floppy"),
    "sombra": dict(kind="cat", body="332f44", dark="1d1a29", light="55507a", accent="4fd6e6", eye="f2d04a", ear="point"),
    "presagio": dict(kind="bird", body="2b2842", dark="16141f", light="5d5c92", accent="b78cff", eye="ff5a5a", beak="e8a838"),
    "tizon": dict(kind="raccoon", body="8d867e", dark="46403b", light="ddd8cf", accent="f2d04a", eye="f4f0e0", ear="point"),
    "ambar": dict(kind="fox", body="e2852f", dark="a4531a", light="f8e6c8", accent="62d26f", eye="2a1a10", ear="point"),
}


def wag_b(t):
    return (-1, 0, 1, 0)[t]


def quad(sp, facing, state, t):
    s = {k: (hx(v) if k not in ("kind", "ear") else v) for k, v in sp.items()}
    c = Cv()
    body, dark, light, acc, eye = s["body"], s["dark"], s["light"], s["accent"], s["eye"]
    walk = state == "walk"
    bob = (0, -1, 0, -1)[t] if walk else 0
    breath = 1 if (not walk and t in (1, 2)) else 0
    lift = (0, 1, 0, -1)[t] if walk else 0       # patas alternadas
    raccoon = s["kind"] == "raccoon"
    fox = s["kind"] in ("fox", "raccoon")
    cat = s["kind"] == "cat"
    blink = (not walk) and t == 3
    if facing == "side":
        by = 11 + bob
        # cola
        wag = (0, 1, 2, 1)[t]
        if cat:
            for i in range(6):
                c.put(5 - (i // 3), by + 2 - i - (1 if t % 2 and i > 3 else 0), body)
            c.put(4, by - 4, light)
        elif fox:
            c.blob(2, by - 1 + (wag % 2), 6, by + 3, body)
            c.rect(2, by + 1 + (wag % 2), 3, by + 3, light)
            if raccoon:
                for sx in (3, 5):
                    c.rect(sx, by - 1 + (wag % 2), sx, by + 3, dark)
        else:
            for i in range(4):
                c.put(6 - i, by + 1 - i // 2 - (1 if wag > 1 else 0), body)
            c.put(3, by - 1 - (1 if wag > 1 else 0), light)
        # patas traseras / delanteras (lejanas mas oscuras)
        for lx, off, col in ((7, lift, body), (9, -lift, dark), (13, -lift, body), (15, lift, dark)):
            c.rect(lx, by + 6, lx + 1, 20 + min(0, off), col)
            if off > 0:
                c.rect(lx + 1, 20, lx + 2, 20, col)
            c.put(lx, 20 + min(0, off), light)
        # cuerpo
        c.blob(6, by, 16, by + 6 + breath, body)
        c.rect(7, by + 5 + breath, 15, by + 6 + breath, light)
        c.rect(7, by, 14, by, dark if cat else body)
        # cabeza
        hy = by - 3 + (1 if fox or cat else 0)
        c.blob(14, hy, 20, hy + 6, body)
        c.rect(19, hy + 3, 22, hy + 5, light if not cat else body)
        c.rect(22, hy + 3, 22, hy + 3, EYE)
        c.rect(15, hy + 5, 19, hy + 6, light if not cat else dark)
        if raccoon:   # antifaz
            c.rect(16, hy + 1, 20, hy + 3, dark)
        # orejas
        if s["ear"] == "floppy":
            c.rect(14, hy - 1, 15, hy + 3, dark)
        else:
            c.rect(15, hy - 2, 15, hy, body)
            c.rect(17, hy - 2, 18, hy, body)
            c.put(16, hy - 2, dark)
            c.put(18, hy - 3, body)
            c.put(15, hy - 3, body)
        # ojo
        if blink:
            c.rect(18, hy + 2, 19, hy + 2, dark)
        else:
            c.put(18, hy + 2, eye)
            c.put(19, hy + 2, eye)
            c.put(19, hy + 1, (255, 255, 255, 255)) if not cat else None
        # collar
        c.rect(14, hy + 6, 15, hy + 6, acc)
        c.put(15, hy + 7, acc)
    else:
        by = 13 + bob
        back = facing == "up"
        # cola (visible desde atras)
        if back:
            wag = (-1, 0, 1, 0)[t]
            if cat:
                c.rect(11 + wag, by - 5, 12 + wag, by + 1, body)
                c.put(11 + wag, by - 5, light)
            elif fox:
                c.blob(9 + wag, by - 1, 14 + wag, by + 5, body)
                c.rect(10 + wag, by + 3, 13 + wag, by + 5, light)
            else:
                c.rect(11 + wag, by - 2, 12 + wag, by + 3, body)
                c.put(11 + wag, by - 2, light)
        # patas
        for lx, off in ((8, lift), (14, -lift)):
            c.rect(lx, by + 3, lx + 1, 20 + min(0, off), body)
            c.rect(lx, 20 + min(0, off), lx + 1, 20 + min(0, off), light)
        # cuerpo
        c.blob(6, by, 17, by + 5 + breath, body)
        if not back:
            c.rect(10, by + 2, 13, by + 5 + breath, light)
        else:
            c.rect(11, by, 12, by + 5, dark)
        # cabeza
        hy = by - 6 + (1 if fox or cat else 0)
        c.blob(6, hy, 17, hy + 8, body)
        if s["ear"] == "floppy":
            c.rect(6, hy, 7, hy + 5, dark)
            c.rect(16, hy, 17, hy + 5, dark)
        else:
            for ex in (7, 15):
                c.rect(ex, hy - 3, ex + 1, hy, body)
                c.put(ex + (1 if ex == 7 else 0), hy - 4, body)
                if not back:
                    c.put(ex, hy - 2, dark)
        if not back:
            c.rect(9, hy + 5, 14, hy + 8, light if not cat else body)
            c.rect(11, hy + 5, 12, hy + 5, EYE)
            if raccoon:
                c.rect(7, hy + 2, 16, hy + 4, dark)
            if blink:
                c.rect(8, hy + 3, 9, hy + 3, dark)
                c.rect(14, hy + 3, 15, hy + 3, dark)
            else:
                c.rect(8, hy + 3, 9, hy + 3, eye)
                c.rect(14, hy + 3, 15, hy + 3, eye)
            c.rect(10, hy + 8, 13, hy + 8, acc)
        else:
            c.rect(10, hy + 8, 13, hy + 8, acc)
            c.rect(10, hy + 1, 13, hy + 1, dark)
            if raccoon:
                for sx in (10, 12):
                    c.rect(sx + wag_b(t), by - 1, sx + wag_b(t), by + 4, dark)
    return c.image()


def bird(sp, facing, state, t):
    s = {k: (hx(v) if k not in ("kind", "ear") else v) for k, v in sp.items()}
    c = Cv()
    body, dark, light, acc, eye, beak = s["body"], s["dark"], s["light"], s["accent"], s["eye"], s["beak"]
    hover = (0, -1, -2, -1)[t] if state == "idle" else (0, -2, 0, -2)[t]
    flap = (3, 1, -1, 1)[t] if state == "walk" else (2, 1, 0, 1)[t]   # alas
    y = 9 + hover
    if facing == "side":
        c.rect(4, y + 3, 8, y + 4, dark)                # cola
        c.rect(3, y + 4, 6, y + 4, body)
        c.blob(8, y + 1, 16, y + 7, body)               # cuerpo
        c.rect(9, y + 6, 15, y + 7, dark)
        c.blob(14, y - 2, 19, y + 3, body)              # cabeza
        c.rect(20, y, 22, y + 1, beak)
        c.put(22, y + 1, dark)
        c.put(17, y, eye)
        c.put(16, y + 2, acc)
        # ala
        wy = y + 1
        c.rect(8, wy - flap * 2, 13, wy - flap * 2 + 1, light)
        c.rect(7, wy - flap * 2 + 1, 12, wy - flap * 2 + 3 + (1 if flap < 1 else 0), body)
        c.rect(6, wy - flap * 2 + 3, 10, wy - flap * 2 + 3, dark)
        c.put(12, y + 8, dark)
        c.put(11, y + 8, dark)
    else:
        back = facing == "up"
        c.blob(9, y + 1, 14, y + 8, body)               # cuerpo
        c.rect(10, y + 6, 13, y + 8, dark)
        c.blob(9, y - 3, 14, y + 2, body)               # cabeza
        if not back:
            c.rect(11, y, 12, y + 2, beak)
            c.put(10, y - 1, eye)
            c.put(13, y - 1, eye)
            c.put(11, y + 4, acc)
            c.put(12, y + 4, acc)
        else:
            c.rect(10, y - 2, 13, y - 2, light)
            c.rect(11, y + 9, 12, y + 10, dark)         # cola
        # alas abiertas / plegadas segun cuadro
        wy = y + 2 - flap * 2
        c.rect(3 + (1 if flap < 1 else 0), wy, 8, wy + 2, body)
        c.rect(15, wy, 20 - (1 if flap < 1 else 0), wy + 2, body)
        c.rect(2 + (1 if flap < 1 else 0), wy, 5, wy, light)
        c.rect(18, wy, 21 - (1 if flap < 1 else 0), wy, light)
        c.rect(3 + (1 if flap < 1 else 0), wy + 2, 6, wy + 2, dark)
        c.rect(17, wy + 2, 20 - (1 if flap < 1 else 0), wy + 2, dark)
    return c.image(shadow_w=5 if hover < -1 else 7, shadow_a=45)


ROWS = [("idle", "down"), ("idle", "up"), ("idle", "side"), ("walk", "down"), ("walk", "up"), ("walk", "side")]


def make(pid):
    sp = SPECIES[pid]
    sheet = Image.new("RGBA", (W * 4, H * len(ROWS)), (0, 0, 0, 0))
    fn = bird if sp["kind"] == "bird" else quad
    for r, (state, facing) in enumerate(ROWS):
        for t in range(4):
            sheet.paste(fn(sp, facing, state, t), (t * W, r * H))
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    sheets = {}
    for pid in SPECIES:
        sheets[pid] = make(pid)
        sheets[pid].save(os.path.join(OUT, f"pet_{pid}.png"))
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        k = 4
        prev = Image.new("RGBA", (W * 4 * k, H * 6 * k * len(sheets) // 2 if False else H * 6 * k), (60, 70, 60, 255))
        # 4 hojas en rejilla 2x2
        prev = Image.new("RGBA", (W * 4 * k * 2, H * 6 * k * 2), (60, 70, 60, 255))
        for i, (pid, im) in enumerate(sheets.items()):
            big = im.resize((im.width * k, im.height * k), Image.NEAREST)
            prev.alpha_composite(big, ((i % 2) * W * 4 * k, (i // 2) * H * 6 * k))
        prev.save(path)


if __name__ == "__main__":
    main()
