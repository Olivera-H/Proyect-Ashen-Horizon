#!/usr/bin/env python3
"""Iconos y casillas del inventario: assets/ui/inv/*.png (objetos 16x16, casillas 24x24, mochila 24x24).
Uso: python3 tools/gen_inventory_ui.py [--preview ARCHIVO.png]   (requiere Pillow)"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui", "inv")
OL = (22, 17, 30, 255)
N = (0, 0, 0, 0)


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def new(w, h):
    return Image.new("RGBA", (w, h), N)


def outline(img):
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and src.getpixel((nx, ny))[3] > 200:
                    img.putpixel((x, y), OL)
                    break
    return img


def R(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def P(img, pts, c):
    for x, y in pts:
        if 0 <= x < img.width and 0 <= y < img.height:
            img.putpixel((x, y), c)


# ------------------------------------------------------------------ objetos
def bandage():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 2, 4, 13, 11, hx("#ecebe6")); R(d, 2, 4, 13, 4, hx("#ffffff")); R(d, 2, 11, 13, 11, hx("#b8b6ae"))
    R(d, 6, 5, 9, 10, hx("#c0392b")); R(d, 4, 7, 11, 8, hx("#c0392b"))
    R(d, 6, 5, 6, 10, hx("#e05a4a")); R(d, 4, 7, 11, 7, hx("#e05a4a"))
    return outline(im)


def food():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 3, 3, 12, 13, hx("#d9822b")); R(d, 3, 3, 4, 13, hx("#f0a24a")); R(d, 11, 3, 12, 13, hx("#a85f1c"))
    R(d, 3, 2, 12, 3, hx("#c8ccd2")); R(d, 3, 13, 12, 13, hx("#9aa0a8"))
    R(d, 5, 6, 10, 10, hx("#f4d35e")); R(d, 5, 6, 10, 6, hx("#fff0a0")); R(d, 6, 8, 9, 8, hx("#c0392b"))
    return outline(im)


def semillas():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 3, 4, 12, 14, hx("#d8c69a")); R(d, 3, 4, 12, 5, hx("#f0e4c0")); R(d, 12, 5, 12, 14, hx("#a89868"))
    R(d, 4, 7, 11, 11, hx("#8aa850")); R(d, 4, 7, 11, 7, hx("#b4d070"))
    P(im, [(7, 9), (8, 9), (6, 10), (9, 10)], hx("#c0392b"))
    R(d, 7, 1, 8, 3, hx("#4f9a3a")); R(d, 5, 2, 6, 3, hx("#6bbd4c")); R(d, 9, 2, 10, 3, hx("#6bbd4c"))
    return outline(im)


def water():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 6, 1, 9, 2, hx("#9aa0a8")); R(d, 5, 3, 10, 4, hx("#4aa3df"))
    R(d, 4, 5, 11, 14, hx("#3b8cc4")); R(d, 4, 5, 5, 14, hx("#7cc6f0")); R(d, 10, 5, 11, 14, hx("#2a6a9a"))
    R(d, 6, 7, 6, 12, hx("#d6f0ff")); R(d, 4, 9, 11, 10, hx("#e8e4d0"))
    return outline(im)


def scrap():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 2, 8, 12, 11, hx("#8a8d93")); R(d, 2, 8, 12, 8, hx("#b4b7bd")); R(d, 2, 11, 12, 11, hx("#55585e"))
    R(d, 5, 3, 9, 7, hx("#6f737a")); R(d, 5, 3, 9, 3, hx("#9a9ea6")); P(im, [(7, 5)], OL)
    R(d, 9, 11, 14, 13, hx("#7a5a3a")); R(d, 9, 11, 14, 11, hx("#a07a50"))
    P(im, [(3, 9), (4, 9)], hx("#d8dade"))
    return outline(im)


# ------------------------------------------------------------ armas y municion
def line(d, pts, c, w=1):
    d.line(pts, fill=c, width=w)


def tubo():
    im = new(16, 16); d = ImageDraw.Draw(im)
    line(d, [(3, 13), (12, 3)], hx("#8a8d93"), 3)
    line(d, [(3, 12), (11, 3)], hx("#c0c4cc"), 1)
    line(d, [(4, 14), (13, 4)], hx("#55585e"), 1)
    return outline(im)


def hacha():
    im = new(16, 16); d = ImageDraw.Draw(im)
    line(d, [(3, 14), (11, 4)], hx("#8a5a2b"), 2)
    d.polygon([(8, 2), (14, 4), (14, 8), (10, 8), (8, 6)], fill=hx("#c0392b"))
    d.polygon([(11, 3), (14, 4), (14, 6), (11, 6)], fill=hx("#e8e4d0"))
    P(im, [(9, 3), (9, 4)], hx("#e05a4a"))
    return outline(im)


def machete():
    im = new(16, 16); d = ImageDraw.Draw(im)
    d.polygon([(5, 11), (13, 2), (14, 3), (14, 6), (7, 13)], fill=hx("#b4b7bd"))
    line(d, [(6, 11), (13, 3)], hx("#eef0f4"), 1)
    line(d, [(8, 12), (14, 6)], hx("#6f737a"), 1)
    line(d, [(2, 14), (6, 10)], hx("#5a3a1e"), 2)
    P(im, [(5, 10), (6, 11), (4, 9)], hx("#c9a227"))
    return outline(im)


def pistola():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 2, 4, 13, 7, hx("#4a4d55")); R(d, 2, 4, 13, 4, hx("#8a8d93"))
    R(d, 3, 8, 6, 9, hx("#4a4d55")); R(d, 4, 9, 7, 13, hx("#3a2a1e")); R(d, 4, 9, 4, 13, hx("#6b4a2a"))
    R(d, 8, 8, 9, 8, hx("#2a2c33")); R(d, 12, 5, 13, 6, hx("#2a2c33"))
    P(im, [(3, 5)], hx("#c0c4cc"))
    return outline(im)


def escopeta():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 5, 5, 15, 6, hx("#4a4d55")); R(d, 5, 5, 15, 5, hx("#8a8d93"))
    R(d, 6, 7, 12, 7, hx("#3a3d44"))
    d.polygon([(0, 8), (6, 6), (6, 9), (3, 11), (1, 11)], fill=hx("#6b4a2a"))
    R(d, 7, 8, 11, 9, hx("#8a5a2b"))
    P(im, [(1, 9), (2, 8)], hx("#a8743f"))
    return outline(im)


def fusil():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 4, 5, 15, 6, hx("#3c4048")); R(d, 4, 5, 15, 5, hx("#7c8088"))
    R(d, 6, 7, 11, 8, hx("#2e3238")); R(d, 8, 9, 9, 11, hx("#2a2d33"))
    R(d, 12, 3, 13, 4, hx("#2a2d33"))
    d.polygon([(0, 7), (5, 5), (5, 8), (3, 10), (1, 10)], fill=hx("#3f4a32"))
    R(d, 6, 6, 8, 6, hx("#5a6a44"))
    return outline(im)


def mascara():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 3, 3, 12, 11, hx("#3f4a32")); R(d, 4, 2, 11, 2, hx("#3f4a32"))
    R(d, 4, 5, 6, 7, hx("#9fd0d8")); R(d, 9, 5, 11, 7, hx("#9fd0d8")); R(d, 4, 5, 4, 5, hx("#e6f8fa")); R(d, 9, 5, 9, 5, hx("#e6f8fa"))
    R(d, 6, 9, 9, 13, hx("#2a2d33")); R(d, 7, 10, 8, 12, hx("#555a63"))
    R(d, 6, 9, 9, 9, hx("#7c8088"))
    R(d, 2, 5, 2, 7, hx("#222a1c")); R(d, 13, 5, 13, 7, hx("#222a1c"))
    return outline(im)


def llave():
    im = new(16, 16); d = ImageDraw.Draw(im)
    d.ellipse([2, 3, 8, 9], fill=hx("#d9b83a")); d.ellipse([4, 5, 6, 7], fill=(0, 0, 0, 0))
    R(d, 8, 6, 14, 7, hx("#d9b83a")); R(d, 12, 7, 13, 10, hx("#d9b83a")); R(d, 10, 7, 10, 9, hx("#d9b83a"))
    R(d, 3, 3, 6, 3, hx("#f2de80"))
    R(d, 1, 11, 6, 13, hx("#3a4529")); R(d, 2, 12, 5, 12, hx("#e8efd0"))
    return outline(im)


def suero():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 5, 3, 10, 12, hx("#cfe8f0")); R(d, 6, 7, 9, 11, hx("#58e08a")); R(d, 6, 8, 7, 10, hx("#b8ffd0"))
    R(d, 4, 2, 11, 3, hx("#5a6068")); R(d, 7, 0, 8, 1, hx("#9aa0aa")); R(d, 6, 4, 6, 6, hx("#ffffff"))
    R(d, 9, 5, 9, 5, hx("#2a2d33")); R(d, 9, 6, 9, 6, hx("#2a2d33"))
    return outline(im)


def balas():
    im = new(16, 16); d = ImageDraw.Draw(im)
    for i, x in enumerate((3, 7, 11)):
        R(d, x, 4 + (i % 2), x + 2, 12, hx("#c9a227"))
        R(d, x, 4 + (i % 2), x + 2, 6 + (i % 2), hx("#b87333"))
        R(d, x, 4 + (i % 2), x, 12, hx("#f1d262"))
        R(d, x, 12, x + 2, 13, hx("#8a6a1a"))
    return outline(im)


def cartuchos():
    im = new(16, 16); d = ImageDraw.Draw(im)
    for x in (3, 9):
        R(d, x, 3, x + 3, 10, hx("#c0392b")); R(d, x, 3, x, 10, hx("#e05a4a"))
        R(d, x, 10, x + 3, 13, hx("#c9a227")); R(d, x, 10, x, 13, hx("#f1d262"))
        R(d, x + 1, 2, x + 2, 2, hx("#a82a20"))
    return outline(im)


def tarjeta():
    im = new(16, 16); d = ImageDraw.Draw(im)
    R(d, 1, 3, 14, 12, hx("#e8eef4")); R(d, 1, 3, 14, 3, hx("#ffffff")); R(d, 1, 12, 14, 12, hx("#aab4c0"))
    R(d, 1, 5, 14, 6, hx("#2a3a52"))
    R(d, 3, 8, 6, 10, hx("#e0b030")); R(d, 4, 9, 5, 9, hx("#a8842a"))
    R(d, 9, 9, 12, 9, hx("#4a8ac0")); R(d, 9, 11, 11, 11, hx("#8a94a0"))
    return outline(im)


# --------------------------------------------------------------- habilidades
def badge(color):
    im = new(16, 16); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 15, 15], fill=hx("#2a2438"))
    d.ellipse([0, 0, 15, 15], outline=color)
    d.ellipse([1, 1, 14, 14], outline=hx("#3d3552"))
    return im


def skill(name):
    gold = hx("#e0b030")
    im = badge(gold); d = ImageDraw.Draw(im)
    if name == "golpe":      # punio
        R(d, 4, 5, 11, 10, hx("#d9a066")); R(d, 4, 5, 11, 5, hx("#f0c08a")); R(d, 4, 10, 11, 10, hx("#a8743f"))
        for x in (6, 8, 10): P(im, [(x, 6), (x, 7)], hx("#a8743f"))
        R(d, 5, 11, 10, 12, hx("#c0392b"))
    elif name == "resistencia":   # rayo
        pts = [(9, 2), (5, 8), (8, 8), (6, 13), (11, 6), (8, 6), (10, 2)]
        d.polygon(pts, fill=hx("#f1c40f")); d.line([(9, 3), (6, 8)], fill=hx("#fff2a0"))
    elif name == "pies":     # bota con ala
        R(d, 4, 4, 7, 10, hx("#8a8d93")); R(d, 4, 10, 11, 12, hx("#6f737a")); R(d, 4, 4, 4, 11, hx("#b4b7bd"))
        d.polygon([(8, 5), (13, 3), (12, 8)], fill=hx("#5dd6e8")); P(im, [(10, 5), (11, 6)], hx("#d6f8ff"))
    elif name == "manos":    # llave inglesa
        d.line([(4, 12), (10, 6)], fill=hx("#d9822b"), width=2)
        d.ellipse([9, 2, 13, 6], outline=hx("#c8ccd2")); R(d, 10, 2, 12, 3, N)
        P(im, [(5, 11), (4, 12), (4, 11)], hx("#ffcf8a"))
    elif name == "estomago":  # manzana
        d.ellipse([3, 5, 12, 13], fill=hx("#6ab04c")); d.ellipse([4, 6, 7, 9], fill=hx("#a5e07a"))
        R(d, 7, 3, 8, 5, hx("#6b4a2a")); P(im, [(9, 3), (10, 3)], hx("#4a8a3a"))
    elif name == "sigilo":    # ojo tachado
        d.ellipse([3, 6, 12, 11], fill=hx("#ecebe6")); d.ellipse([6, 7, 9, 10], fill=hx("#7a4fc0"))
        P(im, [(7, 8)], hx("#1a1024")); d.line([(3, 12), (12, 4)], fill=hx("#d64545"), width=1)
    return outline(im) if False else im


# ------------------------------------------------------------------ interfaz
def slot(kind):
    im = new(24, 24); d = ImageDraw.Draw(im)
    base = {"item": hx("#1d2030"), "sel": hx("#262a40"), "skill": hx("#241e34")}[kind]
    edge = {"item": hx("#4a5068"), "sel": hx("#f1c40f"), "skill": hx("#a8842a")}[kind]
    R(d, 1, 1, 22, 22, base)
    d.rectangle([0, 0, 23, 23], outline=edge)
    R(d, 1, 1, 22, 1, hx("#ffffff", 22)); R(d, 1, 21, 22, 22, hx("#000000", 70))
    P(im, [(0, 0), (23, 0), (0, 23), (23, 23)], N)
    if kind == "skill":
        for (x, y) in ((2, 2), (21, 2), (2, 21), (21, 21)):
            P(im, [(x, y)], hx("#f1c40f"))
    if kind == "sel":
        d.rectangle([1, 1, 22, 22], outline=hx("#f1c40f", 120))
    return im


def backpack():
    im = new(24, 24); d = ImageDraw.Draw(im)
    R(d, 5, 3, 18, 6, hx("#6b7a4a")); R(d, 4, 6, 19, 21, hx("#56653a")); R(d, 4, 6, 6, 21, hx("#7a8c52")); R(d, 17, 6, 19, 21, hx("#3f4a2a"))
    R(d, 7, 2, 16, 3, hx("#3f4a2a")); R(d, 9, 0, 14, 1, hx("#3f4a2a"))
    R(d, 6, 13, 17, 19, hx("#6b7a4a")); R(d, 6, 13, 17, 14, hx("#8a9c60")); R(d, 6, 19, 17, 19, hx("#3f4a2a"))
    R(d, 10, 15, 13, 16, hx("#b08a3a")); R(d, 11, 16, 12, 17, hx("#d8b25a"))
    R(d, 2, 9, 3, 18, hx("#3f4a2a")); R(d, 20, 9, 21, 18, hx("#3f4a2a"))
    R(d, 7, 7, 16, 8, hx("#3f4a2a"))
    return outline(im)


def main():
    os.makedirs(OUT, exist_ok=True)
    sp = {"item_bandage": bandage(), "item_food": food(), "item_water": water(), "item_scrap": scrap(),
          "item_tubo": tubo(), "item_hacha": hacha(), "item_machete": machete(), "item_pistola": pistola(),
          "item_escopeta": escopeta(), "item_fusil": fusil(), "item_mascara": mascara(), "item_llave": llave(), "item_suero": suero(), "item_balas": balas(), "item_cartuchos": cartuchos(), "item_tarjeta": tarjeta(), "item_semillas": semillas(),
          "slot": slot("item"), "slot_sel": slot("sel"), "slot_skill": slot("skill"), "bag": backpack()}
    for s in ("golpe", "resistencia", "pies", "manos", "estomago", "sigilo"):
        sp["skill_" + s] = skill(s)
    for k, v in sp.items():
        v.save(os.path.join(OUT, k + ".png"))
    print("%d imagenes en %s" % (len(sp), os.path.normpath(OUT)))
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        sheet = Image.new("RGBA", (8 * 80, 3 * 80), (60, 90, 60, 255))
        for i, (k, v) in enumerate(sp.items()):
            big = v.resize((v.width * 3, v.height * 3), Image.NEAREST)
            sheet.alpha_composite(big, ((i % 8) * 80 + 4, (i // 8) * 80 + 4))
        sheet.save(path)


if __name__ == "__main__":
    main()
