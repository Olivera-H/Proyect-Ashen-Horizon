#!/usr/bin/env python3
"""Genera el atlas de terreno de Ashen Horizon: assets/world/terrain.png

Uso:  python3 tools/gen_terrain.py                   (escribe el atlas)
      python3 tools/gen_terrain.py --preview DIR     (ademas guarda vistas ampliadas)

Requiere Pillow (pip install pillow). El PNG resultante ya esta en el repo: solo hace
falta ejecutar esto si quieres cambiar colores o formas. Tambien puedes abrirlo en
Aseprite y pintarlo a mano respetando la cuadricula de 16x16 y el orden de filas.

Atlas de 16 columnas x 5 filas (cada tile 16x16). Fila = familia, columna = variante:
  fila 0  asfalto   (0-3 base, 4-5 grietas, 6 parche, 7 bache, 8-9 manchas, 10-11 desgastado,
                     12 grava, 13-14 huella de neumaticos horizontal, 15 grieta larga)
  fila 1  acera     (0-3 base, 4-5 grietas, 6 hierba entre grietas, 7 musgo, 8 mancha,
                     9 esquina rota, 10 hojas secas, 11 hierba en la junta, 12 polvo,
                     13 dos losas, 14-15 base)
  fila 2  cesped    5 niveles de sequedad x 3 variantes (0-2 exuberante ... 12-14 ceniza)
  fila 3  cesped decorado (0-3 flores, 4-6 hierba alta, 7-9 hierba seca alta, 10-11 tierra
                     pisada, 12 tierra con piedras, 13 hojarasca, 14 trebol, 15 charco)
  fila 4  tierra industrial (0-3 base, 4-5 guijarros, 6-7 aceite, 8-9 barro agrietado,
                     10 charco, 11-12 huellas, 13 hollin, 14 chatarra, 15 grava)
  fila 5  escombros sobre asfalto (0-7 montones densos para barricadas, 8-15 restos sueltos)
"""
import math
import os
import random
import sys

from PIL import Image

T = 16
COLS, ROWS = 16, 6
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "world")


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(c, d):
    """d > 0 aclara, d < 0 oscurece."""
    return tuple(max(0, min(255, c[i] + d)) for i in range(3))


class Tile:
    def __init__(self, base):
        self.p = [[base] * T for _ in range(T)]

    def put(self, x, y, c):
        if 0 <= x < T and 0 <= y < T:
            self.p[y][x] = c

    def get(self, x, y):
        return self.p[y][x]

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, c)

    def blend(self, x, y, c, a):
        if 0 <= x < T and 0 <= y < T:
            self.p[y][x] = mix(self.p[y][x], c, a)

    def speckles(self, rng, color, count, shapes=((1, 1, 70), (2, 1, 15), (1, 2, 10), (2, 2, 5)), margin=0):
        pool = []
        for w, h, wt in shapes:
            pool += [(w, h)] * wt
        for _ in range(count):
            w, h = rng.choice(pool)
            x = rng.randint(margin, T - 1 - margin)
            y = rng.randint(margin, T - 1 - margin)
            self.rect(x, y, w, h, color)

    def blob(self, rng, cx, cy, rx, ry, color, density=1.0, edge=0.55):
        """Mancha irregular con borde tramado (dither)."""
        for y in range(T):
            for x in range(T):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                wob = 1.0 + (rng.random() - 0.5) * 0.35
                if d * wob <= 1.0:
                    k = density if d < 0.55 else density * edge
                    if rng.random() < k:
                        self.put(x, y, color)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def crack(self, rng, x, y, length, dark, light=None, heading=None, branch=0.18):
        dirs = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
        h = rng.randrange(8) if heading is None else heading
        for _ in range(length):
            self.put(x, y, dark)
            if light is not None:
                self.blend(x + 1, y + 1, light, 0.55)
            if rng.random() < 0.4:
                h = (h + rng.choice((-1, 1))) % 8
            dx, dy = dirs[h]
            x, y = x + dx, y + dy
            if not (0 <= x < T and 0 <= y < T):
                break
            if rng.random() < branch and length > 5:
                self.crack(rng, x, y, max(2, length // 3), dark, light, (h + rng.choice((-2, 2))) % 8, 0.0)

    def image(self):
        im = Image.new("RGBA", (T, T))
        for y in range(T):
            for x in range(T):
                im.putpixel((x, y), self.p[y][x] + (255,))
        return im


# ================================================================== asfalto

A_BASE = hx("2e3036")
A_DARK = hx("25272c")
A_DARK2 = hx("1e2024")
A_LIGHT = hx("3b3e45")
A_LIGHT2 = hx("474a52")
A_CRACK = hx("17181b")


def asphalt_base(rng, tone=0):
    t = Tile(shade(A_BASE, tone))
    t.speckles(rng, shade(A_DARK, tone), rng.randint(9, 13))
    t.speckles(rng, shade(A_LIGHT, tone), rng.randint(8, 12))
    t.speckles(rng, shade(A_LIGHT2, tone), rng.randint(2, 4), shapes=((1, 1, 100),))
    t.speckles(rng, shade(A_DARK2, tone), rng.randint(1, 3), shapes=((1, 1, 100),))
    return t


def asphalt_tile(i):
    rng = random.Random(1000 + i)
    if i <= 3:
        return asphalt_base(rng)
    if i in (4, 5, 15):
        t = asphalt_base(rng)
        if i == 15:
            t.crack(rng, 1, rng.randint(5, 10), 22, A_CRACK, A_LIGHT2, heading=1, branch=0.25)
        else:
            t.crack(rng, rng.randint(2, 6), rng.randint(2, 6), rng.randint(10, 14), A_CRACK, A_LIGHT2)
            if i == 5:
                t.crack(rng, rng.randint(9, 13), rng.randint(9, 13), 7, A_CRACK, A_LIGHT2)
        return t
    if i == 6:  # parche de reparacion
        t = asphalt_base(rng)
        x0, y0, w, h = 3, 4, 10, 7
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                t.put(x, y, mix(A_BASE, hx("202226"), 0.45))
        t.speckles(rng, A_DARK, 4, margin=4)
        for x in range(x0, x0 + w):
            if rng.random() < 0.8:
                t.blend(x, y0, A_CRACK, 0.7)
            if rng.random() < 0.7:
                t.blend(x, y0 + h - 1, A_LIGHT2, 0.35)
        for y in range(y0, y0 + h):
            if rng.random() < 0.8:
                t.blend(x0, y, A_CRACK, 0.7)
            if rng.random() < 0.7:
                t.blend(x0 + w - 1, y, A_LIGHT2, 0.35)
        return t
    if i == 7:  # bache
        t = asphalt_base(rng)
        t.blob(rng, 8, 8, 5.2, 4.0, hx("2a2c31"), 1.0, 0.8)
        t.blob(rng, 8.3, 8.4, 3.8, 2.8, hx("131417"), 1.0, 0.9)
        for x in range(3, 12):
            t.blend(x, 4, A_LIGHT2, 0.5)
        t.speckles(rng, hx("6b6d73"), 6, shapes=((1, 1, 100),), margin=2)
        t.crack(rng, 2, 11, 5, A_CRACK, None, heading=7, branch=0)
        return t
    if i in (8, 9):  # manchas de aceite / oscuras
        t = asphalt_base(rng)
        if i == 8:
            t.blob(rng, 8, 8, 5.0, 3.6, hx("1d1f23"), 0.9, 0.5)
            t.blob(rng, 7.5, 8.0, 2.6, 1.8, hx("171a1f"), 1.0, 0.7)
            for p in ((6, 7), (9, 8)):
                t.blend(p[0], p[1], hx("3e5a5a"), 0.5)
        else:
            t.blob(rng, 9, 6, 4.5, 4.5, hx("212328"), 0.85, 0.5)
            t.blob(rng, 6, 11, 3.0, 2.5, hx("212328"), 0.85, 0.5)
        return t
    if i in (10, 11):  # desgastado / pintura lavada
        t = asphalt_base(rng, tone=9)
        t.speckles(rng, shade(A_LIGHT2, 6), 8)
        return t
    if i == 12:  # grava y tierra
        t = asphalt_base(rng)
        cols = [hx("574c3c"), hx("6a5c48"), hx("4a4034")]
        for _ in range(26):
            x, y = rng.randint(0, 6), rng.randint(9, 15)
            t.put(x + rng.randint(0, 3), y, rng.choice(cols))
        t.speckles(rng, hx("7d7466"), 4, shapes=((1, 1, 100),), margin=0)
        return t
    if i in (13, 14):  # huella de neumaticos horizontal
        t = asphalt_base(rng)
        band = hx("282a2f")
        for y in (6, 7, 8):
            for x in range(T):
                if rng.random() < (0.92 if y == 7 else 0.55):
                    t.put(x, y, band)
        t.speckles(rng, A_LIGHT, 3, shapes=((1, 1, 100),), margin=0)
        return t
    return asphalt_base(rng)


# ================================================================== acera

S_BASE = hx("6e6e69")
S_DARK = hx("62625d")
S_LIGHT = hx("7b7b75")
S_JOINT = hx("4c4c48")
S_HI = hx("858580")
S_DIRT = hx("4a4237")


def sidewalk_base(rng, tone=0, slab=True):
    t = Tile(shade(S_BASE, tone))
    t.speckles(rng, shade(S_DARK, tone), rng.randint(9, 13))
    t.speckles(rng, shade(S_LIGHT, tone), rng.randint(8, 12))
    if slab:
        for x in range(T):
            t.put(x, 0, S_JOINT)
            t.put(x, 1, S_HI)
        for y in range(T):
            t.put(0, y, S_JOINT)
            t.put(1, y, S_HI)
        t.put(0, 0, shade(S_JOINT, -8))
        # esquina inferior derecha en sombra suave
        for k in range(2, T):
            t.blend(k, T - 1, S_DARK, 0.35)
            t.blend(T - 1, k, S_DARK, 0.35)
    return t


def sidewalk_tile(i):
    rng = random.Random(2000 + i)
    if i <= 3 or i in (14, 15):
        return sidewalk_base(rng, tone=rng.choice((-3, 0, 3)))
    if i in (4, 5):
        t = sidewalk_base(rng)
        t.crack(rng, rng.randint(3, 6), 2, 14, S_JOINT, S_HI, heading=3 if i == 4 else 2)
        return t
    if i == 6:  # hierba entre grietas
        t = sidewalk_base(rng)
        t.crack(rng, 4, 3, 11, S_JOINT, None, heading=3, branch=0)
        g = [hx("3e6a30"), hx("4f8a3c"), hx("2f5224")]
        for (x, y) in ((6, 6), (7, 7), (8, 8), (5, 5), (9, 9)):
            t.put(x, y, rng.choice(g))
            if rng.random() < 0.7:
                t.put(x + rng.choice((-1, 1)), y - 1, rng.choice(g))
        t.put(7, 5, g[1]); t.put(7, 4, g[1]); t.put(8, 6, g[2]); t.put(10, 8, g[1]); t.put(10, 7, g[0])
        return t
    if i == 7:  # musgo
        t = sidewalk_base(rng)
        moss = [hx("4a6a3a"), hx("3a5530"), hx("5a7a46")]
        for (cx, cy) in ((2, 13), (14, 12), (13, 3)):
            for y in range(T):
                for x in range(T):
                    d = (x - cx) ** 2 + (y - cy) ** 2
                    if d < 12 and rng.random() < (1.0 - d / 14.0) * 0.9:
                        t.put(x, y, rng.choice(moss))
        return t
    if i == 8:  # mancha humeda
        t = sidewalk_base(rng)
        t.blob(rng, 9, 9, 5.5, 4.2, hx("55554f"), 0.85, 0.5)
        t.blob(rng, 9, 9, 3.0, 2.2, hx("494944"), 0.9, 0.6)
        return t
    if i == 9:  # esquina rota
        t = sidewalk_base(rng)
        for (x, y) in ((11, 10), (12, 10), (13, 10), (14, 10), (15, 10), (10, 11), (11, 11), (12, 11), (13, 11), (14, 11), (15, 11),
                       (11, 12), (12, 12), (13, 12), (14, 12), (15, 12), (12, 13), (13, 13), (14, 13), (15, 13), (13, 14), (14, 14), (15, 14), (14, 15), (15, 15)):
            t.put(x, y, rng.choice((S_DIRT, shade(S_DIRT, -8), shade(S_DIRT, 10))))
        for (x, y) in ((10, 10), (9, 11), (10, 12), (11, 13), (12, 14), (13, 15)):
            t.put(x, y, S_JOINT)
        t.speckles(rng, hx("8a8a84"), 3, shapes=((1, 1, 100),), margin=2)
        return t
    if i == 10:  # hojas secas
        t = sidewalk_base(rng)
        leaf = [hx("7a5a30"), hx("8c6a38"), hx("5e4526"), hx("9a7a40")]
        for _ in range(11):
            x, y = rng.randint(2, 14), rng.randint(2, 14)
            c = rng.choice(leaf)
            t.put(x, y, c)
            if rng.random() < 0.6:
                t.put(x + 1, y, shade(c, -14))
        return t
    if i == 11:  # hierba en la junta
        t = sidewalk_base(rng)
        g = [hx("3e6a30"), hx("4f8a3c"), hx("2f5224"), hx("6aa04c")]
        for x in (3, 4, 8, 9, 12):
            h = rng.randint(2, 4)
            t.put(x, 1, g[2])
            for k in range(1, h):
                t.put(x, 1 + k, g[2] if k == 1 else rng.choice((g[0], g[1], g[3])))
        for x in (2, 5, 8, 13):
            t.put(x, 1, g[0])
        return t
    if i == 12:  # polvo
        t = sidewalk_base(rng)
        dust = hx("8d836e")
        for y in range(T):
            for x in range(T):
                if rng.random() < 0.16 * (1.0 + (x + y) / 18.0):
                    t.blend(x, y, dust, 0.55)
        return t
    if i == 13:  # dos losas (junta vertical)
        t = sidewalk_base(rng)
        for y in range(2, T):
            t.put(8, y, S_JOINT)
            t.put(9, y, S_HI)
        return t
    return sidewalk_base(rng)


# ================================================================== cesped

TIERS = [
    # base, oscuro, claro, punta
    (hx("3a6a2c"), hx("2a5222"), hx("58903e"), hx("78b050")),   # 0 exuberante
    (hx("3d5a2e"), hx("2b4522"), hx("4c7a38"), hx("6a9a48")),   # 1 normal
    (hx("52602f"), hx("3e4c25"), hx("6f7e3e"), hx("8e9c52")),   # 2 semiseco
    (hx("68642f"), hx("504c25"), hx("867c3e"), hx("a89850")),   # 3 seco
    (hx("55593f"), hx("434734"), hx("686c52"), hx("7e8466")),   # 4 ceniza
]


def blade(t, x, y, tier, rng, tall=2):
    base, dark, light, tip = TIERS[tier]
    for k in range(tall):
        c = tip if k == tall - 1 else (light if k == tall - 2 else dark)
        t.put(x, y - k, c)
    if rng.random() < 0.5:
        t.put(x + rng.choice((-1, 1)), y - tall + 1, light)


def grass_base(rng, tier, kind):
    base, dark, light, tip = TIERS[tier]
    t = Tile(base)
    t.speckles(rng, mix(base, dark, 0.45), rng.randint(14, 20), shapes=((1, 1, 60), (2, 1, 25), (1, 2, 10), (2, 2, 5)))
    if kind == 0:
        for _ in range(rng.randint(3, 4)):
            x, y = rng.randint(1, 13), rng.randint(1, 13)
            t.rect(x, y, 2, 2, dark)
            t.put(x + 1, y - 1, light)
        for _ in range(rng.randint(5, 7)):
            blade(t, rng.randint(1, 14), rng.randint(2, 14), tier, rng, 2)
    elif kind == 1:
        for _ in range(rng.randint(8, 11)):
            blade(t, rng.randint(1, 14), rng.randint(2, 14), tier, rng, rng.choice((2, 2, 3)))
        t.speckles(rng, dark, 4, shapes=((1, 1, 100),))
    else:
        for _ in range(rng.randint(3, 5)):
            blade(t, rng.randint(1, 14), rng.randint(2, 14), tier, rng, 2)
        t.speckles(rng, mix(base, hx("6b5238"), 0.5), 3, shapes=((1, 1, 70), (2, 1, 30)))
        t.speckles(rng, light, 5, shapes=((1, 1, 100),))
    return t


def tuft(t, x, y, tier, rng, n=3, tall=4):
    """Mata de hierba alta con base ancha."""
    base, dark, light, tip = TIERS[tier]
    nb = n + 2
    for k in range(nb):
        off = k - nb // 2
        bx = x + off
        h = tall - abs(off) // 2 - rng.randint(0, 1)
        h = max(2, h)
        lean = 0 if off == 0 else (1 if off > 0 else -1)
        for j in range(h):
            c = tip if j == h - 1 else (light if j >= h - 2 else dark)
            t.put(bx + (lean if j >= h - 2 else 0), y - j, c)
    t.put(x - 1, y + 1, dark)
    t.put(x, y + 1, dark)
    t.put(x + 1, y + 1, dark)


def grass_deco_tile(i):
    rng = random.Random(3000 + i)
    if i <= 3:  # flores
        t = grass_base(rng, 1, rng.choice((0, 2)))
        pal = [(hx("e8e6d2"), hx("f6d84a")), (hx("f6d84a"), hx("ffffff")), (hx("b894d6"), hx("e6d0f0")), (hx("e06a6a"), hx("f6a0a0"))][i]
        for _ in range(rng.randint(5, 7)):
            x, y = rng.randint(1, 14), rng.randint(2, 14)
            t.put(x, y, pal[0])
            if rng.random() < 0.5:
                t.put(x, y + 1, TIERS[1][1])
            if rng.random() < 0.35:
                t.put(x + 1, y, pal[1])
        return t
    if i in (4, 5, 6):
        t = grass_base(rng, 1, 2)
        for (x, y) in ((4, 12), (11, 9), (7, 5))[: 2 + (i % 2)]:
            tuft(t, x + rng.randint(-1, 1), y, 1, rng, 3, 5)
        return t
    if i in (7, 8, 9):
        t = grass_base(rng, 3 if i != 9 else 2, 1)
        for (x, y) in ((5, 11), (11, 12), (8, 6))[: 2 + (i % 2)]:
            tuft(t, x + rng.randint(-1, 1), y, 3 if i != 9 else 2, rng, 3, 4)
        return t
    if i in (10, 11):  # tierra pisada
        t = grass_base(rng, 1, 0)
        dirt = [hx("6b5238"), hx("5a4430"), hx("7c6244")]
        cx, cy = rng.choice((6, 9)), rng.choice((7, 9))
        for y in range(T):
            for x in range(T):
                dx, dy = (x - cx) / 6.0, (y - cy) / 4.6
                d = dx * dx + dy * dy
                if d < 1.0 and rng.random() < (1.0 if d < 0.5 else 0.5):
                    t.put(x, y, rng.choice(dirt))
        t.speckles(rng, hx("8a7a62"), 3, shapes=((1, 1, 100),), margin=4)
        return t
    if i == 12:
        t = grass_base(rng, 2, 2)
        for _ in range(7):
            x, y = rng.randint(2, 13), rng.randint(3, 13)
            t.put(x, y, hx("8a8a84"))
            t.put(x, y + 1, hx("55554f"))
            if rng.random() < 0.4:
                t.put(x + 1, y, hx("a2a29a"))
        return t
    if i == 13:  # hojarasca
        t = grass_base(rng, 3, 2)
        leaf = [hx("7a5a30"), hx("8c6a38"), hx("5e4526"), hx("9a7a40")]
        for _ in range(13):
            x, y = rng.randint(1, 14), rng.randint(1, 14)
            c = rng.choice(leaf)
            t.put(x, y, c)
            t.put(x + 1, y, shade(c, -16))
        return t
    if i == 14:  # trebol
        t = grass_base(rng, 0, 2)
        for _ in range(7):
            x, y = rng.randint(1, 13), rng.randint(1, 13)
            t.put(x, y, hx("78b050"))
            t.put(x + 1, y, hx("78b050"))
            t.put(x, y + 1, hx("58903e"))
            t.put(x + 1, y + 1, hx("78b050"))
        return t
    if i == 15:  # charco
        t = grass_base(rng, 1, 0)
        t.blob(rng, 8, 9, 5.5, 3.6, hx("4a4636"), 1.0, 0.6)
        t.blob(rng, 8, 9, 4.2, 2.6, hx("3a4a52"), 1.0, 0.9)
        for p in ((6, 8), (7, 8), (10, 10)):
            t.put(p[0], p[1], hx("6a7e88"))
        return t
    return grass_base(rng, 1, 0)


# ================================================================== tierra

D_BASE = hx("6b5238")
D_DARK = hx("574330")
D_DARK2 = hx("473625")
D_LIGHT = hx("7e6244")
D_LIGHT2 = hx("927456")


def dirt_base(rng):
    t = Tile(D_BASE)
    t.speckles(rng, D_DARK, rng.randint(12, 16))
    t.speckles(rng, D_LIGHT, rng.randint(9, 12))
    t.speckles(rng, D_LIGHT2, rng.randint(2, 4), shapes=((1, 1, 100),))
    t.speckles(rng, D_DARK2, rng.randint(2, 4), shapes=((1, 1, 100),))
    return t


def dirt_tile(i):
    rng = random.Random(4000 + i)
    if i <= 3:
        return dirt_base(rng)
    if i in (4, 5):  # guijarros
        t = dirt_base(rng)
        for _ in range(rng.randint(5, 8)):
            x, y = rng.randint(1, 13), rng.randint(1, 13)
            t.put(x, y, hx("a0968a"))
            t.put(x + 1, y, hx("8a8176"))
            t.put(x, y + 1, hx("6a6258"))
            t.put(x + 1, y + 1, hx("5a534a"))
        return t
    if i in (6, 7):  # aceite
        t = dirt_base(rng)
        t.blob(rng, 8, 8, 5.4, 4.0, hx("2d2620"), 0.95, 0.55)
        t.blob(rng, 8, 8, 3.0, 2.0, hx("1c1814"), 1.0, 0.8)
        t.blend(7, 7, hx("46605e"), 0.6)
        t.blend(9, 8, hx("5a4a66"), 0.5)
        return t
    if i in (8, 9):  # barro agrietado
        t = dirt_base(rng)
        for _ in range(3):
            t.crack(rng, rng.randint(2, 13), rng.randint(2, 13), rng.randint(6, 9), hx("3a2c1e"), hx("8a6c4c"))
        return t
    if i == 10:  # charco
        t = dirt_base(rng)
        t.blob(rng, 8, 8, 6.0, 4.2, hx("3e3226"), 1.0, 0.6)
        t.blob(rng, 8, 8, 4.6, 3.0, hx("4a5258"), 1.0, 0.9)
        for p in ((6, 7), (7, 7), (11, 9)):
            t.put(p[0], p[1], hx("76868e"))
        return t
    if i in (11, 12):  # huellas
        t = dirt_base(rng)
        dy = 0 if i == 11 else 1
        for y in (3 + dy, 4 + dy, 10 + dy, 11 + dy):
            for x in range(T):
                if rng.random() < 0.9:
                    t.put(x, y, D_DARK2 if y in (3 + dy, 10 + dy) else D_DARK)
        return t
    if i == 13:  # hollin
        t = dirt_base(rng)
        t.blob(rng, 8, 8, 6.2, 5.0, hx("2a2622"), 0.9, 0.5)
        t.blob(rng, 7, 9, 3.4, 2.6, hx("1c1a17"), 0.95, 0.7)
        return t
    if i == 14:  # chatarra
        t = dirt_base(rng)
        t.rect(4, 7, 7, 3, hx("6e7076"))
        t.rect(4, 7, 7, 1, hx("9a9ca3"))
        t.rect(4, 9, 7, 1, hx("4a4c52"))
        t.rect(7, 6, 2, 1, hx("8a4a2a"))
        t.rect(10, 9, 3, 2, hx("8a4a2a"))
        t.speckles(rng, hx("a85a32"), 2, shapes=((1, 1, 100),), margin=3)
        return t
    t = dirt_base(rng)
    for _ in range(40):
        x, y = rng.randint(0, 15), rng.randint(0, 15)
        t.put(x, y, rng.choice((hx("8a8780"), hx("6a6862"), hx("a09c92"), hx("54524c"))))
    return t


def grass_tile(i):
    if i < 15:
        tier, kind = divmod(i, 3)
        return grass_base(random.Random(5000 + i), tier, kind)
    return grass_base(random.Random(5000 + i), 1, 0)


# ================================================================== escombros

C_CON = hx("6e6c68")
C_CON_L = hx("9a9792")
C_CON_D = hx("46443f")
C_REBAR = hx("8a4a28")


def chunk(t, rng, cx, cy, r, tone=0):
    """Trozo de concreto: poligono irregular con luz arriba-izquierda y sombra abajo-derecha."""
    n = rng.randint(5, 7)
    pts = []
    for k in range(n):
        a = k / n * 6.2832 + rng.random() * 0.5
        rr = r * (0.65 + rng.random() * 0.5)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.8))

    def inside(x, y):
        c = False
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
                c = not c
            j = i
        return c

    cells = set()
    for y in range(T):
        for x in range(T):
            if inside(x + 0.5, y + 0.5):
                cells.add((x, y))
    base = shade(C_CON, tone + rng.randint(-8, 8))
    for (x, y) in cells:
        t.put(x, y, base)
    for (x, y) in cells:
        if (x - 1, y) not in cells or (x, y - 1) not in cells:
            t.put(x, y, shade(C_CON_L, tone))
        elif (x + 1, y) not in cells or (x, y + 1) not in cells:
            t.put(x, y, shade(C_CON_D, tone))
    for (x, y) in cells:                       # sombra proyectada
        if (x + 1, y + 1) not in cells and 0 <= x + 1 < T and 0 <= y + 1 < T and rng.random() < 0.8:
            t.blend(x + 1, y + 1, A_DARK2, 0.7)
    if cells and rng.random() < 0.6:
        x, y = rng.choice(sorted(cells))
        t.put(x, y, C_CON_D)
    return cells


def rubble_tile(i):
    rng = random.Random(9000 + i)
    t = asphalt_base(rng, -4)
    if i < 8:
        for _ in range(rng.randint(5, 7)):
            chunk(t, rng, rng.randint(1, 14), rng.randint(2, 14), rng.randint(3, 5))
        if rng.random() < 0.7:                  # varilla oxidada
            x, y = rng.randint(1, 9), rng.randint(2, 12)
            t.line(x, y, x + rng.randint(4, 6), y + rng.randint(-3, 3), C_REBAR)
            t.put(x, y, shade(C_REBAR, 40))
        t.speckles(rng, hx("a79d88"), rng.randint(4, 7), shapes=((1, 1, 100),))
    else:
        for _ in range(rng.randint(1, 3)):
            chunk(t, rng, rng.randint(2, 13), rng.randint(3, 13), rng.randint(2, 3))
        t.speckles(rng, hx("8a8478"), rng.randint(6, 10), shapes=((1, 1, 80), (2, 1, 20)))
        t.speckles(rng, hx("a79d88"), rng.randint(2, 4), shapes=((1, 1, 100),))
    return t


def build_atlas():
    atlas = Image.new("RGBA", (COLS * T, ROWS * T), (0, 0, 0, 0))
    makers = [asphalt_tile, sidewalk_tile, grass_tile, grass_deco_tile, dirt_tile, rubble_tile]
    for r, make in enumerate(makers):
        for c in range(COLS):
            atlas.paste(make(c).image(), (c * T, r * T))
    return atlas


def preview(atlas, outdir):
    os.makedirs(outdir, exist_ok=True)
    big = atlas.resize((atlas.width * 5, atlas.height * 5), Image.NEAREST)
    big.save(os.path.join(outdir, "terrain_atlas.png"))
    # mosaico de prueba: 24x12 tiles mezclando familias para juzgar costuras
    rng = random.Random(7)
    W, H = 30, 14
    sheet = Image.new("RGBA", (W * T, H * T))

    def tile_at(row, col):
        return atlas.crop((col * T, row * T, col * T + T, row * T + T))

    for y in range(H):
        for x in range(W):
            if 5 <= y <= 6 or 9 <= y <= 12 and False:
                pass
            if y in (4, 11):
                im = tile_at(1, rng.choice([0, 1, 2, 3, 3, 14, 15, 4, 6, 7, 10, 11, 12, 13, 8, 9]))
            elif 5 <= y <= 10:
                im = tile_at(0, rng.choice([0, 1, 2, 3, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]))
            elif y < 4:
                n = (x + y * 2) % 15
                im = tile_at(2, min(14, (x // 6) * 3 + rng.randint(0, 2))) if rng.random() < 0.85 else tile_at(3, rng.randint(0, 15))
            else:
                im = tile_at(2, min(14, ((W - x) // 8) * 3 + rng.randint(0, 2))) if rng.random() < 0.8 else tile_at(3, rng.randint(0, 15))
            sheet.paste(im, (x * T, y * T))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(os.path.join(outdir, "terrain_mosaic.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    atlas = build_atlas()
    atlas.save(os.path.join(OUT, "terrain.png"))
    print("terrain.png", atlas.size)
    if "--preview" in sys.argv:
        preview(atlas, sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
