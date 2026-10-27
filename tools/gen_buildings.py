#!/usr/bin/env python3
"""Edificios nuevos del vecindario: supermercado, comisaria, iglesia, tienda, casita,
apartamentos, cuartel (base militar) y cancha. Todo se dibuja por codigo y el arte y las
colisiones salen de la MISMA lista de muebles, asi que coinciden.

Cada edificio mide tw x th tiles (16 px). Arriba va el cuerpo (techo / interior), abajo la
fachada (3 filas) y el porche (2 filas). Se dibuja a 16 px por tile y se amplia 2x.
Salida: assets/houses/<id>_roof.png y <id>_interior.png y los datos de cada edificio
(los escribe gen_houses.py en scripts/house_data.gd).
Uso: python3 tools/gen_buildings.py [--preview ARCHIVO.png]"""
import os
import random
import zlib
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_props as gp  # noqa: E402
from gen_lab import R, T, shade, box3d, vines, stains, OL, TS  # noqa: E402

OUT_DIR = os.path.join(HERE, "..", "assets", "houses")
BLOOD = (110, 30, 30, 255)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# ------------------------------------------------------------------ especificaciones
# furn: (clave, x, y, ancho, alto) en tiles.  walls: tabiques (x, y, ancho, alto).
SPECS = {
    "supermercado": dict(
        tw=25, th=14, door_x=11, floors=[(1, 3, 23, 8)], sign="SUPER",
        pal=dict(wall="#e9e2cf", wall_d="#a89e86", floor_a="#d9d4c6", floor_b="#cbc6b8", joint="#a8a392",
                 accent="#d8362b", roof="#c9c2ae", roof_d="#8f8872", sign_bg="#c82f26", sign_fg="#fff4dc"),
        windows=[(2, 5), (6, 9), (14, 18), (19, 23)], awning="#d8362b",
        walls=[],
        furn=[("freezer", 1, 3.0, 23, 1.1),
              ("shelf", 2, 5.0, 6, 0.9), ("shelf", 9.5, 5.0, 6, 0.9), ("shelf", 17, 5.0, 6, 0.9),
              ("counter", 3, 8.0, 3, 0.9), ("counter", 7, 8.0, 3, 0.9),
              ("counter", 15, 8.0, 3, 0.9), ("counter", 19.5, 8.0, 3, 0.9),
              ("crate", 22, 3.9, 1.3, 1.0)],
        roof_kind="flat_ac"),
    "comisaria": dict(
        tw=20, th=14, door_x=9, floors=[(1, 3, 18, 8)], sign="POLICIA",
        pal=dict(wall="#d7dde6", wall_d="#8b97a8", floor_a="#b9c0cb", floor_b="#adb5c1", joint="#8a93a1",
                 accent="#2c4f9e", roof="#6d7a90", roof_d="#454f60", sign_bg="#1f3a78", sign_fg="#eaf0ff"),
        windows=[(2, 5), (6, 7), (12, 13), (14, 17)], awning=None,
        walls=[(10.0, 3.0, 0.4, 3.0)],
        furn=[("desk", 2, 4.0, 3, 1.1), ("desk", 6, 4.0, 3, 1.1), ("cell", 11, 3.2, 3, 2.4), ("cell", 15, 3.2, 3, 2.4),
              ("rack", 11.5, 6.6, 5.5, 0.6), ("desk", 3, 7.2, 4, 0.9), ("locker", 1, 3.6, 0.9, 1.4),
              ("bench", 12, 8.2, 3, 0.8)],
        roof_kind="pitched_blue"),
    "iglesia": dict(
        tw=14, th=15, door_x=6, floors=[(1, 3, 12, 9)], sign=None,
        pal=dict(wall="#e8dcc4", wall_d="#9a8a6c", floor_a="#b4a48a", floor_b="#a8987e", joint="#8a7a62",
                 accent="#7a2f2f", roof="#8a5a46", roof_d="#5a3a2c", sign_bg="#5a4630", sign_fg="#f3e6c4"),
        windows=[(2, 4), (9, 11)], awning=None,
        walls=[],
        furn=[("altar", 5, 3.2, 4, 1.3), ("pew", 2, 5.0, 4, 0.8), ("pew", 2, 6.7, 4, 0.8), ("pew", 2, 8.4, 4, 0.8),
              ("pew", 8, 5.0, 4, 0.8), ("pew", 8, 6.7, 4, 0.8), ("pew", 8, 8.4, 4, 0.8)],
        roof_kind="church"),
    "tienda": dict(
        tw=12, th=12, door_x=5, floors=[(1, 3, 10, 6)], sign="TIENDA",
        pal=dict(wall="#e3d3b8", wall_d="#9a8868", floor_a="#cdbf9f", floor_b="#c2b494", joint="#a09372",
                 accent="#3f8f5b", roof="#a65a3c", roof_d="#6d3a28", sign_bg="#2f6e46", sign_fg="#f2ffe9"),
        windows=[(1, 3), (8, 10)], awning="#3f8f5b",
        walls=[],
        furn=[("shelf", 1, 3.3, 4, 0.9), ("shelf", 7, 3.3, 4, 0.9), ("counter", 1.5, 5.4, 3, 0.9), ("crate", 9, 5.6, 1.2, 1.0)],
        roof_kind="pitched_red"),
    "casita": dict(
        tw=14, th=12, door_x=6, floors=[(1, 3, 12, 6)], sign=None,
        pal=dict(wall="#e6d8c0", wall_d="#a08c6c", floor_a="#b88f62", floor_b="#ad8458", joint="#8a6a46",
                 accent="#4a7fa8", roof="#6a7f94", roof_d="#43566a", sign_bg="#5a4630", sign_fg="#f3e6c4"),
        windows=[(1, 4), (9, 12)], awning=None,
        walls=[],
        furn=[("bed", 1, 3.2, 2.4, 1.7), ("table", 5, 3.6, 2, 1.1), ("sofa", 9, 3.3, 3, 1.1), ("plant", 12, 5.6, 0.7, 0.7)],
        roof_kind="pitched_blue"),
    "apartamentos": dict(
        tw=22, th=14, door_x=10, floors=[(1, 3, 20, 8)], sign="APTOS",
        pal=dict(wall="#d9cfc2", wall_d="#8e8274", floor_a="#b9a58a", floor_b="#ae9a80", joint="#8f7d66",
                 accent="#8a4a4a", roof="#7c7468", roof_d="#4e483f", sign_bg="#4a3d52", sign_fg="#f3ecff"),
        windows=[(1, 4), (6, 8), (13, 15), (17, 20)], awning=None,
        walls=[(7.3, 3.0, 0.4, 3.0), (14.3, 3.0, 0.4, 3.0)],
        furn=[("bed", 1, 3.2, 2.4, 1.7), ("table", 4, 3.6, 2, 1.1), ("bed", 8, 3.2, 2.4, 1.7), ("sofa", 11, 3.4, 3, 1.1),
              ("bed", 15, 3.2, 2.4, 1.7), ("table", 18, 3.6, 2, 1.1), ("plant", 10, 8.5, 0.7, 0.7)],
        roof_kind="flat_ac"),
    "hospital": dict(
        tw=24, th=14, door_x=11, floors=[(1, 3, 22, 8)], sign="HOSPITAL",
        pal=dict(wall="#e6eceb", wall_d="#8fa09e", floor_a="#cfdad8", floor_b="#c3d0ce", joint="#9db0ad",
                 accent="#2f9e9a", roof="#c4ced0", roof_d="#7c8c8e", sign_bg="#a82a2a", sign_fg="#fff4f0"),
        windows=[(2, 5), (6, 9), (14, 17), (18, 22)], awning=None,
        walls=[(8.0, 3.0, 0.3, 3.0), (15.0, 3.0, 0.3, 3.0)],
        furn=[("bed", 1, 3.2, 2.4, 1.7), ("bed", 4.5, 3.2, 2.4, 1.7), ("bed", 9, 3.2, 2.4, 1.7), ("bed", 12, 3.2, 2.4, 1.7),
              ("bed", 16.5, 3.2, 2.4, 1.7), ("bed", 19.5, 3.2, 2.4, 1.7), ("counter", 14, 7.4, 5, 0.9),
              ("locker", 21.8, 6.3, 0.9, 1.4), ("bench", 3, 7.6, 4, 0.8)],
        roof_kind="flat_ac"),
    "cuartel": dict(
        tw=22, th=14, door_x=10, floors=[(1, 3, 20, 8)], sign="EJERCITO",
        pal=dict(wall="#aeb59a", wall_d="#6a7258", floor_a="#8e957e", floor_b="#848b74", joint="#6a7058",
                 accent="#4f5e3a", roof="#5c6a45", roof_d="#3a4529", sign_bg="#3a4529", sign_fg="#e8efd0"),
        windows=[(2, 5), (6, 8), (13, 15), (16, 19)], awning=None,
        walls=[],
        furn=[("bunk", 1, 3.2, 3, 1.5), ("bunk", 5, 3.2, 3, 1.5), ("rack", 10, 3.1, 4, 0.9), ("rack", 15, 3.1, 4, 0.9),
              ("crate", 18.5, 5.6, 1.3, 1.1), ("table", 7, 6.4, 4, 1.1), ("crate", 1.2, 6.8, 1.3, 1.1)],
        roof_kind="camo"),
}
# cancha: terreno abierto con valla; no tiene techo.
CANCHA = dict(tw=26, th=14, door_x=12)


# ------------------------------------------------------------------ utilidades de dibujo
def new_img(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d._image = im
    return im, d


def pal_of(spec):
    return {k: C(v) for k, v in spec["pal"].items()}


def body_h(spec):
    return spec["th"] - 5


def floor_pattern(d, rect, p):
    x0, y0, x1, y1 = rect
    for ty in range(y0, y1 + 1):
        for tx in range(x0, x1 + 1):
            c = p["floor_a"] if (tx + ty) % 2 == 0 else p["floor_b"]
            R(d, tx * TS, ty * TS, tx * TS + TS - 1, ty * TS + TS - 1, c)
            d.line([(tx * TS, ty * TS), (tx * TS + TS - 1, ty * TS)], fill=p["joint"])
            d.line([(tx * TS, ty * TS), (tx * TS, ty * TS + TS - 1)], fill=p["joint"])


def back_wall(d, x0, x1, p, y_floor=3):
    R(d, T(x0), 4, T(x1) - 1, T(y_floor) - 1, p["wall"])
    for px in range(T(x0), T(x1), 32):
        d.line([(px, 4), (px, T(y_floor) - 1)], fill=shade(p["wall"], -22))
    R(d, T(x0), T(y_floor) - 13, T(x1) - 1, T(y_floor) - 11, p["accent"])
    R(d, T(x0), T(y_floor) - 10, T(x1) - 1, T(y_floor) - 1, shade(p["wall"], -26))
    R(d, T(x0), T(y_floor) - 3, T(x1) - 1, T(y_floor) - 1, p["wall_d"])


def product_dots(d, x0, y0, x1, y1, rnd):
    cols = [C("#d8362b"), C("#e8c230"), C("#3f8f5b"), C("#3f78c8"), C("#e8e0cc"), C("#c8742c")]
    for yy in range(y0, y1, 3):
        for xx in range(x0, x1, 3):
            R(d, xx, yy, xx + 1, yy + 1, rnd.choice(cols))


def draw_furn(d, kind, x, y, w, h, rnd, p):
    X0, Y0, X1, Y1 = T(x), T(y), T(x + w) - 1, T(y + h) - 1
    if kind == "shelf":
        box3d(d, x, y, w, h, C("#c9b88e"), C("#7a5a3c"), 0.5)
        product_dots(d, X0 + 2, Y0 + 2, X1 - 1, Y1 - 7, rnd)
    elif kind == "freezer":
        R(d, X0, Y0 - 4, X1, Y1, C("#dfe8ee"))
        for fx in range(X0, X1, 28):
            R(d, fx + 1, Y0 - 2, fx + 25, Y1 - 3, C("#9fc4d8"))
            R(d, fx + 3, Y0, fx + 6, Y1 - 6, C("#e8f6ff"))
            product_dots(d, fx + 9, Y0, fx + 24, Y1 - 5, rnd)
            d.rectangle([fx, Y0 - 3, fx + 26, Y1 - 2], outline=OL)
        R(d, X0, Y1 - 2, X1, Y1, C("#6a7a88"))
    elif kind == "counter":
        box3d(d, x, y, w, h, C("#cfc8b8"), C("#5a6068"), 0.5)
        R(d, X0 + 4, Y0 + 2, X0 + 14, Y0 + 8, C("#2a2e36")); R(d, X0 + 5, Y0 + 3, X0 + 13, Y0 + 5, C("#6ad0a0"))
        R(d, X1 - 12, Y0 + 3, X1 - 3, Y0 + 7, C("#e8e0cc"))
    elif kind == "crate":
        R(d, X0, Y0, X1, Y1, C("#8a6a3e")); d.rectangle([X0, Y0, X1, Y1], outline=OL)
        R(d, X0 + 1, Y0 + 1, X1 - 1, Y0 + 2, C("#b08a52"))
        d.line([(X0, Y0), (X1, Y1)], fill=C("#5a4226")); d.line([(X0, Y1), (X1, Y0)], fill=C("#5a4226"))
    elif kind == "desk":
        box3d(d, x, y, w, h, C("#b98b55"), C("#6a4a2c"), 0.5)
        R(d, X0 + 5, Y0 + 2, X0 + 14, Y0 + 8, C("#2a2e36")); R(d, X0 + 6, Y0 + 3, X0 + 13, Y0 + 6, C("#5aa8d8"))
        R(d, X1 - 14, Y0 + 4, X1 - 4, Y0 + 7, C("#eeeadc"))
    elif kind == "cell":
        R(d, X0, Y0, X1, Y1, C("#2c3038"))
        R(d, X0 + 2, Y0 + 2, X1 - 2, Y1 - 3, C("#4a4e58"))
        R(d, X0 + 4, Y0 + 5, X0 + 17, Y0 + 12, C("#7a6a52")); R(d, X0 + 4, Y0 + 5, X0 + 8, Y0 + 12, C("#d8d4c4"))
        for bx in range(X0 + 2, X1 - 1, 5):
            R(d, bx, Y0, bx + 1, Y1, C("#9aa0aa"))
        R(d, X0, Y0, X1, Y0 + 1, C("#9aa0aa")); R(d, X0, Y1 - 2, X1, Y1, C("#9aa0aa"))
        d.rectangle([X0, Y0, X1, Y1], outline=OL)
    elif kind == "rack":
        R(d, X0, Y0 - 8, X1, Y1, C("#3a3f46")); d.rectangle([X0, Y0 - 8, X1, Y1], outline=OL)
        for gx in range(X0 + 3, X1 - 6, 9):
            R(d, gx, Y0 - 5, gx + 6, Y0 - 3, C("#1e2126"))
            R(d, gx + 1, Y0 - 3, gx + 4, Y0 + 3, C("#6b4a2a")); R(d, gx, Y0 - 5, gx + 6, Y0 - 5, C("#7c8088"))
    elif kind == "locker":
        R(d, X0, Y0, X1, Y1, C("#6a7f94")); d.rectangle([X0, Y0, X1, Y1], outline=OL)
        R(d, X0 + 3, Y0 + 3, X1 - 3, Y0 + 5, C("#3a4a5a")); R(d, X1 - 4, Y0 + 12, X1 - 3, Y0 + 15, C("#e0e0d0"))
    elif kind == "bench":
        box3d(d, x, y, w, h, C("#8a6a46"), C("#5a432c"), 0.4)
    elif kind == "pew":
        box3d(d, x, y, w, h, C("#9a6c3e"), C("#5e3f24"), 0.35)
        R(d, X0 + 1, Y0, X1 - 1, Y0 + 1, C("#b8864e"))
    elif kind == "altar":
        box3d(d, x, y, w, h, C("#d6d0c2"), C("#8a8474"), 0.5)
        R(d, X0 + 6, Y0 + 2, X1 - 6, Y0 + 7, C("#8a2f2f"))
        for cx in (X0 + 3, X1 - 6):
            R(d, cx, Y0 - 4, cx + 2, Y0 + 3, C("#f0e8d0")); R(d, cx, Y0 - 6, cx + 2, Y0 - 5, C("#f4b832"))
        mx = (X0 + X1) // 2
        R(d, mx - 1, Y0 - 16, mx + 1, Y0 + 1, C("#5a3a22")); R(d, mx - 5, Y0 - 12, mx + 5, Y0 - 10, C("#5a3a22"))
    elif kind == "bed":
        box3d(d, x, y, w, h, p["accent"], shade(p["accent"], -50), 0.4)
        R(d, X0 + 2, Y0 + 2, X0 + 12, Y0 + 9, C("#f0ece0")); d.rectangle([X0 + 2, Y0 + 2, X0 + 12, Y0 + 9], outline=OL)
    elif kind == "bunk":
        box3d(d, x, y, w, h, C("#4f5e3a"), C("#2e3922"), 0.5)
        R(d, X0 + 2, Y0 + 2, X0 + 11, Y0 + 8, C("#d8d8c8")); R(d, X0 + 14, Y0 + 2, X1 - 2, Y1 - 8, C("#5f6e48"))
        R(d, X0, Y0, X0 + 1, Y1, C("#2a2e24")); R(d, X1 - 1, Y0, X1, Y1, C("#2a2e24"))
    elif kind == "table":
        box3d(d, x, y, w, h, C("#a87c4c"), C("#6a4c2c"), 0.5)
        R(d, X0 + 6, Y0 + 3, X0 + 11, Y0 + 7, C("#e8e4d6"))
    elif kind == "sofa":
        box3d(d, x, y, w, h, p["accent"], shade(p["accent"], -45), 0.5)
        R(d, X0, Y0, X1, Y0 + 5, shade(p["accent"], -20)); d.rectangle([X0, Y0, X1, Y1], outline=OL)
    elif kind == "plant":
        R(d, X0 + 1, Y0 + 5, X1 - 1, Y1, C("#8a5a3c"))
        R(d, X0, Y0, X1, Y0 + 5, C("#5a7a3c")); R(d, X0 + 2, Y0 - 2, X1 - 2, Y0 + 2, C("#7a9a4c"))


def facade(d, rnd, spec, p, roof=False):
    tw, th = spec["tw"], spec["th"]
    W = tw * TS
    fy = body_h(spec)
    Y0 = fy * TS
    R(d, 0, Y0, W - 1, Y0 + 3 * TS - 1, p["wall"])
    R(d, 0, Y0, W - 1, Y0 + 2, shade(p["wall"], 24))
    R(d, 0, Y0 + 3 * TS - 5, W - 1, Y0 + 3 * TS - 1, p["wall_d"])
    R(d, 0, Y0 + 20, W - 1, Y0 + 22, p["accent"])
    for (a, b) in spec["windows"]:
        wx0, wx1 = T(a), T(b)
        R(d, wx0, Y0 + 8, wx1, Y0 + 2 * TS + 8, C("#2c3a48"))
        R(d, wx0 + 2, Y0 + 10, wx1 - 2, Y0 + 2 * TS + 6, C("#7fa6c0"))
        for k in range(wx0 + 4, wx1 - 4, 12):
            d.line([(k, Y0 + 10), (k - 7, Y0 + 2 * TS + 6)], fill=C("#cfe6f2"))
        if (b - a) >= 3:
            d.line([((wx0 + wx1) // 2, Y0 + 10), ((wx0 + wx1) // 2, Y0 + 2 * TS + 6)], fill=p["wall_d"])
        d.rectangle([wx0, Y0 + 8, wx1, Y0 + 2 * TS + 8], outline=OL)
        if rnd.random() < 0.6:
            d.line([(wx0 + 6, Y0 + 14), (wx0 + 16, Y0 + 30), (wx0 + 10, Y0 + 40)], fill=C("#e6eef2"))
    dx0, dx1 = spec["door_x"] * TS, (spec["door_x"] + 2) * TS - 1
    R(d, dx0 - 3, Y0 + 6, dx1 + 3, Y0 + 3 * TS - 1, C("#1e2630"))
    R(d, dx0, Y0 + 9, dx0 + 15, Y0 + 3 * TS - 3, shade(p["accent"], 10))
    R(d, dx0 + 16, Y0 + 9, dx1, Y0 + 3 * TS - 3, shade(p["accent"], -10))
    R(d, dx0 + 2, Y0 + 12, dx0 + 12, Y0 + 28, C("#9ac0d8")); R(d, dx0 + 18, Y0 + 12, dx1 - 2, Y0 + 28, C("#8ab0c8"))
    R(d, dx0 + 15, Y0 + 9, dx0 + 16, Y0 + 3 * TS - 3, OL)
    d.rectangle([dx0 - 3, Y0 + 6, dx1 + 3, Y0 + 3 * TS - 1], outline=OL)
    if spec.get("awning"):
        ac = C(spec["awning"])
        aw0, aw1 = dx0 - 24, dx1 + 24
        for i, xx in enumerate(range(aw0, aw1, 8)):
            R(d, xx, Y0 + 2, xx + 7, Y0 + 12, ac if i % 2 == 0 else C("#f2eada"))
        R(d, aw0, Y0 + 12, aw1, Y0 + 14, shade(ac, -50))
        d.rectangle([aw0, Y0 + 2, aw1, Y0 + 14], outline=OL)
    if spec.get("sign"):
        s = spec["sign"]
        tw_ = gp.text_w(s)
        sx = (W - (tw_ + 10)) // 2
        sy = Y0 - 12 if not spec.get("awning") else Y0 - 11
        R(d, sx, sy, sx + tw_ + 9, sy + 11, p["sign_bg"])
        d.rectangle([sx, sy, sx + tw_ + 9, sy + 11], outline=OL)
        gp.text(d._image, sx + 5, sy + 3, s, p["sign_fg"])
        R(d, sx + 2, sy + 1, sx + tw_ + 7, sy + 1, shade(p["sign_bg"], 50))
    # porche
    px0, px1 = dx0 - 8, dx1 + 8
    py = (fy + 3) * TS
    R(d, px0, py, px1, py + TS - 1, C("#b4b0a4"))
    R(d, px0 + 4, py + TS, px1 - 4, py + 2 * TS - 1, C("#a29e92"))
    for yy in (py, py + TS):
        d.line([(px0, yy), (px1, yy)], fill=C("#7a766a"))
    # manchas y enredaderas
    for _ in range(10):
        sx2 = rnd.randint(0, W - 20)
        sy2 = rnd.randint(Y0 + 24, Y0 + 3 * TS - 8)
        R(d, sx2, sy2, sx2 + rnd.randint(4, 12), sy2 + rnd.randint(1, 3), shade(p["wall"], -50))
    vines(d, rnd, [(6, Y0 + 6, 24), (W - 10, Y0 + 4, 22)])


def interior_image(spec, rnd):
    tw, th = spec["tw"], spec["th"]
    p = pal_of(spec)
    im, d = new_img(tw * TS, th * TS)
    for rect in spec["floors"]:
        floor_pattern(d, rect, p)
    back_wall(d, 1, tw - 1, p)
    for (x, y, w, h) in spec["walls"]:
        R(d, T(x), T(y), T(x + w) - 1, T(y + h) - 1, p["wall"])
        R(d, T(x + w) - 1, T(y), T(x + w) - 1, T(y + h) - 1, p["wall_d"])
        d.rectangle([T(x), T(y), T(x + w) - 1, T(y + h) - 1], outline=OL)
    for (kind, x, y, w, h) in sorted(spec["furn"], key=lambda f: f[2] + f[4]):
        draw_furn(d, kind, x, y, w, h, rnd, p)
    x0, y0, x1, y1 = spec["floors"][0]
    stains(d, rnd, [(x0 + 1, y0 + 2, x1, y1)], 6)
    for _ in range(16):
        px, py = rnd.randint(T(x0 + 1), T(x1)), rnd.randint(T(y0 + 1), T(y1))
        R(d, px, py, px + rnd.randint(2, 5), py + rnd.randint(1, 3), C("#ece8dc"))
    facade(d, rnd, spec, p)
    fh = body_h(spec) * TS
    R(d, 0, 0, tw * TS - 1, 3, p["wall_d"]); R(d, 0, 0, 3, fh, p["wall_d"]); R(d, tw * TS - 4, 0, tw * TS - 1, fh, p["wall_d"])
    R(d, 0, fh - 4, tw * TS - 1, fh - 1, p["wall_d"])
    vines(d, rnd, [(5, 8, 30), (tw * TS - 8, 10, 28)])
    return im


def roof_image(spec, rnd):
    import math
    tw, th = spec["tw"], spec["th"]
    p = pal_of(spec)
    W, fh = tw * TS, body_h(spec) * TS
    im, d = new_img(W, th * TS)
    kind = spec["roof_kind"]
    R(d, 0, 0, W - 1, fh - 1, p["roof"])
    if kind.startswith("pitched"):
        ridge = fh // 2
        for y in range(0, fh, 6):
            d.line([(0, y), (W - 1, y)], fill=p["roof_d"])
        R(d, 0, ridge - 2, W - 1, ridge + 1, shade(p["roof"], 36))
        R(d, 0, fh - 6, W - 1, fh - 1, p["roof_d"])
    elif kind == "church":
        for y in range(0, fh, 6):
            d.line([(0, y), (W - 1, y)], fill=p["roof_d"])
        R(d, W // 2 - 1, 0, W // 2 + 1, fh, shade(p["roof"], 40))
        bx = W // 2
        R(d, bx - 14, 6, bx + 14, 34, C("#d8ccb0")); d.rectangle([bx - 14, 6, bx + 14, 34], outline=OL)
        R(d, bx - 8, 12, bx + 8, 28, C("#2a2418")); R(d, bx - 3, 40, bx + 3, 56, C("#5a3a22")); R(d, bx - 8, 46, bx + 8, 50, C("#5a3a22"))
        d.rectangle([bx - 8, 12, bx + 8, 28], outline=OL)
    elif kind == "camo":
        for _ in range(60):
            cx, cy = rnd.randint(0, W), rnd.randint(0, fh)
            col = rnd.choice([C("#4a5a38"), C("#6a7a50"), C("#3a4529"), C("#7a7a4a")])
            d.ellipse([cx - 14, cy - 8, cx + 14, cy + 8], fill=col)
        R(d, 0, fh - 6, W - 1, fh - 1, p["roof_d"])
        R(d, 0, 0, W - 1, 4, p["roof_d"])
        R(d, W // 2 - 20, fh // 2 - 20, W // 2 + 20, fh // 2 + 20, C("#3a4529"))
        d.ellipse([W // 2 - 15, fh // 2 - 15, W // 2 + 15, fh // 2 + 15], outline=C("#e8efd0"))
        R(d, W // 2 - 2, fh // 2 - 11, W // 2 + 2, fh // 2 + 11, C("#e8efd0")); R(d, W // 2 - 11, fh // 2 - 2, W // 2 + 11, fh // 2 + 2, C("#e8efd0"))
    else:  # flat_ac
        R(d, 0, 0, W - 1, 5, p["roof_d"]); R(d, 0, 0, 5, fh, p["roof_d"]); R(d, W - 6, 0, W - 1, fh, p["roof_d"])
        R(d, 0, fh - 6, W - 1, fh - 1, p["roof_d"])
        for x in range(0, W, 32):
            d.line([(x, 0), (x, fh - 1)], fill=shade(p["roof"], -14))
        for (ax, ay) in ((4, 2), (tw - 8, 3), (tw // 2 - 1, 5)):
            R(d, T(ax), T(ay), T(ax) + 33, T(ay) + 29, C("#a0a4a8")); d.rectangle([T(ax), T(ay), T(ax) + 33, T(ay) + 29], outline=OL)
            cx, cy = T(ax) + 16, T(ay) + 10
            d.ellipse([cx - 9, cy - 8, cx + 9, cy + 8], fill=C("#464c54"), outline=OL)
    if spec["sign"] == "HOSPITAL":
        cx, cy = W // 2, fh // 2 + 4
        R(d, cx - 14, cy - 14, cx + 14, cy + 14, C("#f2f2f0")); d.rectangle([cx - 14, cy - 14, cx + 14, cy + 14], outline=OL)
        R(d, cx - 4, cy - 10, cx + 4, cy + 10, C("#c82f26")); R(d, cx - 10, cy - 4, cx + 10, cy + 4, C("#c82f26"))
    if kind == "pitched_blue" and spec["sign"] == "POLICIA":
        R(d, W // 2 - 12, fh // 2 - 10, W // 2 + 12, fh // 2 + 10, C("#1f3a78")); d.rectangle([W // 2 - 12, fh // 2 - 10, W // 2 + 12, fh // 2 + 10], outline=OL)
        gp.text(im, W // 2 - 3, fh // 2 - 3, "P", C("#eaf0ff"))
    stains(d, rnd, [(2, 2, spec["tw"] - 2, body_h(spec) - 1)], 4)
    for _ in range(14):
        sx, sy = rnd.randint(8, W - 12), rnd.randint(8, fh - 8)
        R(d, sx, sy, sx + rnd.randint(3, 9), sy + rnd.randint(1, 3), shade(p["roof"], -30))
    vines(d, rnd, [(8, 8, 36), (W - 12, 10, 32)])
    facade(d, rnd, spec, p, roof=True)
    return im


# ------------------------------------------------------------------ cancha
def cancha_images(rnd):
    tw, th = CANCHA["tw"], CANCHA["th"]
    W, H = tw * TS, th * TS
    im, d = new_img(W, H)
    R(d, 0, 0, W - 1, H - 1, C("#6a7a6a"))
    R(d, TS, TS, W - TS - 1, H - TS - 1, C("#3e7a5a"))
    for x in range(TS, W - TS, 32):
        R(d, x, TS, x + 15, H - TS - 1, C("#3a7054"))
    wl = C("#e8efe6")
    ix0, iy0, ix1, iy1 = TS + 6, TS + 6, W - TS - 7, H - TS - 7
    d.rectangle([ix0, iy0, ix1, iy1], outline=wl)
    mx = (ix0 + ix1) // 2
    d.line([(mx, iy0), (mx, iy1)], fill=wl)
    cy = (iy0 + iy1) // 2
    d.ellipse([mx - 20, cy - 20, mx + 20, cy + 20], outline=wl)
    for sx, sgn in ((ix0, 1), (ix1, -1)):
        d.rectangle(sorted_box(sx, cy - 28, sx + sgn * 30, cy + 28), outline=wl)
        d.rectangle(sorted_box(sx - 5 * sgn, cy - 12, sx, cy + 12), outline=C("#d8d8d0"))
        for gy in range(cy - 12, cy + 12, 4):
            d.line([(sx - sgn * 6, gy), (sx, gy)], fill=C("#b8b8b0"))
    for _ in range(40):
        gx, gy = rnd.randint(TS, W - TS), rnd.randint(TS, H - TS)
        R(d, gx, gy, gx + rnd.randint(2, 6), gy + 1, C("#6a8a4a"))
    stains(d, rnd, [(2, 2, tw - 2, th - 2)], 3)
    # valla de malla (tile de borde), con la puerta abajo
    gx0 = CANCHA["door_x"] * TS
    for x in range(tw):
        for y in (0, th - 1):
            if y == th - 1 and CANCHA["door_x"] <= x <= CANCHA["door_x"] + 1:
                continue
            fence_cell(d, x * TS, y * TS, "h")
    for y in range(1, th - 1):
        for x in (0, tw - 1):
            fence_cell(d, x * TS, y * TS, "v")
    for px, py in ((0, 0), (W - TS, 0), (0, H - TS), (W - TS, H - TS)):
        R(d, px + 6, py, px + 9, py + 15, C("#5a6068")); d.rectangle([px + 6, py, px + 9, py + 15], outline=OL)
    for gx in (gx0 - 3, gx0 + 2 * TS - 1):
        R(d, gx, (th - 1) * TS, gx + 3, th * TS - 1, C("#5a6068"))
    vines(d, rnd, [(8, 6, 26), (W - 10, 12, 24), (T(8), H - 12, 12)])
    roof = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return im, roof


def sorted_box(x0, y0, x1, y1):
    return [min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)]


def fence_cell(d, x, y, mode):
    wire, post = C("#8e969e"), C("#5a6068")
    if mode == "h":
        R(d, x, y + 5, x + 15, y + 11, C("#aab2ba", 90))
        for k in range(0, 16, 4):
            d.line([(x + k, y + 5), (x + k + 4, y + 11)], fill=wire)
            d.line([(x + k + 4, y + 5), (x + k, y + 11)], fill=wire)
        R(d, x, y + 4, x + 15, y + 5, post); R(d, x, y + 11, x + 15, y + 12, post)
    else:
        R(d, x + 5, y, x + 11, y + 15, C("#aab2ba", 90))
        for k in range(0, 16, 4):
            d.line([(x + 5, y + k), (x + 11, y + k + 4)], fill=wire)
            d.line([(x + 11, y + k), (x + 5, y + k + 4)], fill=wire)
        R(d, x + 4, y, x + 5, y + 15, post); R(d, x + 11, y, x + 12, y + 15, post)


def cancha_data():
    tw, th, dx = CANCHA["tw"], CANCHA["th"], CANCHA["door_x"]
    rows = []
    for y in range(th):
        row = ""
        for x in range(tw):
            edge = x in (0, tw - 1) or y in (0, th - 1)
            if y == th - 1 and dx <= x <= dx + 1:
                row += "p"
            elif edge:
                row += "#"
            else:
                row += "f"
        rows.append(row)
    cy = th / 2.0
    boxes = [(1.2, cy - 0.8, 0.3, 1.6), (tw - 1.5, cy - 0.8, 0.3, 1.6)]   # arcos (postes)
    return {"w": tw, "h": th, "door_x": dx, "rows": rows, "boxes": boxes}


# ------------------------------------------------------------------ datos de tiles
def tile_rows(spec, roof, inte):
    tw, th = spec["tw"], spec["th"]
    a1, a2 = roof.split()[3], inte.split()[3]
    rows = []
    fb = max(f[3] for f in spec["floors"])
    fy = body_h(spec)
    for y in range(th):
        row = ""
        for x in range(tw):
            cx, cy = x * TS + TS // 2, y * TS + TS // 2
            c = "#" if y < fy + 3 else "."
            for (x0, y0, x1, y1) in spec["floors"]:
                if x0 <= x <= x1 and y0 <= y <= y1:
                    c = "f"
                    for (_k, bx, by, bw, bh) in spec["furn"]:
                        if bx <= x + 0.5 <= bx + bw and by <= y + 0.5 <= by + bh:
                            c = "o"
            if spec["door_x"] <= x <= spec["door_x"] + 1 and fb < y < th and y < fy + 3 + 2:
                c = "p"
            row += c
        rows.append(row)
    return rows


def build(save=True):
    out_imgs, data = {}, {}
    for name, spec in SPECS.items():
        inte = interior_image(spec, random.Random(zlib.crc32(name.encode())))
        roof = roof_image(spec, random.Random(zlib.crc32(name.encode())))
        out_imgs[name] = (inte, roof)
        boxes = [tuple(w) for w in spec["walls"]] + [(x, y, w, h) for (_k, x, y, w, h) in spec["furn"]]
        data[name] = {"w": spec["tw"], "h": spec["th"], "door_x": spec["door_x"],
                      "rows": tile_rows(spec, roof, inte), "boxes": boxes}
    ci, cr = cancha_images(random.Random(11))
    out_imgs["cancha"] = (ci, cr)
    data["cancha"] = cancha_data()
    if save:
        for name, (inte, roof) in out_imgs.items():
            for nm, im in (("interior", inte), ("roof", roof)):
                big = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
                big.save(os.path.join(OUT_DIR, "%s_%s.png" % (name, nm)))
    return out_imgs, data


if __name__ == "__main__":
    imgs, data = build()
    print("edificios:", ", ".join(imgs))
    if "--preview" in sys.argv:
        pth = sys.argv[sys.argv.index("--preview") + 1]
        names = list(imgs)
        sheet = Image.new("RGBA", (1500, 1400), (70, 100, 70, 255))
        x = y = 0
        rowh = 0
        for nm in names:
            for im in imgs[nm]:
                if x + im.width * 2 > 1500:
                    x, y, rowh = 0, y + rowh + 6, 0
                big = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
                sheet.alpha_composite(big, (x, y))
                x += big.width + 6
                rowh = max(rowh, big.height)
        sheet.crop((0, 0, 1500, y + rowh)).save(pth)
