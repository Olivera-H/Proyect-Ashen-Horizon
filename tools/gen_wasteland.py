#!/usr/bin/env python3
"""Campo desolado fuera de la cerca en los bordes oeste, norte y sur del mapa:
assets/world/wasteland.png (384x1920), wasteland_n.png y wasteland_s.png (3968x384, incluyen las esquinas). Tierra reseca, grietas, cráteres, árboles muertos, huesos y
cadáveres de zombis (hojas de assets/sprites rotadas y apagadas). Procedural y determinista.
Uso: python3 tools/gen_wasteland.py"""
import math
import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.join(HERE, "..", "assets", "sprites")
OUT_DIR = os.path.join(HERE, "..", "assets", "world")
DEPTH = 384          # profundidad del campo (24 tiles)
MAP_W, MAP_H = 3584, 1920   # mapa en px (224x120 tiles)
# Un unico lienzo para todo el anillo (oeste + norte + sur) y luego se recorta en 3 imagenes:
# asi las esquinas y las uniones son continuas (sin lineas). Coordenadas de lienzo = mundo + DEPTH.
W, H = MAP_W + DEPTH, MAP_H + 2 * DEPTH
MX0, MY0, MY1 = DEPTH, DEPTH, DEPTH + MAP_H   # el mapa ocupa x>=MX0, MY0<=y<MY1 (sin franja este)
rnd = random.Random(20261104)


def in_map(x, y, pad=0):
    return x >= MX0 - pad and MY0 - pad <= y < MY1 + pad


def rand_pt(up=0, side=14):
    """Punto aleatorio del anillo cuyo objeto (alto `up`, medio ancho `side`) no invade el mapa."""
    while True:
        x, y = rnd.randrange(20, W - 20), rnd.randrange(20, H - 6)
        if x + side >= MX0 and y - up <= MY1 + 2 and y + 4 >= MY0 - 2:
            continue
        return x, y


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


GROUND = [hx(c) for c in ("6a6049", "62583f", "716650", "5a513c", "685c45", "75694f")]
DARK = hx("463e2f")
ASH = hx("8d887c")


def vnoise(x, y, seed, scale):
    """Ruido de valor suave 0..1."""
    gx, gy = x / scale, y / scale
    x0, y0 = int(math.floor(gx)), int(math.floor(gy))
    fx, fy = gx - x0, gy - y0

    def h(i, j):
        return random.Random((i * 73856093) ^ (j * 19349663) ^ seed).random()
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = h(x0, y0) * (1 - sx) + h(x0 + 1, y0) * sx
    b = h(x0, y0 + 1) * (1 - sx) + h(x0 + 1, y0 + 1) * sx
    return a * (1 - sy) + b * sy


def base():
    img = Image.new("RGBA", (W, H), GROUND[0])
    px = img.load()
    cell = 2
    for y in range(0, H, cell):
        for x in range(0, W, cell):
            if in_map(x, y):
                continue
            n = vnoise(x, y, 11, 40) * 0.6 + vnoise(x, y, 7, 11) * 0.4
            i = min(len(GROUND) - 1, int(n * len(GROUND)))
            c = GROUND[i]
            if rnd.random() < 0.06:
                c = GROUND[rnd.randrange(len(GROUND))]
            # manchas quemadas
            if vnoise(x, y, 99, 70) > 0.72:
                c = tuple(int(v * 0.72) for v in c[:3]) + (255,)
            for dy in range(cell):
                for dx in range(cell):
                    px[x + dx, y + dy] = c
    return img


def put(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), c)


def cracks(img, n):
    for _ in range(n):
        x, y = rand_pt(0, 4)
        ang = rnd.random() * math.tau
        for _ in range(rnd.randrange(12, 50)):
            ang += rnd.uniform(-0.5, 0.5)
            x += math.cos(ang) * 1.3
            y += math.sin(ang) * 1.3
            put(img, int(x), int(y), DARK)
            if rnd.random() < 0.06:
                bx, by, ba = x, y, ang + rnd.choice((-1, 1)) * 0.9
                for _ in range(rnd.randrange(4, 14)):
                    bx += math.cos(ba)
                    by += math.sin(ba)
                    put(img, int(bx), int(by), DARK)


def crater(img, cx, cy, r):
    for y in range(-r, r + 1):
        for x in range(-int(r * 1.4), int(r * 1.4) + 1):
            d = math.hypot(x / 1.4, y)
            if d <= r:
                c = hx("3a3326") if d < r * 0.6 else hx("4c4331")
                put(img, cx + x, cy + y, c)
            elif d <= r + 1.5:
                put(img, cx + x, cy + y, hx("857a60"))


def ash_pile(img, cx, cy):
    for _ in range(rnd.randrange(20, 50)):
        put(img, cx + rnd.randint(-6, 6), cy + rnd.randint(-3, 3), rnd.choice((ASH, hx("a09b8e"), hx("5e5a52"))))


def bones(img, cx, cy):
    c = hx("d9d2bd")
    ang = rnd.random() * math.pi
    for t in range(-4, 5):
        put(img, cx + int(math.cos(ang) * t), cy + int(math.sin(ang) * t), c)
    put(img, cx + int(math.cos(ang) * 5), cy + int(math.sin(ang) * 5) - 1, c)
    put(img, cx + int(math.cos(ang) * -5), cy + int(math.sin(ang) * -5) + 1, c)
    if rnd.random() < 0.4:   # craneo
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, 0)):
            put(img, cx + 6 + dx, cy - 3 + dy, c)
        put(img, cx + 6, cy - 3, hx("2a2520"))


def tufts(img, n):
    for _ in range(n):
        x, y = rand_pt(4, 2)
        c = rnd.choice((hx("8a7a3c"), hx("6e6230"), hx("9b8d52")))
        for k in range(rnd.randrange(2, 5)):
            put(img, x + k - 1, y - rnd.randrange(1, 4), c)
            put(img, x + k - 1, y, hx("4a4128"))


def dead_tree(img, x, y):
    t = hx("1f1a18")
    t2 = hx("342b25")
    h = rnd.randrange(22, 40)
    for i in range(h):
        put(img, x, y - i, t)
        put(img, x + 1, y - i, t2)
        if i < 5:
            put(img, x - 1, y - i, t)
            put(img, x + 2, y - i, t)

    def branch(bx, by, ang, ln, depth):
        for i in range(ln):
            bx += math.cos(ang)
            by += math.sin(ang)
            put(img, int(bx), int(by), t)
        if depth > 0:
            branch(bx, by, ang - 0.6, ln * 2 // 3, depth - 1)
            branch(bx, by, ang + 0.6, ln * 2 // 3, depth - 1)
    for k in range(rnd.randrange(2, 4)):
        by = y - h + rnd.randrange(0, h // 2)
        branch(x, by, -math.pi / 2 + rnd.choice((-1, 1)) * rnd.uniform(0.5, 1.1), rnd.randrange(8, 14), 2)
    # sombra
    for dx in range(-5, 10):
        put(img, x + dx, y + 1, hx("352e22"))


def depth_at(x, y):
    """Distancia (Chebyshev) al borde del mapa, igual en toda la esquina."""
    dx = max(0, MX0 - x)
    dy = max(0, MY0 - y, y - (MY1 - 1))
    return max(dx, dy)


def ring_pt_near_fence(depth):
    """Punto del anillo a `depth` px de la cerca (lado al azar, ponderado por longitud)."""
    r = rnd.random() * (2 * W + MAP_H)
    if r < W:
        return rnd.randrange(20, W - 30), MY0 - depth
    if r < 2 * W:
        return rnd.randrange(20, W - 30), MY1 + depth
    return MX0 - depth, rnd.randrange(MY0, MY1)


def corpse_sprites():
    """Zombis tumbados: cuadro 'idle abajo' de cada hoja, girado y apagado."""
    out = []
    for name, fw, fh in (("walker_0", 24, 32), ("walker_1", 24, 32), ("walker_2", 24, 32), ("walker_3", 24, 32),
                         ("runner_0", 24, 32), ("runner_1", 24, 32), ("tank", 40, 44)):
        sh = Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")
        fr = sh.crop((0, 0, fw, fh))
        out.append((name, fr))
    return out


def blood_pool(img, cx, cy, rx, ry):
    for y in range(-ry, ry + 1):
        for x in range(-rx, rx + 1):
            d = (x / rx) ** 2 + (y / ry) ** 2
            if d <= 1.0 and rnd.random() < (0.95 if d < 0.6 else 0.6):
                c = hx("4a0f12") if d < 0.5 else hx("5e1a1a")
                put(img, cx + x, cy + y, c)


def dim(fr):
    px = fr.load()
    for y in range(fr.height):
        for x in range(fr.width):
            r, g, b, a = px[x, y]
            if a:
                gray = (r + g + b) // 3
                px[x, y] = (int((r * 0.45 + gray * 0.2) * 0.8), int((g * 0.5 + gray * 0.2) * 0.78), int((b * 0.45 + gray * 0.2) * 0.72), a)
    return fr


def place_corpses(img, n):
    sprites = corpse_sprites()
    spots = []
    # grupos: la mayoria cerca de la cerca (derecha), algunos dispersos
    for i in range(n):
        if rnd.random() < 0.4 and spots:
            ox, oy = rnd.choice(spots)
            x, y = ox + rnd.randint(-26, 26), oy + rnd.randint(-22, 22)
        else:
            x, y = ring_pt_near_fence(int(rnd.triangular(40, DEPTH - 30, 70)))
        x = max(24, min(W - 34, x))
        y = max(20, min(H - 24, y))
        if in_map(x, y, 10):
            continue
        spots.append((x, y))
        name, fr = rnd.choice(sprites[:-1] if rnd.random() < 0.95 else sprites[-1:])
        fr = dim(fr.copy())
        if rnd.random() < 0.5:
            fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
        rot = rnd.choice((90, 270, 90, 270, 180, 60, 120))
        fr = fr.rotate(rot, expand=True, resample=Image.NEAREST)
        bbox = fr.getbbox()
        if bbox:
            fr = fr.crop(bbox)
        blood_pool(img, x, y + 2, fr.width // 2 + 3, max(3, fr.height // 3 + 1))
        img.alpha_composite(fr, (x - fr.width // 2, y - fr.height // 2))
        # sombra bajo el cuerpo
        for dx in range(-fr.width // 2, fr.width // 2):
            put(img, x + dx, y + fr.height // 2 + 1, hx("2f2a20"))


def vignette(img):
    px = img.load()
    for y in range(H):
        for x in range(W):
            if in_map(x, y):
                continue
            dp = depth_at(x, y)
            k = min(1.0, (DEPTH - dp) / 120.0)   # el campo se pierde en la niebla lejos de la cerca
            f = 0.35 + 0.65 * k
            if dp < 10:   # franja de sombra junto a la cerca
                f *= 1.0 - (10 - dp) * 0.035
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * f), int(g * f), int(b * f), a)


def main():
    img = base()
    scale = (W * H - MAP_W * MAP_H) / (384 * 1920)
    cracks(img, int(160 * scale))
    for _ in range(int(28 * scale)):
        cx, cy = rand_pt(9, 14)
        crater(img, cx, cy, rnd.randrange(4, 9))
    for _ in range(int(90 * scale)):
        ash_pile(img, *rand_pt(0, 8))
    tufts(img, int(380 * scale))
    for _ in range(int(60 * scale)):
        bones(img, *rand_pt(0, 8))
    place_corpses(img, int(135 * scale))
    for _ in range(int(46 * scale)):
        tx, ty = rand_pt(46, 12)
        dead_tree(img, tx, ty)
    vignette(img)
    os.makedirs(OUT_DIR, exist_ok=True)
    rgb = img.convert("RGB")
    # recortes: oeste (bajo el mapa-oeste), norte y sur (incluyen las esquinas)
    for name, box in (("wasteland.png", (0, MY0, DEPTH, MY1)),
                      ("wasteland_n.png", (0, 0, W, MY0)),
                      ("wasteland_s.png", (0, MY1, W, H))):
        path = os.path.join(OUT_DIR, name)
        rgb.crop(box).save(path, optimize=True)
        print("ok", name, os.path.getsize(path))


if __name__ == "__main__":
    main()
