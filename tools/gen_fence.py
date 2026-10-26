#!/usr/bin/env python3
"""Cercado del refugio y detalles de jardin: assets/world/props/fence_*.png, gate_post, refuge_sign, mailbox.
Uso: python3 tools/gen_fence.py [--preview DIR]    (requiere Pillow; usa los ayudantes de gen_props.py)"""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_props as gp  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

gp.FONT["F"] = "111100110100100"
gp.FONT["G"] = "111100101101111"

WOOD = gp.hx("#8a7459")
WOOD_L = gp.hx("#a58d6c")
WOOD_D = gp.hx("#5f4f3b")
WIRE = gp.hx("#3a3d46")
METAL = gp.hx("#6b6f78")


def barbed(d, x0, x1, y):
    gp.rect(d, x0, y, x1, y, WIRE)
    for x in range(x0 + 2, x1, 5):
        gp.px(d._image, x, y - 1, WIRE)
        gp.px(d._image, x, y + 1, WIRE)


def fence_h(variant):
    """Un tramo de 16 px visto de frente: tablas apuntadas, dos travesaños y alambre de puas."""
    img = gp.new(16, 21)
    d = ImageDraw.Draw(img)
    rnd = random.Random(40 + variant)
    base_y = 18
    for i in range(4):
        x = i * 4
        h = 13
        top = base_y - h
        if variant == 1 and i == 2:
            h = 7                                   # tabla rota
            top = base_y - h
        col = WOOD if (i + variant) % 2 == 0 else gp.lighten(WOOD, -10)
        gp.rect(d, x, top + 1, x + 2, base_y, col)
        gp.px(img, x + 1, top, col)                  # punta
        gp.rect(d, x, top + 1, x, base_y, WOOD_L)
        if variant == 2 and i == 1:                  # tabla inclinada
            gp.px(img, x, top + 1, gp.NONE)
            gp.px(img, x + 3, top - 1, col)
    for ry in (base_y - 10, base_y - 4):
        gp.rect(d, 0, ry, 15, ry + 1, WOOD_D)
        gp.rect(d, 0, ry, 15, ry, gp.lighten(WOOD_D, 18))
    d._image = img
    barbed(d, 0, 15, 2)
    # poste lateral al inicio del tramo
    gp.rect(d, 0, 4, 1, base_y + 1, gp.lighten(WOOD_D, -6))
    return gp.finish(img, gp.shadow_layer(16, 21, 8, 19, 8, 2, 60), rim=False)


def fence_v():
    """Tramo vertical (visto de lado): poste con travesaño y alambre."""
    img = gp.new(8, 22)
    d = ImageDraw.Draw(img)
    d._image = img
    gp.rect(d, 2, 5, 5, 19, WOOD)
    gp.rect(d, 2, 5, 2, 19, WOOD_L)
    gp.rect(d, 5, 5, 5, 19, WOOD_D)
    gp.rect(d, 2, 4, 5, 4, gp.lighten(WOOD, 20))
    gp.rect(d, 3, 9, 4, 10, WOOD_D)
    gp.rect(d, 3, 14, 4, 15, WOOD_D)
    barbed(d, 1, 6, 2)
    return gp.finish(img, gp.shadow_layer(8, 22, 4, 20, 4, 2, 60), rim=False)


def fence_post():
    img = gp.new(8, 26)
    d = ImageDraw.Draw(img)
    d._image = img
    gp.rect(d, 2, 7, 5, 22, WOOD_D)
    gp.rect(d, 2, 7, 2, 22, WOOD)
    gp.rect(d, 1, 5, 6, 6, METAL)
    gp.rect(d, 1, 5, 6, 5, gp.lighten(METAL, 40))
    barbed(d, 0, 7, 3)
    return gp.finish(img, gp.shadow_layer(8, 26, 4, 23, 4, 2, 60), rim=False)


def gate_post():
    """Poste del porton: mas alto, con tapa metalica y franja roja de aviso."""
    img = gp.new(10, 32)
    d = ImageDraw.Draw(img)
    d._image = img
    gp.rect(d, 2, 6, 7, 28, WOOD_D)
    gp.rect(d, 2, 6, 3, 28, WOOD)
    gp.rect(d, 1, 3, 8, 5, METAL)
    gp.rect(d, 1, 3, 8, 3, gp.lighten(METAL, 40))
    for y in range(12, 24, 4):
        gp.rect(d, 2, y, 7, y + 1, gp.hx("#b23a32"))
    return gp.finish(img, gp.shadow_layer(10, 32, 5, 29, 5, 2, 60), rim=False)


def refuge_sign():
    s = "REFUGIO"
    w = gp.text_w(s) + 6
    img = gp.new(w, 12)
    d = ImageDraw.Draw(img)
    d._image = img
    gp.rect(d, 0, 2, w - 1, 11, gp.hx("#2f5a3a"))
    gp.rect(d, 0, 2, w - 1, 2, gp.hx("#4a8458"))
    gp.rect(d, 0, 11, w - 1, 11, gp.hx("#1d3a26"))
    gp.text(img, 3, 5, s, gp.hx("#e8e4d0"))
    gp.rect(d, 3, 0, 3, 1, WIRE)
    gp.rect(d, w - 4, 0, w - 4, 1, WIRE)
    return gp.finish(img, rim=False)


def horizonte_sign():
    s = "HORIZONTE"
    w = gp.text_w(s) + 8
    img = gp.new(w, 13)
    d = ImageDraw.Draw(img)
    d._image = img
    gp.rect(d, 0, 2, w - 1, 12, gp.hx("#22364a"))
    gp.rect(d, 0, 2, w - 1, 2, gp.hx("#3ea8a0"))
    gp.rect(d, 0, 12, w - 1, 12, gp.hx("#141f2c"))
    gp.text(img, 4, 5, s, gp.hx("#e6f0ec"))
    gp.rect(d, 3, 0, 3, 1, WIRE)
    gp.rect(d, w - 4, 0, w - 4, 1, WIRE)
    return gp.finish(img, rim=False)


def mailbox():
    img = gp.new(10, 20)
    d = ImageDraw.Draw(img)
    d._image = img
    gp.rect(d, 4, 9, 5, 18, WOOD_D)
    gp.rect(d, 1, 3, 8, 8, gp.hx("#4a6f9a"))
    gp.rect(d, 1, 3, 8, 3, gp.hx("#7aa0cc"))
    gp.rect(d, 7, 1, 7, 4, gp.hx("#b23a32"))
    gp.rect(d, 2, 5, 4, 6, gp.hx("#2d4666"))
    return gp.finish(img, gp.shadow_layer(10, 20, 5, 18, 4, 2, 60))


def build():
    return {
        "fence_h_a": fence_h(0), "fence_h_b": fence_h(1), "fence_h_c": fence_h(2),
        "fence_v": fence_v(), "fence_post": fence_post(), "gate_post": gate_post(),
        "refuge_sign": refuge_sign(), "horizonte_sign": horizonte_sign(), "mailbox": mailbox(),
    }


if __name__ == "__main__":
    sp = build()
    for k, v in sp.items():
        gp.save(k, v)
    print("%d sprites de cercado" % len(sp))
    if "--preview" in sys.argv:
        gp.preview(sp, sys.argv[sys.argv.index("--preview") + 1])
