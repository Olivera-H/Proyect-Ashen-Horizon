#!/usr/bin/env python3
"""Genera las hojas de sprites de personajes y zombis de Ashen Horizon.

Uso:  python3 tools/gen_sprites.py          (escribe en assets/sprites/)
      python3 tools/gen_sprites.py --preview DIR   (ademas guarda vistas ampliadas)

Requiere Pillow (pip install pillow). Los PNG resultantes ya estan en el repo:
solo hace falta ejecutar esto si quieres cambiar los colores o las formas.
Tambien puedes abrir los PNG en Aseprite y pintarlos a mano: el juego solo
necesita que respetes el tamano de cuadro y el orden de filas (ver ANIMS).

Cada hoja tiene 12 filas (animaciones) x 4 columnas (cuadros):
  idle_{down,up,side} (2), walk_* (4), run_* (4), attack_* (3).
'side' mira a la derecha; el juego lo voltea para mirar a la izquierda.
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sprites")

ANIMS = [
    ("idle_down", 2), ("idle_up", 2), ("idle_side", 2),
    ("walk_down", 4), ("walk_up", 4), ("walk_side", 4),
    ("run_down", 4), ("run_up", 4), ("run_side", 4),
    ("attack_down", 3), ("attack_up", 3), ("attack_side", 3),
]
COLS = 4
W, H = 24, 32          # cuadro de humanos y zombis normales
DY = 2                 # margen superior para saltos de carrera y armas levantadas
OUTLINE = (22, 17, 30)


# ------------------------------------------------------------------ colores

def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def lite(c):
    return mix(c, (255, 250, 225), 0.24)


def dark(c):
    return mix(c, (24, 12, 48), 0.36)


# ------------------------------------------------------------------- lienzo

class Frame:
    def __init__(self, w, h, dy=0):
        self.w, self.h = w, h
        self.dy = dy
        self.px = [[None] * w for _ in range(h)]

    def put(self, x, y, c):
        y += self.dy
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def clear(self, x, y):
        y += self.dy
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = None

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def srect(self, x0, y0, x1, y1, base):
        """Rectangulo con luz arriba y sombra abajo/derecha."""
        w, h = x1 - x0 + 1, y1 - y0 + 1
        if w <= 0 or h <= 0:
            return
        self.rect(x0, y0, x1, y1, base)
        if h >= 3:
            self.rect(x0, y0, x1, y0, lite(base))
        if h >= 2:
            self.rect(x0, y1, x1, y1, dark(base))
        if w >= 3:
            self.rect(x1, y0 + 1, x1, y1 - 1, dark(base))

    def line(self, x0, y0, x1, y1, c, thick=1):
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        x, y = x0, y0
        pts = []
        while True:
            pts.append((x, y))
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x += sx
            if e2 < dx:
                err += dx
                y += sy
        for (px, py) in pts:
            self.put(px, py, c)
            if thick >= 2:
                if dx >= dy:
                    self.put(px, py + 1, c)
                else:
                    self.put(px + 1, py, c)
            if thick >= 3:
                self.put(px + 1, py + 1, c)
                self.put(px - 1, py, c)
        return pts

    def opaque(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.px[y][x] is not None

    def to_image(self, shadow=None):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        out = img.load()
        if shadow:
            sx0, sx1, sy = shadow
            for yy, (a0, a1) in enumerate(((sx0 + 1, sx1 - 1), (sx0, sx1), (sx0 + 1, sx1 - 1))):
                for x in range(a0, a1 + 1):
                    if 0 <= x < self.w and 0 <= sy + yy < self.h:
                        out[x, sy + yy] = (0, 0, 0, 74)
        # contorno exterior
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if self.opaque(x + dx, y + dy):
                            out[x, y] = OUTLINE + (255,)
                            break
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is not None:
                    out[x, y] = tuple(c) + (255,)
        return img


# ---------------------------------------------------------------- especificaciones

class Spec:
    """Todo lo que distingue a un personaje de otro."""
    def __init__(self, **kw):
        self.pants = hx("3f4250")
        self.boots = hx("2c2326")
        self.leg_band = None
        self.skin = hx("d6a066")
        self.sleeve = hx("2c3e56")
        self.cuff = None
        self.head = None
        self.torso = None
        self.weapon = True
        self.arms_forward = False
        self.hunch = (0, 0)          # desplazamiento extra de la cabeza (dx, dy)
        self.arm_swing = 1.0
        self.seed = 0
        self.leg_xs = ((8, 11), (12, 15))
        self.leg_w = 4
        self.arm_x = (5, 17)
        self.__dict__.update(kw)


# ---------------------------------------------------------------- partes comunes

PIPE = hx("a9afba")
PIPE_D = hx("5d626d")
TAPE = hx("6b4a2f")


def draw_pipe(f, hx0, hy0, ang, length=7):
    import math
    a = math.radians(ang)
    x1 = hx0 + int(round(math.cos(a) * length))
    y1 = hy0 + int(round(math.sin(a) * length))
    f.line(hx0, hy0, x1, y1, PIPE, 2)
    f.put(x1, y1, PIPE_D)
    # cinta del agarre
    f.put(hx0, hy0, TAPE)
    f.put(hx0 + (1 if abs(x1 - hx0) < abs(y1 - hy0) else 0), hy0 + (0 if abs(x1 - hx0) < abs(y1 - hy0) else 1), TAPE)


def legs(f, spec, facing, pose):
    amp = pose.get("amp", 1)
    fl, fr = pose.get("fl", 0), pose.get("fr", 0)
    lift = pose.get("lift", (0, 0))
    if facing in ("down", "up"):
        sgn = 1 if facing == "down" else -1
        for ((x0, x1), fw, lf) in ((spec.leg_xs[0], fl, lift[0]), (spec.leg_xs[1], fr, lift[1])):
            bottom = 24 + fw * amp * sgn - lf
            f.srect(x0, 18, x1, bottom, spec.pants)
            if spec.leg_band:
                f.rect(x0, 21, x1, 21, spec.leg_band)
            f.srect(x0, bottom - 1, x1, bottom, spec.boots)
    else:
        stride = 3 if amp == 1 else 4
        for near, fw, lf in ((False, fr, lift[1]), (True, fl, lift[0])):
            x0 = 10 + int(fw * stride)
            x1 = x0 + spec.leg_w - 1
            bottom = 24 - lf
            pc = spec.pants if near else dark(spec.pants)
            bc = spec.boots if near else dark(spec.boots)
            f.srect(x0, 18, x1, bottom, pc)
            if spec.leg_band:
                f.rect(x0, 21, x1, 21, spec.leg_band if near else dark(spec.leg_band))
            f.srect(x0, bottom - 1, x1 + 1, bottom, bc)


def arm_vertical(f, spec, x0, y0, length, hand_h=2):
    f.srect(x0, y0, x0 + 1, y0 + length - 1, spec.sleeve)
    if spec.cuff:
        f.rect(x0, y0 + length - 1, x0 + 1, y0 + length - 1, spec.cuff)
    f.srect(x0, y0 + length, x0 + 1, y0 + length + hand_h - 1, spec.skin)
    return (x0, y0 + length + 1)


def arm_line(f, spec, sx, sy, hx0, hy0, thick=2):
    f.line(sx, sy, hx0, hy0, spec.sleeve, thick)
    f.rect(hx0, hy0, hx0 + 1, hy0 + 1, spec.skin)


def draw_entity(spec, facing, pose):
    f = Frame(W, H, DY)
    oy = pose.get("oy", 0)
    ox = pose.get("ox", 0)
    lean = pose.get("lean", 0)
    amp = pose.get("amp", 1)
    fl, fr = pose.get("fl", 0), pose.get("fr", 0)
    sgn = 1 if facing == "down" else -1
    atk = pose.get("atk")          # (hand, angulo) del brazo cercano en ataque
    hdx, hdy = spec.hunch
    carry = None

    if facing == "side":
        # brazo lejano
        if spec.arms_forward:
            f.srect(12 + lean + ox, 12 + oy, 19 + lean + ox, 13 + oy, dark(spec.sleeve))
            f.srect(19 + lean + ox, 12 + oy, 20 + lean + ox, 14 + oy, dark(spec.skin))
        else:
            ax = 11 + int(-fr * (3 if amp == 1 else 4) * spec.arm_swing) + lean
            f.srect(ax, 12 + oy, ax + 2, 16 + oy, dark(spec.sleeve))
            f.srect(ax, 17 + oy, ax + 2, 18 + oy, dark(spec.skin))
        legs(f, spec, facing, pose)
        spec.torso(f, facing, ox + lean, oy, pose, spec)
        # brazo cercano
        if atk:
            (hx0, hy0), ang = atk
            arm_line(f, spec, 12 + lean, 12 + oy, hx0, hy0)
            carry = (hx0, hy0, ang)
        elif spec.arms_forward:
            reach = pose.get("reach", 0)
            f.srect(12 + lean + ox, 13 + oy, 19 + lean + ox + reach, 14 + oy, spec.sleeve)
            f.srect(19 + lean + ox + reach, 12 + oy, 21 + lean + ox + reach, 15 + oy, spec.skin)
            f.put(22 + lean + ox + reach, 15 + oy, (230, 226, 205))
        else:
            ax = 11 + int(-fl * (3 if amp == 1 else 4) * spec.arm_swing) + lean
            f.srect(ax, 12 + oy, ax + 2, 16 + oy, spec.sleeve)
            if spec.cuff:
                f.rect(ax, 16 + oy, ax + 2, 16 + oy, spec.cuff)
            f.srect(ax, 17 + oy, ax + 2, 18 + oy, spec.skin)
            carry = (ax + 2, 18 + oy, 62)
        spec.head(f, facing, ox + lean + hdx, oy + hdy, pose, spec)
    else:
        legs(f, spec, facing, pose)
        # brazos
        if atk:
            (hx0, hy0), ang = atk
            arm_vertical(f, spec, spec.arm_x[0], 11 + oy, 5)          # brazo izquierdo quieto
            arm_line(f, spec, 17, 12 + oy, hx0, hy0)
            carry = (hx0, hy0, ang)
        elif spec.arms_forward:
            up = pose.get("armup", 0)
            if facing == "down":
                for x0 in (spec.arm_x[0] - 1, spec.arm_x[1] + 1):
                    f.srect(x0, 12 + oy - up, x0 + 1, 14 + oy - up, spec.sleeve)
                    f.srect(x0 - 1 + (1 if x0 > 12 else 0), 15 + oy - up, x0 + 2, 17 + oy - up, spec.skin)
                    f.put(x0 + (0 if x0 < 12 else 1), 18 + oy - up, (230, 226, 205))
            else:
                for x0 in spec.arm_x:
                    f.srect(x0, 11 + oy, x0 + 1, 16 + oy, spec.sleeve)
        else:
            a = int(spec.arm_swing * amp)
            dl = -fl * a * sgn
            dr = -fr * a * sgn
            arm_vertical(f, spec, spec.arm_x[0], 11 + oy + dl, 5)
            hand = arm_vertical(f, spec, spec.arm_x[1], 11 + oy + dr, 5)
            carry = (18, 17 + oy + dr, 90 if facing == "down" else 95)
        spec.torso(f, facing, ox, oy, pose, spec)
        spec.head(f, facing, ox + hdx, oy + hdy, pose, spec)

    if spec.weapon and carry:
        cx, cy, ang = carry
        if not atk:
            if facing == "side":
                draw_pipe(f, cx, cy, 58, 6)
            elif facing == "down":
                draw_pipe(f, 19, cy, 82, 6)
            else:
                draw_pipe(f, 19, cy, 100, 5)
        else:
            draw_pipe(f, cx, cy, ang, 7)
    return f.to_image(shadow=(7, 16, 24 + DY))


# ---------------------------------------------------------------- poses

def walk_poses(run=False):
    amp = 2 if run else 1
    seq = [(1, -1, 0, (0, 1)), (0, 0, -1, (0, 0)), (-1, 1, 0, (1, 0)), (0, 0, -1, (0, 0))]
    out = []
    for fl, fr, oy, lift in seq:
        out.append({"fl": fl, "fr": fr, "oy": oy * (2 if run and oy else 1), "amp": amp, "lift": lift,
                    "lean": 1 if run else 0})
    return out


def idle_poses():
    return [{"oy": 0}, {"oy": 1, "legs_fixed": True}]


def attack_poses(facing):
    if facing == "side":
        return [
            {"oy": 0, "lean": -1, "atk": ((10, 6), -125), "fl": 0, "fr": 0},
            {"oy": 0, "lean": 1, "atk": ((15, 12), -8), "fl": 1, "fr": -1},
            {"oy": 1, "lean": 2, "atk": ((15, 15), 55), "fl": 1, "fr": -1},
        ]
    if facing == "down":
        return [
            {"oy": 0, "atk": ((18, 8), -90)},
            {"oy": 0, "atk": ((14, 15), 130)},
            {"oy": 1, "atk": ((10, 18), 160)},
        ]
    return [
        {"oy": 0, "atk": ((18, 8), -90)},
        {"oy": 0, "atk": ((17, 9), -135)},
        {"oy": 0, "atk": ((14, 8), -170)},
    ]


def build_sheet(spec, poses_fn=None, frame_size=(W, H), draw=None):
    fw, fh = frame_size
    draw = draw or draw_entity
    sheet = Image.new("RGBA", (COLS * fw, len(ANIMS) * fh), (0, 0, 0, 0))
    for row, (name, n) in enumerate(ANIMS):
        kind, facing = name.split("_")
        if kind == "idle":
            poses = idle_poses()
        elif kind == "walk":
            poses = walk_poses(False)
        elif kind == "run":
            poses = walk_poses(True)
        else:
            poses = attack_poses(facing)
        if poses_fn:
            poses = poses_fn(kind, facing, poses)
        for col in range(n):
            sheet.alpha_composite(draw(spec, facing, poses[col]), (col * fw, row * fh))
    return sheet


# ================================================================= PROTAGONISTAS

RED = hx("c8342a")
YEL = hx("f1c40f")
NAVY = hx("2c3e56")
SK_M = hx("d6a066")
SK_L = hx("e9be98")


PACK = hx("55603f")
PACK_L = hx("6d7a50")


def backpack(f, facing, ox, oy, color):
    if facing == "up":
        f.srect(8 + ox, 12 + oy, 15 + ox, 18 + oy, color)
        f.rect(8 + ox, 14 + oy, 15 + ox, 14 + oy, dark(color))      # solapa
        f.rect(11 + ox, 14 + oy, 12 + ox, 15 + oy, hx("b8bcc4"))     # hebilla
    elif facing == "side":
        f.srect(5 + ox, 12 + oy, 9 + ox, 18 + oy, color)
        f.rect(5 + ox, 14 + oy, 9 + ox, 14 + oy, dark(color))


def torso_mateo(f, facing, ox, oy, pose, spec):
    if facing == "side":
        backpack(f, facing, ox, oy, PACK)
    if facing in ("down", "up"):
        f.srect(7 + ox, 11 + oy, 16 + ox, 18 + oy, NAVY)
        f.rect(7 + ox, 15 + oy, 16 + ox, 15 + oy, YEL)               # banda reflectante
        f.rect(7 + ox, 18 + oy, 16 + ox, 18 + oy, hx("5a3e2a"))     # cinturon
        if facing == "down":
            f.rect(10 + ox, 11 + oy, 13 + ox, 11 + oy, dark(SK_M))  # cuello
            f.rect(7 + ox, 11 + oy, 8 + ox, 11 + oy, YEL)
            f.rect(15 + ox, 11 + oy, 16 + ox, 11 + oy, YEL)
            f.put(11 + ox, 18 + oy, hx("b8bcc4"))
            f.put(12 + ox, 18 + oy, hx("b8bcc4"))
            f.rect(11 + ox, 12 + oy, 12 + ox, 14 + oy, dark(NAVY))  # abertura de la chaqueta
        else:
            backpack(f, facing, ox, oy, PACK)
            f.rect(7 + ox, 11 + oy, 16 + ox, 11 + oy, YEL)          # hombreras reflectantes
    else:
        f.srect(8 + ox, 11 + oy, 15 + ox, 18 + oy, NAVY)
        f.rect(8 + ox, 15 + oy, 15 + ox, 15 + oy, YEL)
        f.rect(8 + ox, 18 + oy, 15 + ox, 18 + oy, hx("5a3e2a"))
        f.put(14 + ox, 18 + oy, hx("b8bcc4"))


def head_mateo(f, facing, ox, oy, pose, spec):
    if facing == "down":
        f.srect(8 + ox, 6 + oy, 15 + ox, 10 + oy, SK_M)
        f.rect(8 + ox, 10 + oy, 15 + ox, 10 + oy, dark(SK_M))        # barba
        f.srect(8 + ox, 2 + oy, 15 + ox, 5 + oy, RED)
        f.rect(7 + ox, 6 + oy, 16 + ox, 6 + oy, hx("8e2a22"))        # ala del casco
        f.rect(11 + ox, 3 + oy, 12 + ox, 4 + oy, YEL)                # insignia
        f.put(10 + ox, 8 + oy, (25, 20, 28))
        f.put(13 + ox, 8 + oy, (25, 20, 28))
        f.put(11 + ox, 10 + oy, hx("7a3a2a"))
        f.put(12 + ox, 10 + oy, hx("7a3a2a"))
        f.clear(8 + ox, 2 + oy)
        f.clear(15 + ox, 2 + oy)
    elif facing == "up":
        f.srect(8 + ox, 2 + oy, 15 + ox, 8 + oy, RED)
        f.clear(8 + ox, 2 + oy)
        f.clear(15 + ox, 2 + oy)
        f.rect(8 + ox, 5 + oy, 15 + ox, 5 + oy, YEL)
        f.rect(7 + ox, 8 + oy, 16 + ox, 9 + oy, hx("8e2a22"))        # cubrenuca
        f.rect(9 + ox, 10 + oy, 14 + ox, 10 + oy, dark(SK_M))
    else:
        f.srect(9 + ox, 6 + oy, 15 + ox, 10 + oy, SK_M)
        f.rect(9 + ox, 10 + oy, 14 + ox, 10 + oy, dark(SK_M))
        f.put(16 + ox, 9 + oy, SK_M)                                 # nariz
        f.srect(7 + ox, 2 + oy, 15 + ox, 5 + oy, RED)
        f.rect(7 + ox, 4 + oy, 15 + ox, 4 + oy, YEL)
        f.rect(10 + ox, 6 + oy, 17 + ox, 6 + oy, hx("8e2a22"))       # ala
        f.rect(7 + ox, 6 + oy, 9 + ox, 9 + oy, hx("8e2a22"))         # cubrenuca
        f.put(13 + ox, 8 + oy, (25, 20, 28))
        f.clear(7 + ox, 2 + oy)
        f.clear(15 + ox, 2 + oy)


MATEO = Spec(
    pants=hx("464a58"), boots=hx("2c2326"), leg_band=YEL, skin=SK_M, sleeve=NAVY, cuff=YEL,
    head=head_mateo, torso=torso_mateo,
)

HAIR_L = hx("4a2e1e")
COAT = hx("e4e6ea")
BLUE = hx("2e86c1")


PACK_LENA = hx("7a6a55")


def torso_lena(f, facing, ox, oy, pose, spec):
    if facing == "side":
        backpack(f, facing, ox, oy, PACK_LENA)
    if facing in ("down", "up"):
        f.srect(7 + ox, 11 + oy, 16 + ox, 18 + oy, COAT)
        if facing == "down":
            f.rect(10 + ox, 12 + oy, 13 + ox, 17 + oy, BLUE)           # camiseta azul
            f.rect(10 + ox, 12 + oy, 13 + ox, 12 + oy, dark(BLUE))
            f.put(12 + ox, 14 + oy, YEL)                               # credencial
            f.put(12 + ox, 15 + oy, YEL)
            f.rect(10 + ox, 11 + oy, 13 + ox, 11 + oy, dark(SK_L))
        else:
            backpack(f, facing, ox, oy, PACK_LENA)
        f.rect(7 + ox, 18 + oy, 16 + ox, 18 + oy, hx("7a5a3e"))
    else:
        f.srect(8 + ox, 11 + oy, 15 + ox, 18 + oy, COAT)
        f.rect(13 + ox, 12 + oy, 15 + ox, 17 + oy, BLUE)
        f.rect(8 + ox, 18 + oy, 15 + ox, 18 + oy, hx("7a5a3e"))


def head_lena(f, facing, ox, oy, pose, spec):
    sway = pose.get("tail", 0)
    if facing == "down":
        f.srect(8 + ox, 5 + oy, 15 + ox, 10 + oy, SK_L)
        f.srect(8 + ox, 2 + oy, 15 + ox, 5 + oy, HAIR_L)
        f.rect(7 + ox, 3 + oy, 7 + ox, 9 + oy, HAIR_L)
        f.rect(16 + ox, 3 + oy, 16 + ox, 9 + oy, HAIR_L)
        f.put(8 + ox, 6 + oy, HAIR_L)
        f.put(15 + ox, 6 + oy, HAIR_L)
        f.rect(9 + ox, 6 + oy, 11 + ox, 6 + oy, HAIR_L)                # flequillo
        f.put(10 + ox, 8 + oy, (25, 20, 28))
        f.put(13 + ox, 8 + oy, (25, 20, 28))
        f.put(11 + ox, 10 + oy, hx("a8584e"))
        f.put(12 + ox, 10 + oy, hx("a8584e"))
        f.clear(8 + ox, 2 + oy)
        f.clear(15 + ox, 2 + oy)
    elif facing == "up":
        f.srect(8 + ox, 2 + oy, 15 + ox, 10 + oy, HAIR_L)
        f.put(7 + ox, 5 + oy, HAIR_L)
        f.put(16 + ox, 5 + oy, HAIR_L)
        f.rect(7 + ox, 6 + oy, 7 + ox, 9 + oy, HAIR_L)
        f.rect(16 + ox, 6 + oy, 16 + ox, 9 + oy, HAIR_L)
        f.clear(8 + ox, 2 + oy)
        f.clear(15 + ox, 2 + oy)
        for (hxp, hyp) in ((10, 4), (13, 5), (11, 8), (14, 8)):        # mechones
            f.put(hxp + ox, hyp + oy, lite(HAIR_L))
        f.rect(11 + ox, 9 + oy, 12 + ox, 9 + oy, BLUE)                  # liga
        f.rect(11 + ox, 10 + oy, 12 + ox, 13 + oy + sway, HAIR_L)      # coleta
        f.put(11 + ox, 14 + oy + sway, dark(HAIR_L))
        f.put(12 + ox, 14 + oy + sway, dark(HAIR_L))
    else:
        f.srect(9 + ox, 5 + oy, 15 + ox, 10 + oy, SK_L)
        f.put(16 + ox, 9 + oy, SK_L)
        f.srect(7 + ox, 2 + oy, 15 + ox, 5 + oy, HAIR_L)
        f.rect(7 + ox, 5 + oy, 10 + ox, 10 + oy, HAIR_L)
        f.rect(11 + ox, 5 + oy, 14 + ox, 5 + oy, HAIR_L)
        f.rect(5 + ox, 7 + oy, 6 + ox, 12 + oy + sway, HAIR_L)         # coleta
        f.put(5 + ox, 13 + oy + sway, dark(HAIR_L))
        f.put(7 + ox, 7 + oy, BLUE)
        f.put(13 + ox, 8 + oy, (25, 20, 28))
        f.put(14 + ox, 10 + oy, hx("a8584e"))
        f.clear(7 + ox, 2 + oy)
        f.clear(15 + ox, 2 + oy)


LENA = Spec(
    pants=hx("3b5775"), boots=hx("6b4630"), skin=SK_L, sleeve=COAT, head=head_lena, torso=torso_lena,
)



# ================================================================= ZOMBIS

BLOOD = hx("761818")
BLOOD_L = hx("aa2622")
BONE = hx("ded6b8")
GLOW = hx("e8d44d")
TEETH = hx("ebe6cd")
EYE_DK = (26, 20, 22)
Z_SKIN = hx("7c9666")
Z_PALE = hx("aab296")


def zhair(f, x0, x1, y, color, seed, density=3):
    """Pelo ralo: deja huecos para que se vea el cuero cabelludo."""
    for x in range(x0, x1 + 1):
        if (x * 7 + seed + y * 3) % density != 0:
            f.put(x, y, color)


def torso_walker(f, facing, ox, oy, pose, spec):
    sh = spec.shirt
    if facing in ("down", "up"):
        f.srect(7 + ox, 11 + oy, 16 + ox, 18 + oy, sh)
        d = spec.deco
        if d == "vest":
            f.rect(9 + ox, 11 + oy, 14 + ox, 18 + oy, hx("d9772b"))
            f.rect(9 + ox, 14 + oy, 14 + ox, 14 + oy, hx("e8d44d"))
            f.rect(9 + ox, 17 + oy, 14 + ox, 17 + oy, hx("e8d44d"))
            f.rect(14 + ox, 12 + oy, 14 + ox, 18 + oy, dark(hx("d9772b")))
        elif d == "office" and facing == "down":
            f.rect(10 + ox, 11 + oy, 13 + ox, 11 + oy, hx("e8e4d8"))
            f.rect(11 + ox, 12 + oy, 12 + ox, 16 + oy, hx("26262f"))
        elif d == "hoodie":
            f.rect(9 + ox, 15 + oy, 14 + ox, 17 + oy, dark(sh))
            if facing == "down":
                f.put(10 + ox, 12 + oy, lite(sh))
                f.put(13 + ox, 12 + oy, lite(sh))
            else:
                f.rect(8 + ox, 10 + oy, 15 + ox, 11 + oy, dark(sh))       # capucha caida
        elif d == "scrubs":
            if facing == "down":
                f.rect(10 + ox, 11 + oy, 13 + ox, 11 + oy, Z_SKIN)
                f.rect(11 + ox, 12 + oy, 12 + ox, 12 + oy, Z_SKIN)
            f.rect(8 + ox, 15 + oy, 10 + ox, 16 + oy, dark(sh))           # bolsillo
        # camisa rota y sangre
        for (bx, by, bw, bh) in spec.blood:
            f.rect(bx + ox, by + oy, bx + bw - 1 + ox, by + bh - 1 + oy, BLOOD)
            f.put(bx + ox, by + bh + oy, BLOOD)
        for bx in (9, 13):
            f.put(bx + ox, 18 + oy, Z_SKIN)                               # panza al aire
        f.put(15 + ox, 18 + oy, Z_SKIN)
        f.rect(7 + ox, 18 + oy, 16 + ox, 18 + oy, dark(spec.pants)) if False else None
    else:
        f.srect(8 + ox, 11 + oy, 15 + ox, 18 + oy, sh)
        if spec.deco == "vest":
            f.rect(10 + ox, 11 + oy, 14 + ox, 18 + oy, hx("d9772b"))
            f.rect(10 + ox, 14 + oy, 14 + ox, 14 + oy, hx("e8d44d"))
        elif spec.deco == "office":
            f.rect(14 + ox, 12 + oy, 15 + ox, 15 + oy, hx("26262f"))
        elif spec.deco == "hoodie":
            f.rect(6 + ox, 10 + oy, 9 + ox, 14 + oy, dark(sh))
        for (bx, by, bw, bh) in spec.blood:
            f.rect(min(bx, 12) + ox, by + oy, min(bx, 12) + bw - 1 + ox, by + bh - 1 + oy, BLOOD)
        f.put(9 + ox, 18 + oy, Z_SKIN)
        f.put(13 + ox, 18 + oy, Z_SKIN)


def head_walker(f, facing, ox, oy, pose, spec):
    skin = spec.skin
    open_m = pose.get("mouth", False)
    if facing == "down":
        f.srect(8 + ox, 3 + oy, 15 + ox, 10 + oy, skin)
        zhair(f, 8 + ox, 15 + ox, 3 + oy, spec.hair, spec.seed)
        zhair(f, 8 + ox, 15 + ox, 4 + oy, spec.hair, spec.seed + 1, 4)
        f.put(7 + ox, 5 + oy, spec.hair)
        f.rect(9 + ox, 6 + oy, 10 + ox, 7 + oy, EYE_DK)
        f.rect(13 + ox, 6 + oy, 14 + ox, 7 + oy, EYE_DK)
        f.put(10 + ox, 7 + oy, GLOW)
        f.put(13 + ox, 6 + oy, GLOW)
        f.rect(8 + ox, 8 + oy, 9 + ox, 8 + oy, BLOOD_L)                    # herida en la mejilla
        my = 9 if open_m else 9
        f.rect(10 + ox, my + oy, 13 + ox, my + 1 + oy + (1 if open_m else 0), BLOOD)
        f.put(10 + ox, my + oy, TEETH)
        f.put(12 + ox, my + oy, TEETH)
        f.put(12 + ox, 11 + oy + (1 if open_m else 0), BLOOD)               # baba de sangre
        for bx in range(8, 16):                                               # sombra bajo la mandibula
            pass
    elif facing == "up":
        f.srect(8 + ox, 3 + oy, 15 + ox, 10 + oy, skin)
        for y, dens in ((3, 5), (4, 4), (5, 3), (6, 3)):
            zhair(f, 8 + ox, 15 + ox, y + oy, spec.hair, spec.seed + y, dens)
        f.rect(11 + ox, 6 + oy, 12 + ox, 7 + oy, BLOOD_L)                   # herida
        f.put(11 + ox, 7 + oy, BLOOD)
        f.rect(9 + ox, 10 + oy, 14 + ox, 10 + oy, dark(skin))
        f.rect(7 + ox, 6 + oy, 7 + ox, 8 + oy, skin)                        # orejas
        f.rect(16 + ox, 6 + oy, 16 + ox, 8 + oy, skin)
        f.clear(8 + ox, 3 + oy)
        f.clear(15 + ox, 3 + oy)
    else:
        f.srect(9 + ox, 3 + oy, 16 + ox, 10 + oy, skin)
        zhair(f, 9 + ox, 14 + ox, 3 + oy, spec.hair, spec.seed)
        f.rect(9 + ox, 4 + oy, 11 + ox, 7 + oy, spec.hair)
        f.rect(14 + ox, 6 + oy, 15 + ox, 7 + oy, EYE_DK)
        f.put(15 + ox, 7 + oy, GLOW)
        f.put(17 + ox, 8 + oy, skin)                                         # nariz
        f.rect(14 + ox, 9 + oy, 16 + ox, 10 + oy + (1 if open_m else 0), BLOOD)
        f.put(15 + ox, 9 + oy, TEETH)
        f.put(13 + ox, 8 + oy, BLOOD_L)


def torso_runner(f, facing, ox, oy, pose, spec):
    skin = spec.skin
    if facing in ("down", "up"):
        f.srect(8 + ox, 11 + oy, 15 + ox, 18 + oy, skin)
        if facing == "down":
            for y in (13, 15):                                               # costillas
                for x in (9, 10, 12, 13, 14):
                    f.put(x + ox, y + oy, dark(skin))
            f.rect(11 + ox, 12 + oy, 11 + ox, 17 + oy, dark(skin))
            f.put(12 + ox, 16 + oy, BLOOD_L)
        else:
            for y in (12, 14, 16):                                           # columna
                f.put(11 + ox, y + oy, dark(skin))
                f.put(12 + ox, y + oy, dark(skin))
            f.rect(9 + ox, 12 + oy, 10 + ox, 13 + oy, dark(skin))            # omoplatos
            f.rect(13 + ox, 12 + oy, 14 + ox, 13 + oy, dark(skin))
        f.srect(8 + ox, 17 + oy, 15 + ox, 18 + oy, spec.shorts)              # shorts rotos
        f.put(10 + ox, 18 + oy, skin)
        f.put(14 + ox, 18 + oy, skin)
    else:
        f.srect(9 + ox, 11 + oy, 15 + ox, 18 + oy, skin)
        for y in (13, 15):
            for x in (12, 13, 14):
                f.put(x + ox, y + oy, dark(skin))
        f.srect(9 + ox, 17 + oy, 15 + ox, 18 + oy, spec.shorts)


def head_runner(f, facing, ox, oy, pose, spec):
    skin = spec.skin
    eye = hx("ff4a38")
    if facing == "down":
        f.srect(9 + ox, 3 + oy, 14 + ox, 10 + oy, skin)
        for (x, y) in ((9, 2), (11, 1), (12, 2), (14, 2), (8, 4), (15, 4)):    # mechones sueltos
            f.put(x + ox, y + oy, spec.hair)
        f.rect(9 + ox, 5 + oy, 10 + ox, 6 + oy, EYE_DK)
        f.rect(13 + ox, 5 + oy, 14 + ox, 6 + oy, EYE_DK)
        f.put(10 + ox, 6 + oy, eye)
        f.put(13 + ox, 6 + oy, eye)
        f.rect(10 + ox, 8 + oy, 13 + ox, 10 + oy, BLOOD)                      # grito
        f.rect(10 + ox, 8 + oy, 13 + ox, 8 + oy, TEETH)
        f.put(11 + ox, 10 + oy, TEETH)
        f.put(13 + ox, 10 + oy, BLOOD_L)
    elif facing == "up":
        f.srect(9 + ox, 3 + oy, 14 + ox, 10 + oy, skin)
        for (x, y) in ((9, 3), (10, 4), (13, 3), (14, 5), (11, 6), (12, 8)):
            f.put(x + ox, y + oy, spec.hair)
        f.rect(8 + ox, 6 + oy, 8 + ox, 7 + oy, skin)
        f.rect(15 + ox, 6 + oy, 15 + ox, 7 + oy, skin)
    else:
        f.srect(10 + ox, 3 + oy, 16 + ox, 10 + oy, skin)
        for (x, y) in ((10, 2), (12, 1), (9, 4), (9, 6)):
            f.put(x + ox, y + oy, spec.hair)
        f.rect(14 + ox, 5 + oy, 15 + ox, 6 + oy, EYE_DK)
        f.put(15 + ox, 6 + oy, eye)
        f.put(17 + ox, 8 + oy, skin)
        f.rect(14 + ox, 8 + oy, 16 + ox, 10 + oy, BLOOD)
        f.rect(14 + ox, 8 + oy, 16 + ox, 8 + oy, TEETH)


def zombie_poses(kind, facing, poses):
    """Modifica las poses base para que los zombis se muevan distinto a un humano."""
    if kind == "idle":
        return [{"oy": 0, "ox": 0}, {"oy": 1, "ox": 1 if facing != "side" else -1}]
    if kind in ("walk", "run"):
        out = []
        for i, p in enumerate(poses):
            q = dict(p)
            q["ox"] = [-1, 0, 1, 0][i] if facing != "side" else 0
            q["armup"] = [0, 1, 0, 1][i]
            q["reach"] = [0, 1, 0, 1][i]
            q["lean"] = 0
            q["oy"] = 0 if i % 2 == 0 else 1
            q["amp"] = 1
            # cojera: la pierna izquierda se arrastra
            q["lift"] = (0, 0)
            out.append(q)
        return out
    return [
        {"oy": 1, "lean": -1, "armup": 0, "reach": 0, "mouth": True},
        {"oy": -1, "lean": 3, "armup": 3, "reach": 2, "mouth": True},
        {"oy": 1, "lean": 1, "armup": 1, "reach": 1, "mouth": True},
    ]


def runner_poses(kind, facing, poses):
    if kind == "idle":
        return [{"oy": 0, "lean": 1}, {"oy": 1, "lean": 1}]
    if kind in ("walk", "run"):
        out = []
        for i, p in enumerate(poses):
            q = dict(p)
            q["lean"] = 2 if kind == "run" else 1
            q["amp"] = 2
            q["oy"] = [0, -1, 0, -1][i] * 1
            out.append(q)
        return out
    return [
        {"oy": 1, "lean": -1, "armup": 0, "mouth": True, "fl": 1, "fr": -1, "amp": 2},
        {"oy": -1, "lean": 3, "armup": 2, "mouth": True, "fl": -1, "fr": 1, "amp": 2},
        {"oy": 0, "lean": 2, "armup": 1, "mouth": True, "fl": 0, "fr": 0, "amp": 2},
    ]


def walker(shirt, pants, deco, hair, seed, blood, skin=Z_SKIN):
    return Spec(
        pants=pants, boots=hx("2a2622"), skin=skin, sleeve=shirt, shirt=shirt, deco=deco, hair=hair,
        seed=seed, blood=blood, head=head_walker, torso=torso_walker, weapon=False, arms_forward=True,
        hunch=(0, 1),
    )


WALKERS = [
    walker(hx("b9b7aa"), hx("4a4c58"), "office", hx("3a3326"), 1, [(8, 13, 3, 3)]),
    walker(hx("5f7468"), hx("3b5272"), "hoodie", hx("2a2420"), 2, [(12, 12, 3, 2)]),
    walker(hx("78aeb4"), hx("5d9096"), "scrubs", hx("55402c"), 3, [(9, 13, 4, 3), (13, 16, 2, 1)]),
    walker(hx("767a80"), hx("5a4632"), "vest", hx("30291f"), 4, [(8, 15, 2, 2)]),
]


def runner(skin, shorts, hair):
    return Spec(
        pants=hx("4a2f2f") if False else shorts, boots=hx("2a2622"), skin=skin, sleeve=skin, shorts=shorts,
        hair=hair, head=head_runner, torso=torso_runner, weapon=False, arms_forward=False,
        leg_xs=((9, 11), (12, 14)), leg_w=3, arm_x=(6, 16), arm_swing=1.6,
    )


RUNNERS = [
    runner(Z_PALE, hx("93302c"), hx("322a24")),
    runner(hx("a2a98e"), hx("3b4b6e"), hx("1f1a18")),
]
for _r in RUNNERS:
    _r.pants = _r.shorts


# ---------------------------------------------------------------- tanque

TW, TH, TDY = 40, 44, 4
T_SKIN = hx("7b8768")
T_SKIN2 = hx("6a5578")
T_BOIL = hx("c1c35c")
T_BOIL2 = hx("9a62a8")
T_PANTS = hx("604c3a")


def boil(f, cx, cy, r, color):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r // 2:
                f.put(x, y, color)
    f.put(cx + 1, cy + 1, dark(color))
    f.put(cx - 1, cy - 1, lite(lite(color)))


def fist(f, x0, y0, x1, y1):
    f.srect(x0, y0, x1, y1, T_SKIN)
    for x in range(x0 + 2, x1 - 1, 2):
        f.put(x, y0 + 1, dark(T_SKIN))
        f.put(x, y0 + 2, dark(T_SKIN))
    f.rect(x0 + 1, y1 - 1, x1 - 1, y1 - 1, dark(T_SKIN2))


def big_arm(f, sx, sy, fx, fy, width, fist_w, fist_h, edge=False):
    for t in range(width):
        f.line(sx + t, sy, fx - width // 2 + t, fy, T_SKIN)
    f.line(sx + width - 1, sy, fx - width // 2 + width - 1, fy, dark(T_SKIN))
    f.line(sx, sy, fx - width // 2, fy, lite(T_SKIN))
    fist(f, fx - fist_w // 2, fy, fx - fist_w // 2 + fist_w - 1, fy + fist_h - 1)
    if edge:
        f.line(sx - 1, sy + 1, fx - width // 2 - 1, fy, OUTLINE)


def draw_tank(spec, facing, pose):
    f = Frame(TW, TH, TDY)
    oy, lean = pose.get("oy", 0), pose.get("lean", 0)
    fl, fr = pose.get("fl", 0), pose.get("fr", 0)
    arm = pose.get("arm", "walk")
    sgn = 1 if facing == "down" else -1
    sw = int(fl * 2)
    # ---- piernas
    if facing in ("down", "up"):
        for (x0, fw) in ((12, fl), (21, fr)):
            bottom = 36 + fw * sgn
            f.srect(x0, 25, x0 + 6, 32, T_PANTS)
            for x in (x0 + 1, x0 + 4):
                f.clear(x, 32 + 0) if False else None
            f.srect(x0, 33, x0 + 6, bottom, T_SKIN)
            f.srect(x0 - 1, bottom - 1, x0 + 7, bottom, dark(T_SKIN))
    else:
        for near, fw in ((False, fr), (True, fl)):
            x0 = (19 if not near else 14) + int(fw * 4)
            c = T_PANTS if near else dark(T_PANTS)
            f.srect(x0, 25, x0 + 6, 32, c)
            f.srect(x0, 33, x0 + 6, 36, T_SKIN if near else dark(T_SKIN))
            f.srect(x0, 35, x0 + 8, 36, dark(T_SKIN))
    # ---- torso y cabeza
    if facing in ("down", "up"):
        for y in range(11, 26):
            k = (y - 11) // 4
            f.rect(9 + k, y + oy, 30 - k, y + oy, T_SKIN)
        for y in range(11, 26):
            k = (y - 11) // 4
            f.put(30 - k, y + oy, dark(T_SKIN))
            f.put(9 + k, y + oy, lite(T_SKIN))
        f.rect(9, 11 + oy, 30, 11 + oy, lite(T_SKIN))
        f.rect(12, 25 + oy, 27, 25 + oy, dark(T_SKIN))
        if facing == "down":
            for x in range(14, 26):                                      # cicatriz con puntos
                f.put(x, 17 + oy, dark(T_SKIN))
            for x in range(15, 26, 3):
                f.rect(x, 16 + oy, x, 18 + oy, dark(T_SKIN))
            f.rect(16, 13 + oy, 17, 14 + oy, BONE)                       # costilla expuesta
            f.put(23, 22 + oy, dark(T_SKIN))
            boil(f, 13, 15 + oy, 1, T_BOIL)
            boil(f, 26, 15 + oy, 2, T_BOIL2)
            boil(f, 20, 21 + oy, 1, T_BOIL)
        else:
            f.rect(19, 12 + oy, 20, 24 + oy, dark(T_SKIN))               # columna
            for y in range(13, 24, 3):
                f.rect(18, y + oy, 21, y + oy, BONE)
            boil(f, 13, 16 + oy, 2, T_BOIL2)
            boil(f, 27, 19 + oy, 1, T_BOIL)
        f.rect(10, 8 + oy, 10, 10 + oy, BONE)                            # pinchos de hueso
        f.put(11, 9 + oy, BONE)
        f.rect(29, 8 + oy, 29, 10 + oy, BONE)
        f.put(28, 9 + oy, BONE)
        # cabeza
        f.srect(16, 4 + oy, 23, 11 + oy, T_SKIN)
        f.clear(16, 4 + oy)
        f.clear(23, 4 + oy)
        if facing == "down":
            f.rect(17, 7 + oy, 19, 8 + oy, EYE_DK)
            f.put(18, 7 + oy, hx("ff3a30"))
            f.rect(22, 7 + oy, 22, 7 + oy, GLOW)
            f.rect(17, 10 + oy, 22, 11 + oy, BLOOD)
            f.put(18, 10 + oy, TEETH)
            f.put(21, 10 + oy, TEETH)
            f.put(20, 11 + oy, TEETH)
        else:
            f.rect(18, 4 + oy, 21, 6 + oy, dark(T_SKIN))
            f.rect(17, 5 + oy, 17, 7 + oy, BONE)
            f.rect(22, 5 + oy, 22, 7 + oy, BONE)
    else:
        # lomo con jorobas y pinchos hacia atras
        for y in range(11, 26):
            k = (y - 11) // 5
            f.rect(12 + k, y + oy, 28 - k + lean, y + oy, T_SKIN)
            f.put(28 - k + lean, y + oy, dark(T_SKIN))
        f.rect(12, 11 + oy, 28 + lean, 11 + oy, lite(T_SKIN))
        boil(f, 12, 14 + oy, 3, T_BOIL2)
        boil(f, 15, 20 + oy, 1, T_BOIL)
        for (x, y) in ((10, 10), (9, 14), (10, 18)):
            f.rect(x, y + oy, x + 1, y + oy, BONE)
        f.rect(22, 15 + oy, 26, 15 + oy, dark(T_SKIN))
        f.rect(26, 14 + oy, 26, 17 + oy, dark(T_SKIN))
        # cabeza
        hx0 = 23 + lean
        f.srect(hx0, 5 + oy, hx0 + 7, 12 + oy, T_SKIN)
        f.clear(hx0 + 7, 5 + oy)
        f.rect(hx0 + 4, 7 + oy, hx0 + 6, 8 + oy, EYE_DK)
        f.put(hx0 + 6, 7 + oy, hx("ff3a30"))
        f.put(hx0 + 8, 9 + oy, T_SKIN)
        f.rect(hx0 + 4, 10 + oy, hx0 + 7, 12 + oy, BLOOD)
        f.put(hx0 + 5, 10 + oy, TEETH)
        f.put(hx0 + 7, 10 + oy, TEETH)
    # ---- brazos
    walk_dy = -sw if arm == "walk" else 0
    if facing == "side":
        # brazo lejano
        f.rect(21 + lean, 14 + oy, 25 + lean, 26 + oy, dark(T_SKIN))
        if arm == "up":
            big_arm(f, 19 + lean, 14 + oy, 24 + lean, 1 + oy, 6, 9, 8, True)
        elif arm == "slam":
            big_arm(f, 19 + lean, 14 + oy, 29 + lean, 27, 6, 9, 8, True)
        else:
            big_arm(f, 19 + lean, 14 + oy, 21 + lean + int(-fl * 3), 28 + oy, 6, 9, 8, True)
    else:
        if arm == "up":
            big_arm(f, 3, 13 + oy, 6, 0 + oy, 7, 9, 8)
        elif arm == "slam":
            big_arm(f, 3, 13 + oy, 6, 28 + oy, 7, 9, 8)
        else:
            big_arm(f, 3, 13 + oy, 6, 28 + oy - sw * sgn, 7, 9, 8)
        # brazo derecho (mas delgado)
        ry = 26 + oy + sw * sgn
        for t in range(6):
            f.line(30 + t, 13 + oy, 30 + t, ry, T_SKIN)
        f.line(35, 13 + oy, 35, ry, dark(T_SKIN))
        f.line(30, 13 + oy, 30, ry, lite(T_SKIN))
        fist(f, 30, ry + 1, 36, ry + 6)
        f.rect(31, 14 + oy, 34, 14 + oy, T_PANTS)                        # resto de manga
    return f.to_image(shadow=(11, 28, 36 + TDY))


def tank_poses(kind, facing, poses):
    if kind == "idle":
        return [{"oy": 0}, {"oy": 1}]
    if kind in ("walk", "run"):
        out = []
        for i, p in enumerate(poses):
            q = dict(p)
            q["oy"] = [0, 1, 0, 1][i]
            q["amp"] = 1
            out.append(q)
        return out
    return [
        {"oy": 0, "arm": "up", "lean": 0},
        {"oy": 1, "arm": "slam", "lean": 2},
        {"oy": 1, "arm": "walk", "lean": 1},
    ]


TANK = Spec()


def extra_sheets():
    out = {}
    for i, sp in enumerate(WALKERS):
        out["walker_%d" % i] = build_sheet(sp, zombie_poses)
    for i, sp in enumerate(RUNNERS):
        out["runner_%d" % i] = build_sheet(sp, runner_poses)
    out["tank"] = build_sheet(TANK, tank_poses, frame_size=(TW, TH), draw=draw_tank)
    return out


# ================================================================= principal

def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path)
    return path


def preview(img, name, pdir, rows=None, scale=5):
    os.makedirs(pdir, exist_ok=True)
    fh = img.height // len(ANIMS)
    if rows:
        img = img.crop((0, rows[0] * fh, img.width, rows[1] * fh))
    bg = Image.new("RGBA", img.size, (52, 70, 52, 255))
    bg.alpha_composite(img)
    bg = bg.resize((bg.width * scale, bg.height * scale), Image.NEAREST)
    suffix = "" if not rows else "_%d_%d" % rows
    bg.save(os.path.join(pdir, name + suffix + ".png"))


def main():
    pdir = None
    if "--preview" in sys.argv:
        pdir = sys.argv[sys.argv.index("--preview") + 1]
    sheets = {"mateo": build_sheet(MATEO), "lena": build_sheet(LENA)}
    try:
        sheets.update(extra_sheets())
    except NameError:
        pass
    for name, img in sheets.items():
        save(img, name)
        if pdir:
            preview(img, name, pdir, rows=(0, 6))
            preview(img, name, pdir, rows=(6, 12))
    print("listo:", ", ".join(sheets))


if __name__ == "__main__":
    main()
