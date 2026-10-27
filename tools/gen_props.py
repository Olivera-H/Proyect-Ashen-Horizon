#!/usr/bin/env python3
"""Genera los objetos de calle de Ashen Horizon: assets/world/props/*.png

Uso:  python3 tools/gen_props.py                  (escribe los PNG)
      python3 tools/gen_props.py --preview DIR    (ademas guarda una hoja de contacto ampliada)

Requiere Pillow. Los PNG ya estan en el repo; ejecuta esto solo si quieres cambiar formas o
colores (tambien puedes repintarlos a mano: el juego solo necesita que el nombre del archivo
coincida con el de StreetProps.KINDS en scripts/street_props.gd).

Cada sprite se apoya en el suelo por el centro de su borde inferior. Todos llevan contorno
oscuro, luz desde arriba-izquierda y una sombra suave en la base.
Variantes encendidas: traffic_light_front_amber / _red y street_lamp_lit.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "assets", "world", "props")
OUTLINE = (22, 17, 30, 255)
NONE = (0, 0, 0, 0)


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def lighten(c, d):
    return (max(0, min(255, c[0] + d)), max(0, min(255, c[1] + d)), max(0, min(255, c[2] + d)), c[3])


def new(w, h):
    return Image.new("RGBA", (w, h), NONE)


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def opaque(img, x, y):
    return 0 <= x < img.width and 0 <= y < img.height and img.getpixel((x, y))[3] > 200


def rim_light(img, up=26, down=30):
    """Aclara los bordes que miran arriba-izquierda y oscurece los de abajo-derecha."""
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            c = src.getpixel((x, y))
            if c[3] < 200:
                continue
            if not opaque(src, x - 1, y - 1) or not opaque(src, x, y - 1) or not opaque(src, x - 1, y):
                img.putpixel((x, y), lighten(c, up))
            elif not opaque(src, x + 1, y + 1) or not opaque(src, x, y + 1) or not opaque(src, x + 1, y):
                img.putpixel((x, y), lighten(c, -down))


def outline(img, col=OUTLINE):
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if opaque(src, x + dx, y + dy):
                    img.putpixel((x, y), col)
                    break


def shadow_layer(w, h, cx, cy, rx, ry, a=70):
    s = new(w, h)
    d = ImageDraw.Draw(s)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(10, 8, 16, a))
    return s


def finish(obj, shadow=None, rim=True):
    if rim:
        rim_light(obj)
    outline(obj)
    if shadow is None:
        return obj
    out = shadow.copy()
    out.alpha_composite(obj)
    return out


def save(name, img):
    os.makedirs(OUT_DIR, exist_ok=True)
    img.save(os.path.join(OUT_DIR, name + ".png"))


# ------------------------------------------------------------------ fuente 3x5
FONT = {
    "A": "010101111101101", "D": "110101101101110", "E": "111100110100111",
    "H": "101101111101101", "I": "111010010010111", "L": "100100100100111",
    "N": "111101101101101", "O": "111101101101111", "R": "110101110101101",
    "S": "111100111001111", "T": "111010010010010", "U": "101101101101111",
    "Z": "111001010100111", "0": "111101101101111", "6": "111100111101111",
    "8": "111101111101111", " ": "000000000000000",
    "P": "111101111100100", "C": "111100100100111", "J": "001001001101111", "M": "101111111101101",
    "B": "110101110101110", "K": "101101110101101", "G": "111100101101111", "V": "101101101101010",
    "F": "111100110100100", "Y": "101101010010010", "X": "101101010101101", "W": "101101111111101",
    "1": "010110010010111", "2": "111001111100111", "3": "111001111001111", "4": "101101111001001",
    "5": "111100111001111", "7": "111001001010010", "9": "111101111001111",
}


def text(img, x, y, s, col, gap=1):
    for ch in s:
        g = FONT[ch]
        for i, v in enumerate(g):
            if v == "1":
                px(img, x + i % 3, y + i // 3, col)
        x += 3 + gap
    return x


def text_w(s, gap=1):
    return len(s) * (3 + gap) - gap


# ------------------------------------------------------------------ postes y senales
POLE = hx("#6b6f78")
POLE_D = hx("#4a4d55")
POLE_L = hx("#9aa0aa")


def pole(d, x, y0, y1, w=2):
    rect(d, x, y0, x + w - 1, y1, POLE)
    rect(d, x + w - 1, y0, x + w - 1, y1, POLE_D)
    rect(d, x, y0, x, y1, POLE_L)


def base_plate(d, cx, y):
    rect(d, cx - 3, y - 1, cx + 2, y, POLE_D)


def traffic_light(lit=None, back=False):
    """16x34. Caja con tres luces (rojo, ambar, verde). lit: None / 'amber' / 'red'."""
    w, h = 16, 34
    o = new(w, h)
    d = ImageDraw.Draw(o)
    pole(d, 7, 17, h - 2)
    base_plate(d, 8, h - 1)
    box = hx("#2c2e35") if not back else hx("#34363e")
    rect(d, 4, 1, 11, 17, box)
    rect(d, 5, 2, 5, 16, lighten(box, 14))
    rect(d, 10, 2, 10, 16, lighten(box, -10))
    # visera / tornillos
    rect(d, 3, 1, 3, 3, POLE_D)
    rect(d, 12, 1, 12, 3, POLE_D)
    if back:
        rect(d, 6, 4, 9, 4, lighten(box, 18))
        rect(d, 6, 9, 9, 9, lighten(box, 18))
        rect(d, 6, 14, 9, 14, lighten(box, 18))
        px(o, 7, 6, hx("#3d4048"))
        px(o, 8, 11, hx("#3d4048"))
    else:
        cols = {
            0: (hx("#7a1d18"), hx("#ff4a3a"), "red"),
            1: (hx("#7a5a14"), hx("#ffc23a"), "amber"),
            2: (hx("#1d4a22"), hx("#58e060"), "green"),
        }
        for i in range(3):
            y = 2 + i * 5
            dark, bright, name = cols[i]
            on = lit == name
            c = bright if on else dark
            rect(d, 6, y, 9, y + 3, c)
            if on:
                px(o, 6, y, lighten(c, 70))
                px(o, 7, y, lighten(c, 40))
                rect(d, 5, y + 1, 5, y + 2, lighten(c, -50))
                rect(d, 10, y + 1, 10, y + 2, lighten(c, -50))
            else:
                px(o, 6, y, lighten(c, 30))
                px(o, 9, y + 3, lighten(c, -30))
        # visera encima de cada luz
        for i in range(3):
            rect(d, 5, 1 + i * 5, 10, 1 + i * 5, hx("#1b1c22"))
    return finish(o, shadow_layer(w, h, 8, h - 2, 6, 2), rim=False)


def stop_sign():
    w, h = 16, 30
    o = new(w, h)
    d = ImageDraw.Draw(o)
    pole(d, 7, 14, h - 2)
    base_plate(d, 8, h - 1)
    red = hx("#b3261e")
    pts = [(5, 0), (10, 0), (15, 5), (15, 10), (10, 15), (5, 15), (0, 10), (0, 5)]
    d.polygon(pts, fill=hx("#e8e4da"))
    inner = [(5.5, 2), (9.5, 2), (13, 5.5), (13, 9.5), (9.5, 13), (5.5, 13), (2, 9.5), (2, 5.5)]
    d.polygon(inner, fill=red)
    # letrero PARE abstracto: barra blanca con huecos de letras
    rect(d, 3, 6, 12, 9, hx("#f2eee4"))
    for x in (5, 8, 11):
        rect(d, x, 7, x, 8, red)
    px(o, 3, 3, lighten(red, 40))
    px(o, 4, 3, lighten(red, 40))
    # desgaste
    for (x, y) in [(11, 4), (12, 11), (4, 12), (9, 13)]:
        px(o, x, y, lighten(red, -35))
    return finish(o, shadow_layer(w, h, 8, h - 2, 6, 2), rim=False)


def speed_sign(num):
    w, h = 16, 30
    o = new(w, h)
    d = ImageDraw.Draw(o)
    pole(d, 7, 13, h - 2)
    base_plate(d, 8, h - 1)
    d.ellipse([1, 0, 14, 13], fill=hx("#c2271e"))
    d.ellipse([3, 2, 12, 11], fill=hx("#ece8de"))
    text(o, 5, 4, num, hx("#1d1a22"))
    for (x, y) in [(2, 4), (13, 8), (6, 1)]:
        px(o, x, y, hx("#8c1c16"))
    return finish(o, shadow_layer(w, h, 8, h - 2, 6, 2), rim=False)


def warning_ped():
    w, h = 18, 32
    o = new(w, h)
    d = ImageDraw.Draw(o)
    pole(d, 8, 16, h - 2)
    base_plate(d, 9, h - 1)
    yel = hx("#e0b92a")
    d.polygon([(9, 0), (17, 8), (9, 16), (1, 8)], fill=hx("#1d1a22"))
    d.polygon([(9, 2), (15, 8), (9, 14), (3, 8)], fill=yel)
    # peaton
    blk = hx("#1d1a22")
    px(o, 9, 5, blk)
    rect(d, 9, 6, 9, 9, blk)
    px(o, 8, 7, blk)
    px(o, 10, 7, blk)
    px(o, 8, 10, blk)
    px(o, 10, 10, blk)
    px(o, 7, 8, blk)
    for (x, y) in [(13, 8), (5, 6)]:
        px(o, x, y, lighten(yel, -45))
    return finish(o, shadow_layer(w, h, 9, h - 2, 6, 2), rim=False)


def guide_sign(label):
    w, h = 48, 40
    o = new(w, h)
    d = ImageDraw.Draw(o)
    pole(d, 7, 16, h - 2)
    pole(d, 39, 16, h - 2)
    base_plate(d, 8, h - 1)
    base_plate(d, 40, h - 1)
    green = hx("#1f6b45")
    rect(d, 1, 0, 46, 17, hx("#e6e2d6"))
    rect(d, 2, 1, 45, 16, green)
    rect(d, 2, 1, 45, 1, lighten(green, 20))
    tw = text_w(label)
    text(o, 2 + (44 - tw) // 2, 4, label, hx("#f2eee4"))
    # flecha y raya
    rect(d, 6, 12, 41, 12, hx("#e6e2d6"))
    d.polygon([(43, 12), (40, 10), (40, 14)], fill=hx("#e6e2d6"))
    for (x, y) in [(10, 14), (30, 15), (44, 3), (3, 15)]:
        px(o, x, y, lighten(green, -22))
    # barra de refuerzo
    rect(d, 7, 18, 40, 18, POLE_D)
    return finish(o, shadow_layer(w, h, 24, h - 2, 22, 2), rim=False)


def street_lamp(lit=False):
    w, h = 24, 46
    o = new(w, h)
    d = ImageDraw.Draw(o)
    pole(d, 11, 8, h - 2)
    base_plate(d, 12, h - 1)
    rect(d, 10, h - 6, 13, h - 3, POLE_D)
    rect(d, 10, h - 6, 10, h - 3, POLE)
    # cabeza
    rect(d, 7, 3, 16, 7, hx("#3a3d46"))
    rect(d, 6, 2, 17, 3, hx("#4a4d55"))
    rect(d, 7, 2, 12, 2, POLE_L)
    glass = hx("#fff0a8") if lit else hx("#5a5f66")
    rect(d, 8, 6, 15, 8, glass)
    if lit:
        rect(d, 9, 7, 14, 8, hx("#ffe58a"))
        px(o, 8, 6, hx("#ffffff"))
    else:
        px(o, 8, 6, hx("#7f858c"))
        px(o, 14, 8, hx("#40444a"))
    rect(d, 7, 8, 16, 8, hx("#2c2e35") if not lit else hx("#fff0a8"))
    rect(d, 7, 9, 16, 9, hx("#2c2e35"))
    img = finish(o, shadow_layer(w, h, 12, h - 2, 6, 2), rim=False)
    if lit:
        # halo en pixeles bajo la lampara
        for (x, y, a) in [(7, 10, 90), (8, 11, 70), (9, 12, 50), (14, 10, 90), (15, 11, 70), (13, 12, 50), (11, 10, 90)]:
            px(img, x, y, (255, 230, 140, a))
    return img


# ------------------------------------------------------------------ mobiliario
def hydrant():
    w, h = 12, 15
    o = new(w, h)
    d = ImageDraw.Draw(o)
    red = hx("#a8362a")
    rect(d, 3, 4, 8, 12, red)
    rect(d, 2, 3, 9, 4, lighten(red, -10))
    rect(d, 4, 1, 7, 3, red)
    rect(d, 3, 11, 8, 13, lighten(red, -25))
    rect(d, 1, 6, 2, 8, lighten(red, -10))
    rect(d, 9, 6, 10, 8, lighten(red, -10))
    px(o, 5, 0, lighten(red, 30))
    rect(d, 4, 5, 4, 10, lighten(red, 30))
    for (x, y) in [(7, 8), (6, 6), (3, 12)]:
        px(o, x, y, hx("#6a4a2a"))
    return finish(o, shadow_layer(w, h, 6, h - 2, 5, 2))


def trash_can():
    w, h = 14, 17
    o = new(w, h)
    d = ImageDraw.Draw(o)
    metal = hx("#59675f")
    rect(d, 3, 4, 10, 15, metal)
    rect(d, 2, 3, 11, 4, lighten(metal, 20))
    rect(d, 3, 2, 10, 2, lighten(metal, 36))
    for x in (5, 7, 9):
        rect(d, x, 6, x, 14, lighten(metal, -22))
    rect(d, 3, 6, 3, 14, lighten(metal, 16))
    # basura que se desborda
    for (x, y, c) in [(4, 1, "#b8b0a0"), (6, 0, "#8a7a5a"), (8, 1, "#9aa08c"), (9, 0, "#c0b8a8")]:
        px(o, x, y, hx(c))
    for (x, y) in [(8, 10), (5, 12)]:
        px(o, x, y, hx("#7a4a2a"))
    return finish(o, shadow_layer(w, h, 7, h - 2, 6, 2))


def cone():
    w, h = 10, 12
    o = new(w, h)
    d = ImageDraw.Draw(o)
    org = hx("#e07a1c")
    rect(d, 1, 9, 8, 10, hx("#3a3a42"))
    d.polygon([(4, 1), (5, 1), (8, 9), (1, 9)], fill=org)
    rect(d, 3, 4, 6, 5, hx("#e9e5da"))
    rect(d, 2, 7, 7, 7, hx("#e9e5da"))
    px(o, 4, 2, lighten(org, 40))
    px(o, 3, 6, lighten(org, 30))
    px(o, 7, 8, lighten(org, -40))
    return finish(o, shadow_layer(w, h, 5, h - 2, 4, 1, 60), rim=False)


def manhole():
    s = 16
    o = new(s, s)
    d = ImageDraw.Draw(o)
    d.ellipse([1, 1, 14, 14], fill=hx("#2a2a30"))
    d.ellipse([2, 2, 13, 13], fill=hx("#4b4d54"))
    d.ellipse([3, 3, 12, 12], fill=hx("#3b3d44"))
    for k in (5, 7, 9):
        rect(d, 4, k, 11, k, hx("#2e3036"))
        rect(d, 4, k + 1, 11, k + 1, hx("#55575f"))
    px(o, 4, 4, hx("#6a6c74"))
    px(o, 11, 11, hx("#202228"))
    return o


# ------------------------------------------------------------------ autos
def car(kind, body, dark, seed):
    rnd = random.Random(seed)
    w, h = 48, 28
    o = new(w, h)
    d = ImageDraw.Draw(o)
    lo = lighten(body, -34)
    hi = lighten(body, 30)
    glass = hx("#46586a")
    glass_hi = hx("#7f96aa")
    van = kind == "van"
    wagon = kind == "wagon"
    # carroceria baja
    y_top = 13 if not van else 6
    rect(d, 2, y_top, 45, 22, body)
    rect(d, 2, 21, 45, 22, lo)
    rect(d, 2, y_top, 45, y_top, hi)
    rect(d, 1, 16, 1, 22, lo)     # paragolpes
    rect(d, 46, 17, 46, 22, lo)
    # cabina
    if not van:
        x0, x1 = (12, 35) if not wagon else (11, 40)
        d.polygon([(x0, 13), (x1 + 5, 13), (x1 + 1, 5), (x0 + 5, 5)], fill=body)
        rect(d, x0 + 5, 5, x1 + 1, 5, hi)
        d.polygon([(x0 + 3, 12), (x1 + 3, 12), (x1, 7), (x0 + 6, 7)], fill=glass)
        # montante central
        mx = (x0 + x1) // 2 + 1
        rect(d, mx, 7, mx + 1, 12, body)
        px(o, x0 + 7, 8, glass_hi)
        px(o, x0 + 8, 8, glass_hi)
        px(o, mx + 4, 8, glass_hi)
    else:
        rect(d, 2, 6, 33, 6, hi)
        rect(d, 34, 6, 45, 22, body)
        rect(d, 34, 6, 45, 6, hi)
        d.polygon([(36, 8), (44, 8), (45, 15), (36, 15)], fill=glass)
        px(o, 37, 9, glass_hi)
        px(o, 38, 9, glass_hi)
        rect(d, 33, 7, 33, 21, lo)
        rect(d, 17, 8, 17, 21, lo)
        rect(d, 18, 12, 24, 14, lighten(body, -12))
    # franja / detalles
    if kind == "taxi":
        rect(d, 2, 17, 45, 17, hx("#1d1a22"))
        for x in range(2, 46, 4):
            rect(d, x, 17, x + 1, 17, hx("#e9e5da"))
        rect(d, 21, 2, 28, 4, hx("#e9e5da"))
        rect(d, 22, 3, 27, 3, hx("#1d1a22"))
    # manijas y linea de puerta
    rect(d, (18 if not van else 22), y_top + 1, (18 if not van else 22), 21, lo)
    px(o, 20, y_top + 3, lighten(body, 55))
    px(o, 28, y_top + 3, lighten(body, 55))
    # luces
    rect(d, 44, 15 if not van else 16, 45, 17 if not van else 18, hx("#f2e6a0"))
    rect(d, 2, 15 if not van else 16, 3, 17 if not van else 18, hx("#8a1c1c"))
    # ruedas
    for cx in (11, 36):
        flat = (cx == 11 and rnd.random() < 0.3)
        r = 4
        d.ellipse([cx - r, 18 + (2 if flat else 0), cx + r, 26], fill=hx("#1d1c22"))
        d.ellipse([cx - 1, 20 + (2 if flat else 0), cx + 1, 24], fill=hx("#8a8d94"))
        px(o, cx - 2, 20 + (2 if flat else 0), hx("#4a4a52"))
    # danos: ventana rota, oxido, golpes, polvo
    for _ in range(rnd.randint(1, 2)):
        gx = rnd.randint(16, 32) if not van else rnd.randint(37, 42)
        gy = rnd.randint(7, 10) if not van else rnd.randint(9, 12)
        for k in range(3):
            px(o, gx + k, gy + (k % 2), glass_hi)
    for _ in range(rnd.randint(5, 9)):
        x = rnd.randint(3, 44)
        y = rnd.randint(y_top + 1, 21)
        if opaque(o, x, y) and o.getpixel((x, y)) not in (glass, glass_hi):
            px(o, x, y, rnd.choice([hx("#8a4f2c"), hx("#6a3d22"), lighten(body, -22)]))
    for x in range(3, 45):
        if rnd.random() < 0.35:
            px(o, x, 21, hx("#6b5a44"))
    # cap de polvo encima (semitransparente)
    dust = Image.new("RGBA", (w, h), (120, 100, 70, 0))
    for y in range(y_top, 23):
        for x in range(2, 46):
            if opaque(o, x, y) and rnd.random() < 0.12:
                dust.putpixel((x, y), (120, 100, 70, 60))
    o.alpha_composite(dust)
    return finish(o, shadow_layer(w, h, 24, h - 3, 22, 2, 80), rim=True)


# ------------------------------------------------------------------ vegetacion
def tree_dead(w, h, seed, base_x=None):
    rnd = random.Random(seed)
    o = new(w, h)
    d = ImageDraw.Draw(o)
    bark = hx("#5e4a40")
    bx = base_x if base_x is not None else w // 2
    by = h - 3

    def branch(x, y, ang, ln, th, depth):
        x2 = x + math.cos(ang) * ln
        y2 = y - math.sin(ang) * ln
        d.line([x, y, x2, y2], fill=bark, width=max(1, int(round(th))))
        if depth > 0:
            n = 2 if rnd.random() < 0.7 else 3
            for i in range(n):
                da = rnd.uniform(0.35, 0.85) * (1 if i % 2 == 0 else -1)
                branch(x2, y2, ang + da, ln * rnd.uniform(0.62, 0.8), th * 0.66, depth - 1)
        return

    # raices
    d.polygon([(bx - 5, by + 1), (bx - 2, by - 5), (bx + 2, by - 5), (bx + 5, by + 1)], fill=bark)
    d.line([bx - 6, by + 1, bx - 3, by - 2], fill=bark, width=1)
    d.line([bx + 6, by + 1, bx + 3, by - 2], fill=bark, width=1)
    # tronco
    trunk_h = h * 0.38
    d.polygon([(bx - 3, by - 3), (bx + 3, by - 3), (bx + 2, by - trunk_h), (bx - 2, by - trunk_h)], fill=bark)
    tx, ty = bx, by - trunk_h
    branch(tx, ty, math.pi / 2 + rnd.uniform(-0.15, 0.15), h * 0.28, 3.2, 4)
    branch(tx - 1, ty + 4, math.pi / 2 + 0.9, h * 0.22, 2.4, 3)
    branch(tx + 1, ty + 6, math.pi / 2 - 0.9, h * 0.2, 2.2, 3)
    # musgo, nudo y grietas
    for _ in range(7):
        y = rnd.randint(int(by - trunk_h), by - 3)
        x = bx + rnd.randint(-2, 2)
        c = opaque(o, x, y)
        if c:
            px(o, x, y, rnd.choice([hx("#3f362f"), hx("#6b5a4a"), hx("#556b3a")]))
    px(o, bx, int(by - trunk_h * 0.5), hx("#2c2420"))
    px(o, bx, int(by - trunk_h * 0.5) + 1, hx("#2c2420"))
    return finish(o, shadow_layer(w, h, bx, h - 2, 11, 3, 70))


def tree_dying(w, h, seed):
    rnd = random.Random(seed)
    o = new(w, h)
    d = ImageDraw.Draw(o)
    bark = hx("#5a4639")
    bx, by = w // 2, h - 3
    d.polygon([(bx - 5, by + 1), (bx - 2, by - 5), (bx + 2, by - 5), (bx + 5, by + 1)], fill=bark)
    d.polygon([(bx - 3, by - 3), (bx + 3, by - 3), (bx + 2, by - 20), (bx - 2, by - 20)], fill=bark)
    tips = []

    def branch(x, y, ang, ln, th, depth):
        x2 = x + math.cos(ang) * ln
        y2 = y - math.sin(ang) * ln
        d.line([x, y, x2, y2], fill=bark, width=max(1, int(round(th))))
        if depth > 0:
            for i in range(2):
                da = rnd.uniform(0.4, 0.9) * (1 if i == 0 else -1)
                branch(x2, y2, ang + da, ln * rnd.uniform(0.65, 0.8), th * 0.66, depth - 1)
        else:
            tips.append((x2, y2))

    branch(bx, by - 20, math.pi / 2, 14, 3, 3)
    branch(bx, by - 17, math.pi / 2 + 0.8, 12, 2.4, 2)
    branch(bx, by - 15, math.pi / 2 - 0.8, 12, 2.4, 2)
    # hojas: pocas, secas y amarillentas
    leaf = [hx("#7b8138"), hx("#9a9540"), hx("#6a6f30"), hx("#a68a3a")]
    for (x, y) in tips:
        if rnd.random() < 0.75:
            r = rnd.randint(3, 5)
            c = rnd.choice(leaf)
            d.ellipse([x - r, y - r + 1, x + r, y + r - 1], fill=c)
            for _ in range(5):
                px(o, int(x + rnd.randint(-r, r)), int(y + rnd.randint(-r + 1, r - 1)), rnd.choice(leaf))
    # huecos en la copa
    for _ in range(14):
        x = rnd.randint(4, w - 5)
        y = rnd.randint(2, h - 18)
        if o.getpixel((x, y))[0:3] in [c[0:3] for c in leaf]:
            px(o, x, y, NONE)
    return finish(o, shadow_layer(w, h, bx, h - 2, 12, 3, 70))


def bush(dry, seed):
    rnd = random.Random(seed)
    w, h = 26, 18
    o = new(w, h)
    d = ImageDraw.Draw(o)
    pal = [hx("#4a7a35"), hx("#3d6a2d"), hx("#5a8a3e")] if not dry else [hx("#8a7a3e"), hx("#6e6232"), hx("#a08c4a")]
    for (cx, cy, rx, ry) in [(8, 11, 7, 5), (17, 11, 8, 5), (13, 8, 8, 6), (6, 13, 5, 3), (20, 13, 5, 3)]:
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=rnd.choice(pal))
    for _ in range(36):
        x = rnd.randint(3, w - 4)
        y = rnd.randint(4, h - 4)
        if opaque(o, x, y):
            px(o, x, y, rnd.choice(pal + [lighten(pal[2], 25)]))
    if dry:
        for _ in range(6):
            x = rnd.randint(4, w - 5)
            y = rnd.randint(3, 9)
            d.line([x, y + 4, x + rnd.randint(-3, 3), y], fill=hx("#5a4a32"), width=1)
    else:
        for (x, y) in [(7, 9), (15, 6), (19, 10)]:
            px(o, x, y, hx("#c9575a"))
    return finish(o, shadow_layer(w, h, 13, h - 3, 11, 2, 65))


def rock(w, h, seed):
    rnd = random.Random(seed)
    o = new(w, h)
    d = ImageDraw.Draw(o)
    g = hx("#7a7a80")
    pts = [(1, h - 3), (2, h - 7), (w * 0.3, 2), (w * 0.62, 1), (w - 3, h * 0.45), (w - 2, h - 3)]
    d.polygon(pts, fill=g)
    d.polygon([(3, h - 4), (w * 0.35, 4), (w * 0.55, 3), (w * 0.45, h - 4)], fill=lighten(g, 14))
    d.polygon([(w * 0.6, h * 0.5), (w - 3, h * 0.5), (w - 3, h - 4), (w * 0.55, h - 4)], fill=lighten(g, -22))
    for _ in range(3):
        x = rnd.randint(3, w - 5)
        y = rnd.randint(4, h - 5)
        d.line([x, y, x + rnd.randint(-2, 2), y + 2], fill=lighten(g, -42), width=1)
    for _ in range(3):
        px(o, rnd.randint(3, w - 4), h - 5, hx("#5a7a3a"))
    return finish(o, shadow_layer(w, h, w // 2, h - 2, w // 2 - 1, 2, 70))


# ------------------------------------------------------------------ todo
def build():
    sprites = {
        "traffic_light_front": traffic_light(None),
        "traffic_light_front_amber": traffic_light("amber"),
        "traffic_light_front_red": traffic_light("red"),
        "traffic_light_back": traffic_light(None, back=True),
        "stop_sign": stop_sign(),
        "speed_60": speed_sign("60"),
        "speed_80": speed_sign("80"),
        "warning_ped": warning_ped(),
        "guide_horizonte": guide_sign("HORIZONTE"),
        "guide_industrial": guide_sign("INDUSTRIAL"),
        "street_lamp": street_lamp(False),
        "street_lamp_lit": street_lamp(True),
        "hydrant": hydrant(),
        "trash_can": trash_can(),
        "cone": cone(),
        "manhole": manhole(),
        "car_sedan_red": car("sedan", hx("#a8342c"), None, 1),
        "car_sedan_blue": car("sedan", hx("#35629a"), None, 2),
        "car_taxi": car("taxi", hx("#d4a622"), None, 3),
        "car_van_white": car("van", hx("#c9c9c2"), None, 4),
        "car_wagon_green": car("wagon", hx("#4a7a52"), None, 5),
        "tree_dead_a": tree_dead(46, 58, 11),
        "tree_dead_b": tree_dead(38, 48, 23),
        "tree_dying": tree_dying(54, 60, 31),
        "bush_green": bush(False, 5),
        "bush_dry": bush(True, 9),
        "rock_a": rock(16, 13, 3),
        "rock_b": rock(21, 16, 8),
    }
    return sprites


def preview(sprites, folder):
    os.makedirs(folder, exist_ok=True)
    names = list(sprites)
    scale = 4
    cols = 7
    cell_w, cell_h = 56 * scale // 2 + 20, 60 * scale // 2 + 20
    rows = (len(names) + cols - 1) // cols
    for bgname, bg in (("grass", (74, 104, 52, 255)), ("asphalt", (62, 62, 68, 255))):
        sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), bg)
        for i, n in enumerate(names):
            im = sprites[n]
            big = im.resize((im.width * scale // 2 * 1, im.height * scale // 2 * 1), Image.NEAREST)
            big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
            cx = (i % cols) * cell_w + (cell_w - big.width) // 2
            cy = (i // cols) * cell_h + cell_h - big.height - 6
            sheet.alpha_composite(big, (max(0, cx), max(0, cy)))
        sheet.save(os.path.join(folder, "props_%s.png" % bgname))


if __name__ == "__main__":
    sp = build()
    for k, v in sp.items():
        save(k, v)
    print("%d sprites en %s" % (len(sp), os.path.normpath(OUT_DIR)))
    if "--preview" in sys.argv:
        preview(sp, sys.argv[sys.argv.index("--preview") + 1])
