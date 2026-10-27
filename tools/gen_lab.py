#!/usr/bin/env python3
"""Laboratorio Horizonte: genera su techo, su interior y la puerta abierta, y las colisiones.

El arte y las cajas de colision salen de la MISMA lista de muebles y paredes, asi que coinciden.
Se dibuja a 16 px por tile (como el resto del juego) y se amplia 2x con vecino mas cercano.
Salida: assets/houses/laboratorio_roof.png, laboratorio_interior.png, lab_door_open.png
y devuelve los datos que gen_houses.py escribe en scripts/house_data.gd.
Uso: python3 tools/gen_lab.py [--preview ARCHIVO.png]"""
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_props as gp  # noqa: E402

TS = 16
TW, TH = 36, 20
W, H = TW * TS, TH * TS
OUT_DIR = os.path.join(HERE, "..", "assets", "houses")

OL = (24, 32, 44, 255)
WALL_L = (214, 222, 230, 255)
WALL_M = (176, 188, 200, 255)
WALL_D = (126, 140, 154, 255)
WALL_DD = (86, 98, 112, 255)
FLOOR_A = (156, 166, 178, 255)
FLOOR_B = (146, 156, 168, 255)
JOINT = (118, 128, 140, 255)
TEAL = (62, 168, 160, 255)
HAZ = (232, 192, 40, 255)
GREEN = (96, 224, 124, 255)
GREEN_D = (46, 140, 80, 255)
RED = (204, 62, 52, 255)
GLASS = (92, 138, 168, 255)
GLASS_L = (170, 210, 232, 255)
BLOOD = (110, 30, 30, 255)
VINE = (64, 120, 52, 255)
VINE_L = (96, 160, 66, 255)

# --------------------------------------------------------------- geometria (tiles)
FLOORS = [(1, 4, 11, 13), (12, 8, 23, 13), (12, 4, 23, 7), (24, 4, 34, 13)]
DOOR_X = 17          # puerta de 2 tiles (17 y 18), centro en x = 18
DOOR_Y = 14
# esquinas superiores recortadas (transparentes)
NOTCH = [(0, 0, 2, 3), (34, 0, 36, 3)]
# paredes interiores (x, y, ancho, alto) con sus pasillos
WALLS = [
    (11.75, 3.6, 0.5, 5.9), (11.75, 12.5, 0.5, 1.5),      # entre laboratorio oeste y vestibulo
    (23.75, 3.6, 0.5, 5.9), (23.75, 12.5, 0.5, 1.5),      # entre vestibulo y servidores
    (12.25, 7.25, 4.25, 0.5), (19.5, 7.25, 4.25, 0.5),    # entre archivo y vestibulo
]
# muebles: (clave, x, y, ancho, alto)
FURN = [
    ("bench", 1, 4, 5, 1.1), ("tank", 7, 4, 1.6, 2.4), ("tank", 9, 4, 1.6, 2.4),
    ("island", 3, 8, 5, 1.5), ("centrifuge", 9.5, 8, 1.3, 1.4), ("lockers", 1, 11, 1.2, 2.0),
    ("desk", 15, 10, 6, 1.2), ("bench_wait", 13, 12, 2.2, 0.9), ("bench_wait", 20.8, 12, 2.2, 0.9),
    ("cryo", 13, 4, 2, 2.3), ("cryo", 21.5, 4, 2, 2.3), ("terminal", 17, 4, 2.4, 1.2),
    ("racks", 25, 4, 9.5, 1.3), ("desk2", 26, 8, 3, 1.3), ("desk2", 31, 8, 3, 1.3), ("barrels", 33, 11, 1.2, 1.5),
]
TERMINAL_POS = (18.2, 5.7)      # donde se usa el archivo del Lote H-7
DOOR_BLOCK = (17.0, 14.0, 2.0, 0.9)   # puerta cerrada: caja que se quita al abrir


def img():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def R(d, x0, y0, x1, y1, c):
    x0, x1 = sorted((int(x0), int(x1)))
    y0, y1 = sorted((int(y0), int(y1)))
    d.rectangle([x0, y0, x1, y1], fill=c)


def T(v):
    return int(round(v * TS))


# ------------------------------------------------------------------ cuerpo
def body_mask():
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.rectangle([0, 0, W - 1, 17 * TS - 1], fill=255)
    for (x0, y0, x1, y1) in NOTCH:
        d.rectangle([x0 * TS, y0 * TS, x1 * TS - 1, y1 * TS - 1], fill=0)
    # porche de la entrada
    d.rectangle([14 * TS, 17 * TS, 22 * TS - 1, 19 * TS + 15], fill=255)
    return m


def floor_pattern(d, rect):
    x0, y0, x1, y1 = rect
    for ty in range(y0, y1 + 1):
        for tx in range(x0, x1 + 1):
            c = FLOOR_A if (tx + ty) % 2 == 0 else FLOOR_B
            R(d, tx * TS, ty * TS, tx * TS + TS - 1, ty * TS + TS - 1, c)
            d.line([(tx * TS, ty * TS), (tx * TS + TS - 1, ty * TS)], fill=JOINT)
            d.line([(tx * TS, ty * TS), (tx * TS, ty * TS + TS - 1)], fill=JOINT)


def back_wall(d, x0, x1, y_top=0.5, y_floor=4):
    """Pared del fondo de una sala vista en oblicuo: paneles claros, franja de color y zocalo."""
    R(d, T(x0), T(y_top), T(x1) - 1, T(y_floor) - 1, WALL_L)
    for px in range(T(x0), T(x1), 32):
        d.line([(px, T(y_top)), (px, T(y_floor) - 1)], fill=WALL_M)
    R(d, T(x0), T(y_floor) - 14, T(x1) - 1, T(y_floor) - 12, TEAL)
    R(d, T(x0), T(y_floor) - 11, T(x1) - 1, T(y_floor) - 1, WALL_M)
    R(d, T(x0), T(y_floor) - 4, T(x1) - 1, T(y_floor) - 1, WALL_D)
    R(d, T(x0), T(y_floor) - 1, T(x1) - 1, T(y_floor) - 1, WALL_DD)


def shade(c, k):
    return tuple(max(0, min(255, v + k)) for v in c[:3]) + (255,)


def box3d(d, x, y, w, h, top, front, depth=0.4):
    """Mueble visto de frente-arriba: tapa clara y frente oscuro."""
    X0, Y0, X1, Y1 = T(x), T(y), T(x + w) - 1, T(y + h) - 1
    fh = max(3, int(depth * TS))
    R(d, X0, Y0, X1, Y1 - fh, top)
    R(d, X0, Y1 - fh + 1, X1, Y1, front)
    d.line([(X0, Y0), (X1, Y0)], fill=shade(top, 28))
    d.line([(X0, Y1 - fh + 1), (X1, Y1 - fh + 1)], fill=shade(front, -40))
    d.rectangle([X0, Y0, X1, Y1], outline=OL)


def draw_furn(d, kind, x, y, w, h, rnd):
    X0, Y0, X1, Y1 = T(x), T(y), T(x + w) - 1, T(y + h) - 1
    if kind == "bench":
        box3d(d, x, y, w, h, (196, 204, 212, 255), (112, 126, 140, 255))
        for i in range(int(w)):                      # lavabos y frascos
            cx = X0 + 10 + i * 16
            R(d, cx, Y0 + 3, cx + 7, Y0 + 7, (120, 134, 148, 255)); R(d, cx + 2, Y0 + 4, cx + 5, Y0 + 5, GLASS_L)
        for i in range(3):
            px = X0 + 6 + i * 24
            R(d, px, Y0 - 5, px + 3, Y0 + 1, GLASS_L); R(d, px + 1, Y0 - 3, px + 2, Y0 + 1, GREEN)
    elif kind == "tank":
        R(d, X0, Y0, X1, Y1, (52, 66, 82, 255))
        R(d, X0 + 2, Y0 + 3, X1 - 2, Y1 - 6, GREEN_D)
        R(d, X0 + 3, Y0 + 5, X1 - 3, Y1 - 8, (66, 180, 104, 255))
        R(d, X0 + 4, Y0 + 5, X0 + 6, Y1 - 8, (170, 240, 190, 255))
        for bx, by in ((X0 + 12, Y0 + 12), (X0 + 15, Y0 + 24), (X0 + 9, Y0 + 30)):
            R(d, bx, by, bx + 1, by + 1, (210, 250, 220, 255))
        R(d, X0 + 4, Y0 + 14, X0 + 10, Y0 + 24, (30, 80, 56, 255))      # sombra de un "espécimen"
        R(d, X0, Y1 - 5, X1, Y1, (36, 46, 60, 255))
        R(d, X0, Y0, X1, Y0 + 2, (80, 96, 112, 255))
        d.rectangle([X0, Y0, X1, Y1], outline=OL)
    elif kind == "island":
        box3d(d, x, y, w, h, (214, 222, 228, 255), (96, 110, 126, 255), 0.5)
        for i in range(3):
            mx = X0 + 10 + i * 24
            R(d, mx, Y0 + 3, mx + 7, Y0 + 12, (40, 46, 56, 255)); R(d, mx + 2, Y0 + 5, mx + 5, Y0 + 7, GLASS_L)
        R(d, X1 - 22, Y0 + 4, X1 - 8, Y0 + 11, (240, 244, 248, 255))
    elif kind == "centrifuge":
        box3d(d, x, y, w, h, (190, 198, 206, 255), (96, 110, 126, 255), 0.5)
        d.ellipse([X0 + 3, Y0 + 3, X1 - 3, Y0 + 15], fill=(60, 70, 84, 255), outline=OL)
        R(d, X0 + 8, Y0 + 7, X1 - 8, Y0 + 9, RED)
    elif kind == "lockers":
        for i in range(2):
            lx = X0 + 1 + i * 9
            R(d, lx, Y0, lx + 8, Y1, (96, 120, 140, 255)); d.rectangle([lx, Y0, lx + 8, Y1], outline=OL)
            R(d, lx + 6, Y0 + 14, lx + 7, Y0 + 17, (220, 220, 200, 255))
            R(d, lx + 2, Y0 + 3, lx + 6, Y0 + 5, (60, 78, 94, 255))
    elif kind == "desk":
        box3d(d, x, y, w, h, (222, 226, 230, 255), (84, 104, 124, 255), 0.55)
        R(d, X0 + 6, Y0 + 3, X0 + 14, Y0 + 9, (40, 46, 56, 255)); R(d, X0 + 7, Y0 + 4, X0 + 13, Y0 + 7, GLASS)
        R(d, X1 - 22, Y0 + 5, X1 - 6, Y0 + 8, (240, 240, 232, 255))
        R(d, X0 + 40, Y0 + 4, X0 + 52, Y0 + 5, HAZ)
    elif kind == "bench_wait":
        box3d(d, x, y, w, h, (80, 110, 130, 255), (46, 66, 82, 255), 0.4)
    elif kind == "cryo":
        R(d, X0, Y0, X1, Y1, (40, 54, 70, 255))
        R(d, X0 + 3, Y0 + 3, X1 - 3, Y1 - 8, (90, 170, 220, 255))
        R(d, X0 + 5, Y0 + 5, X0 + 8, Y1 - 10, (200, 240, 255, 255))
        R(d, X0 + 14, Y0 + 12, X1 - 8, Y1 - 12, (60, 120, 170, 255))
        R(d, X0, Y1 - 7, X1, Y1, (30, 40, 52, 255))
        R(d, X0 + 4, Y1 - 5, X0 + 6, Y1 - 3, GREEN)
        d.rectangle([X0, Y0, X1, Y1], outline=OL)
        for fx in range(X0 + 4, X1 - 3, 9):
            d.line([(fx, Y0 + 3), (fx - 3, Y0 + 12)], fill=(220, 245, 255, 255))
    elif kind == "terminal":
        box3d(d, x, y, w, h, (64, 78, 96, 255), (34, 44, 58, 255), 0.5)
        mx = X0 + (X1 - X0) // 2 - 12
        R(d, mx, Y0 - 10, mx + 24, Y0 + 4, (30, 36, 46, 255)); R(d, mx + 2, Y0 - 8, mx + 22, Y0 + 2, (30, 150, 120, 255))
        for i in range(4):
            R(d, mx + 4, Y0 - 6 + i * 2, mx + 6 + (i * 5) % 13, Y0 - 6 + i * 2, (190, 255, 220, 255))
        d.rectangle([mx, Y0 - 10, mx + 24, Y0 + 4], outline=OL)
    elif kind == "racks":
        for i in range(int(w / 1.9)):
            rx = X0 + i * 30
            R(d, rx, Y0 - 6, rx + 26, Y1, (34, 40, 50, 255)); d.rectangle([rx, Y0 - 6, rx + 26, Y1], outline=OL)
            for j in range(6):
                R(d, rx + 3, Y0 - 3 + j * 4, rx + 22, Y0 - 1 + j * 4, (52, 60, 74, 255))
                led = (GREEN, RED, HAZ)[(i + j) % 3] if rnd.random() < 0.55 else (60, 66, 76, 255)
                R(d, rx + 19, Y0 - 3 + j * 4, rx + 20, Y0 - 2 + j * 4, led)
    elif kind == "desk2":
        box3d(d, x, y, w, h, (210, 216, 222, 255), (92, 110, 128, 255), 0.5)
        for mx in (X0 + 6, X0 + 30):
            R(d, mx, Y0 + 2, mx + 12, Y0 + 9, (36, 42, 54, 255)); R(d, mx + 1, Y0 + 3, mx + 11, Y0 + 7, GLASS)
    elif kind == "barrels":
        for (bx, by) in ((X0, Y0), (X0 + 9, Y0 + 8), (X0 + 1, Y0 + 14)):
            R(d, bx, by, bx + 9, by + 12, (212, 186, 52, 255)); R(d, bx, by, bx + 1, by + 12, (240, 220, 110, 255))
            R(d, bx, by + 4, bx + 9, by + 5, (60, 60, 60, 255)); R(d, bx + 3, by + 6, bx + 6, by + 9, (40, 120, 50, 255))
            d.rectangle([bx, by, bx + 9, by + 12], outline=OL)


def vines(d, rnd, pts):
    for (x, y, n) in pts:
        for k in range(n):
            x += rnd.choice((-1, 0, 0, 1)); y += rnd.choice((0, 1, 1))
            R(d, x, y, x + 1, y + 1, VINE if k % 3 else VINE_L)


def stains(d, rnd, rects, n):
    for _ in range(n):
        (x0, y0, x1, y1) = rnd.choice(rects)
        bx, by = rnd.randint(T(x0), T(x1) - 6), rnd.randint(T(y0), T(y1) - 6)
        for _k in range(rnd.randint(8, 18)):
            R(d, bx + rnd.randint(0, 8), by + rnd.randint(0, 5), bx + rnd.randint(1, 9), by + rnd.randint(1, 6), BLOOD)


def facade(d, rnd):
    """Frente del edificio (filas 14 a 17) con ventanas, entrada, cartel y escalones."""
    R(d, 0, 14 * TS, W - 1, 17 * TS - 1, WALL_M)
    R(d, 0, 14 * TS, W - 1, 14 * TS + 2, WALL_L)
    R(d, 0, 17 * TS - 5, W - 1, 17 * TS - 1, WALL_DD)
    R(d, 0, 14 * TS + 22, W - 1, 14 * TS + 24, TEAL)
    for x0, x1 in ((2, 6), (8, 12), (24, 28), (30, 34)):
        wx0, wx1 = T(x0), T(x1)
        R(d, wx0, 14 * TS + 8, wx1, 16 * TS + 4, (40, 54, 70, 255))
        R(d, wx0 + 2, 14 * TS + 10, wx1 - 2, 16 * TS + 2, GLASS)
        for k in range(wx0 + 4, wx1 - 4, 14):
            d.line([(k, 14 * TS + 10), (k - 8, 16 * TS + 2)], fill=GLASS_L)
        d.line([((wx0 + wx1) // 2, 14 * TS + 10), ((wx0 + wx1) // 2, 16 * TS + 2)], fill=WALL_DD)
        d.rectangle([wx0, 14 * TS + 8, wx1, 16 * TS + 4], outline=OL)
        if rnd.random() < 0.7:
            d.line([(wx0 + 8, 14 * TS + 14), (wx0 + 20, 15 * TS + 6), (wx0 + 14, 16 * TS)], fill=(220, 230, 240, 255))
    # paneles con el logo
    for x in (13, 21):
        pass
    # entrada
    R(d, 14 * TS, 14 * TS + 4, 22 * TS - 1, 17 * TS, WALL_L)
    R(d, 14 * TS, 14 * TS + 4, 22 * TS - 1, 14 * TS + 7, WALL_DD)
    d.rectangle([14 * TS, 14 * TS + 4, 22 * TS - 1, 17 * TS], outline=OL)
    # puerta corrediza de seguridad (2 hojas) con luz roja
    dx0, dx1 = DOOR_X * TS, (DOOR_X + 2) * TS - 1
    R(d, dx0 - 2, 14 * TS + 10, dx1 + 2, 17 * TS - 1, (40, 48, 60, 255))
    R(d, dx0, 14 * TS + 12, dx0 + 15, 17 * TS - 3, (96, 124, 148, 255))
    R(d, dx0 + 16, 14 * TS + 12, dx1, 17 * TS - 3, (88, 116, 140, 255))
    R(d, dx0 + 2, 14 * TS + 14, dx0 + 5, 17 * TS - 6, GLASS_L)
    R(d, dx0 + 15, 14 * TS + 12, dx0 + 16, 17 * TS - 3, OL)
    R(d, dx0 + 14, 14 * TS + 8, dx0 + 17, 14 * TS + 10, RED)
    R(d, dx1 + 4, 15 * TS + 2, dx1 + 7, 15 * TS + 8, (30, 36, 46, 255)); R(d, dx1 + 5, 15 * TS + 3, dx1 + 6, 15 * TS + 4, RED)
    # cartel HORIZONTE sobre la entrada
    label = "HORIZONTE"
    tw = gp.text_w(label)
    sx = (W - (tw + 8)) // 2
    R(d, sx, 14 * TS - 6 + 6, sx + tw + 7, 14 * TS + 12 - 1, (30, 44, 60, 255))
    d.rectangle([sx, 14 * TS, sx + tw + 7, 14 * TS + 11], outline=OL)
    gp.text(d._image, sx + 4, 14 * TS + 3, label, (230, 240, 236, 255))
    R(d, sx + 2, 14 * TS + 11, sx + tw + 5, 14 * TS + 11, TEAL)
    # porche: escalones y columnas
    R(d, 15 * TS, 17 * TS, 21 * TS - 1, 18 * TS - 1, (176, 180, 186, 255))
    R(d, 15 * TS, 18 * TS, 21 * TS - 1, 19 * TS - 1, (160, 164, 170, 255))
    R(d, 15 * TS + 6, 19 * TS, 21 * TS - 7, 19 * TS + 15, (140, 144, 150, 255))
    for yy in (17 * TS, 18 * TS, 19 * TS):
        d.line([(15 * TS, yy), (21 * TS - 1, yy)], fill=WALL_DD)
    for cx in (14 * TS + 2, 21 * TS + 4):
        R(d, cx, 15 * TS, cx + 9, 18 * TS + 4, WALL_L); R(d, cx, 15 * TS, cx + 2, 18 * TS + 4, (240, 244, 248, 255))
        R(d, cx + 8, 15 * TS, cx + 9, 18 * TS + 4, WALL_D); d.rectangle([cx, 15 * TS, cx + 9, 18 * TS + 4], outline=OL)
    # macetas secas junto a la entrada
    for cx in (12 * TS + 4, 22 * TS + 8):
        R(d, cx, 16 * TS + 4, cx + 11, 17 * TS - 1, (120, 80, 56, 255)); d.rectangle([cx, 16 * TS + 4, cx + 11, 17 * TS - 1], outline=OL)
        for k in range(5):
            R(d, cx + 1 + k * 2, 16 * TS - 2 + (k % 2) * 3, cx + 2 + k * 2, 16 * TS + 4, (110, 126, 60, 255))
    # manchas y enredaderas en la fachada
    for _ in range(14):
        sx2 = rnd.randint(0, W - 20); sy2 = rnd.randint(14 * TS + 24, 17 * TS - 8)
        R(d, sx2, sy2, sx2 + rnd.randint(4, 12), sy2 + rnd.randint(1, 3), (110, 120, 116, 255))
    vines(d, rnd, [(6, 14 * TS + 6, 30), (W - 10, 14 * TS + 4, 28), (12 * TS, 14 * TS + 30, 12)])


def interior_image(rnd):
    im = img()
    d = ImageDraw.Draw(im)
    d._image = im
    for rect in FLOORS:
        floor_pattern(d, rect)
    # parte superior de las salas sin piso (bajo la pared del fondo)
    back_wall(d, 1, 11.75)
    back_wall(d, 12.25, 23.75)
    back_wall(d, 24.25, 35)
    # cartel del archivo y senales
    R(d, T(17), T(2.2), T(19.2), T(3.4), (24, 40, 36, 255)); d.rectangle([T(17), T(2.2), T(19.2), T(3.4)], outline=OL)
    gp.text(im, T(17) + 3, T(2.2) + 4, "H", GREEN)
    R(d, T(17) + 11, T(2.2) + 4, T(17) + 22, T(2.2) + 8, GREEN_D)
    for x in (4.5, 28.5):
        R(d, T(x), T(1.4), T(x) + 24, T(1.4) + 18, HAZ); d.rectangle([T(x), T(1.4), T(x) + 24, T(1.4) + 18], outline=OL)
        d.ellipse([T(x) + 7, T(1.4) + 4, T(x) + 17, T(1.4) + 14], outline=(30, 30, 30, 255))
    # paredes interiores
    for (x, y, w, h) in WALLS:
        R(d, T(x), T(y), T(x + w) - 1, T(y + h) - 1, WALL_L)
        R(d, T(x), T(y), T(x), T(y + h) - 1, (244, 248, 250, 255))
        R(d, T(x + w) - 1, T(y), T(x + w) - 1, T(y + h) - 1, WALL_D)
        d.rectangle([T(x), T(y), T(x + w) - 1, T(y + h) - 1], outline=OL)
    for (kind, x, y, w, h) in sorted(FURN, key=lambda f: f[2] + f[4]):
        draw_furn(d, kind, x, y, w, h, rnd)
    stains(d, rnd, [(2, 9, 11, 13), (13, 8, 23, 13), (25, 6, 34, 13), (13, 5, 23, 7)], 7)
    # papeles y escombros
    for _ in range(26):
        px, py = rnd.randint(T(1), T(34)), rnd.randint(T(5), T(13))
        R(d, px, py, px + rnd.randint(2, 5), py + rnd.randint(1, 3), (236, 238, 232, 255))
    # marco exterior
    facade(d, rnd)
    R(d, 0, 0, W - 1, 3, WALL_DD)
    R(d, 0, 0, 3, 14 * TS, WALL_DD); R(d, W - 4, 0, W - 1, 14 * TS, WALL_DD)
    R(d, 0, 14 * TS - 4, W - 1, 14 * TS - 1, WALL_DD)
    vines(d, rnd, [(5, 8, 40), (W - 8, 10, 36), (T(12) , 4, 12), (T(24), 4, 14)])
    return im


def roof_image(rnd):
    im = img()
    d = ImageDraw.Draw(im)
    d._image = im
    R(d, 0, 0, W - 1, 14 * TS - 1, (186, 194, 202, 255))
    # paneles de cubierta
    for x in range(0, W, 32):
        d.line([(x, 0), (x, 14 * TS - 1)], fill=(160, 170, 180, 255))
    for y in range(0, 14 * TS, 48):
        d.line([(0, y), (W - 1, y)], fill=(160, 170, 180, 255))
    # parapeto
    R(d, 0, 0, W - 1, 5, WALL_DD); R(d, 0, 0, 5, 14 * TS, WALL_DD); R(d, W - 6, 0, W - 1, 14 * TS, WALL_DD)
    R(d, 0, 14 * TS - 6, W - 1, 14 * TS - 1, WALL_DD)
    R(d, 2, 2, W - 3, 3, WALL_L)
    # claraboyas
    for (x0, x1) in ((3, 9), (14, 22), (27, 33)):
        R(d, T(x0), T(2), T(x1), T(4.5), (58, 74, 92, 255))
        R(d, T(x0) + 3, T(2) + 3, T(x1) - 3, T(4.5) - 3, GLASS)
        for k in range(T(x0) + 8, T(x1) - 3, 12):
            d.line([(k, T(2) + 3), (k - 6, T(4.5) - 3)], fill=GLASS_L)
        d.line([((T(x0) + T(x1)) // 2, T(2) + 3), ((T(x0) + T(x1)) // 2, T(4.5) - 3)], fill=WALL_DD)
        d.rectangle([T(x0), T(2), T(x1), T(4.5)], outline=OL)
    # unidades de aire acondicionado
    for (x, y) in ((4, 7), (9, 9), (26, 7), (30, 9), (13, 10.5), (21, 10.5)):
        R(d, T(x), T(y), T(x) + 33, T(y) + 29, (150, 160, 170, 255)); d.rectangle([T(x), T(y), T(x) + 33, T(y) + 29], outline=OL)
        R(d, T(x), T(y) + 20, T(x) + 33, T(y) + 29, (116, 126, 138, 255))
        cx, cy = T(x) + 16, T(y) + 10
        d.ellipse([cx - 9, cy - 8, cx + 9, cy + 8], fill=(46, 54, 66, 255), outline=OL)
        d.line([(cx - 8, cy), (cx + 8, cy)], fill=(130, 140, 150, 255)); d.line([(cx, cy - 7), (cx, cy + 7)], fill=(130, 140, 150, 255))
    # emblema de riesgo biologico en el centro
    cx, cy = T(18), T(7.4)
    d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=(230, 188, 40, 255), outline=OL)
    d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], outline=(30, 30, 30, 255))
    for ang in range(3):
        import math
        a = ang * 2.094 - 1.57
        px, py = cx + int(math.cos(a) * 9), cy + int(math.sin(a) * 9)
        d.ellipse([px - 6, py - 6, px + 6, py + 6], outline=(30, 30, 30, 255))
    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(30, 30, 30, 255))
    # tuberias, antena y mancha de humedad
    d.line([(T(2), T(13)), (T(34), T(13))], fill=(110, 118, 128, 255), width=3)
    R(d, T(17), T(10.3), T(19), T(10.3) + 3, (110, 118, 128, 255))
    R(d, T(32), T(3), T(32) + 2, T(3) + 20, (90, 96, 106, 255))
    stains(d, rnd, [(3, 5, 12, 12), (22, 6, 33, 12)], 5)
    for _ in range(18):
        sx, sy = rnd.randint(8, W - 12), rnd.randint(8, 14 * TS - 8)
        R(d, sx, sy, sx + rnd.randint(3, 9), sy + rnd.randint(1, 3), (140, 150, 158, 255))
    vines(d, rnd, [(8, 8, 50), (W - 12, 10, 44), (T(15), 8, 20), (T(24), 6, 24)])
    facade(d, rnd)
    # recortar esquinas
    m = body_mask()
    a = im.split()[3]
    im.putalpha(Image.composite(a, Image.new("L", (W, H), 0), m))
    return im


def door_open_image():
    w, h = 3 * TS, 3 * TS
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    R(d, 0, 0, w - 1, h - 1, (40, 48, 60, 255))
    R(d, 2, 4, w - 3, h - 3, (14, 20, 28, 255))
    R(d, 2, 4, 6, h - 3, (96, 124, 148, 255)); R(d, w - 7, 4, w - 3, h - 3, (88, 116, 140, 255))
    R(d, w // 2 - 2, 0, w // 2 + 1, 3, GREEN)
    d.rectangle([0, 0, w - 1, h - 1], outline=OL)
    return im


def tile_rows(body, roof, inte):
    a1, a2 = roof.split()[3], inte.split()[3]
    rows = []
    fb = max(f[3] for f in FLOORS)
    for y in range(TH):
        row = ""
        for x in range(TW):
            cx, cy = x * TS + TS // 2, y * TS + TS // 2
            c = "#" if (a1.getpixel((cx, cy)) > 0 or a2.getpixel((cx, cy)) > 0) else "."
            for (x0, y0, x1, y1) in FLOORS:
                if x0 <= x <= x1 and y0 <= y <= y1:
                    c = "f"
                    for (_k, bx, by, bw, bh) in FURN:
                        if bx <= x + 0.5 <= bx + bw and by <= y + 0.5 <= by + bh:
                            c = "o"
            if DOOR_X <= x <= DOOR_X + 1 and fb < y < TH:
                c = "p"
            row += c
        rows.append(row)
    return rows


def build(save=True):
    rnd = random.Random(7)
    inte = interior_image(rnd)
    rnd = random.Random(7)
    roof = roof_image(rnd)
    door = door_open_image()
    out = {}
    for name, im in (("laboratorio_interior", inte), ("laboratorio_roof", roof), ("lab_door_open", door)):
        import gen_polish
        big = gen_polish.polish(im, seed=7) if name != "lab_door_open" else im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        out[name] = big
        if save:
            big.save(os.path.join(OUT_DIR, name + ".png"))
    boxes = [(x, y, w, h) for (x, y, w, h) in WALLS] + [(x, y, w, h) for (_k, x, y, w, h) in FURN]
    data = {"w": TW, "h": TH, "door_x": DOOR_X, "rows": tile_rows(body_mask(), roof, inte), "boxes": boxes,
            "terminal": TERMINAL_POS, "door_block": DOOR_BLOCK}
    return out, data


if __name__ == "__main__":
    imgs, data = build()
    print("laboratorio:", imgs["laboratorio_interior"].size)
    if "--preview" in sys.argv:
        p = sys.argv[sys.argv.index("--preview") + 1]
        sheet = Image.new("RGBA", (imgs["laboratorio_interior"].width, imgs["laboratorio_interior"].height * 2 + 10), (70, 100, 70, 255))
        sheet.alpha_composite(imgs["laboratorio_interior"], (0, 0))
        sheet.alpha_composite(imgs["laboratorio_roof"], (0, imgs["laboratorio_interior"].height + 10))
        sheet.save(p)
