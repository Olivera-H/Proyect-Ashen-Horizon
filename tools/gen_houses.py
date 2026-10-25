#!/usr/bin/env python3
"""Prepara el arte de las casas: recorta cada par techo/interior con el mismo marco y lo
escala a una cantidad exacta de tiles (16 px). Entrada: assets/houses/originales/<id>_techo.png
y <id>_interior.png. Salida: assets/houses/<id>_roof.png y <id>_interior.png.
Uso: python3 tools/gen_houses.py [--grid DIR]   (--grid guarda vistas con la cuadricula de tiles)"""
import sys, os
from PIL import Image, ImageDraw

TS = 16
HOUSES = {            # id: (tiles de ancho, tiles de alto)
    "cabana":  (18, 10),
    "casa":    (20, 11),
    "chalet":  (12, 10),
    "taller":  (24, 12),
}

# Zonas caminables de cada interior, medidas sobre el arte (en tiles, x0, y0, x1, y1 incluidos),
# y la columna de la puerta (2 tiles de ancho) por la que se baja hasta el porche.
LAYOUT = {
    "cabana": {"floor": [(1, 3, 12, 5)], "door_x": 8},
    "casa":   {"floor": [(1, 3, 14, 6)], "door_x": 9},
    "chalet": {"floor": [(1, 3, 6, 6)],  "door_x": 5},
    "taller": {"floor": [(1, 4, 22, 5), (5, 6, 17, 7)], "door_x": 11},
}
SRC = "assets/houses/originales"
OUT = "assets/houses"


def clean(im):
    a = im.split()[3].point(lambda v: 0 if v < 100 else 255)
    im.putalpha(a)
    return im


def tile_map(hid, tw, th, roof, inte):
    """'.' fuera (libre), '#' muro (solido), 'f' piso, 'p' camino de la puerta."""
    lay = LAYOUT[hid]
    a1, a2 = roof.split()[3], inte.split()[3]
    rows = []
    floor_bottom = max(f[3] for f in lay["floor"])
    for y in range(th):
        row = ""
        for x in range(tw):
            cx, cy = x * TS + TS // 2, y * TS + TS // 2
            solid_px = a1.getpixel((cx, cy)) > 0 or a2.getpixel((cx, cy)) > 0
            c = "#" if solid_px else "."
            for (x0, y0, x1, y1) in lay["floor"]:
                if x0 <= x <= x1 and y0 <= y <= y1:
                    c = "f"
            if lay["door_x"] <= x <= lay["door_x"] + 1 and floor_bottom < y < th:
                c = "p"
            row += c
        rows.append(row)
    return {"w": tw, "h": th, "rows": rows, "door_x": lay["door_x"]}


def write_gd(data):
    out = ["# GENERADO por tools/gen_houses.py - no editar a mano.",
           "# Mapa de tiles de cada casa: '.' libre, '#' muro, 'f' piso interior, 'p' camino de la puerta.",
           "class_name HouseData", "", "const TYPES := {"]
    for hid, d in data.items():
        out.append(f'\t"{hid}": {{"w": {d["w"]}, "h": {d["h"]}, "door_x": {d["door_x"]}, "rows": [')
        for r in d["rows"]:
            out.append(f'\t\t"{r}",')
        out.append("\t]},")
    out.append("}")
    open("scripts/house_data.gd", "w").write("\n".join(out) + "\n")


def main():
    grid = sys.argv[sys.argv.index("--grid") + 1] if "--grid" in sys.argv else None
    data = {}
    for hid, (tw, th) in HOUSES.items():
        roof = Image.open(f"{SRC}/{hid}_techo.png").convert("RGBA")
        inte = Image.open(f"{SRC}/{hid}_interior.png").convert("RGBA")
        for im in (roof, inte):
            im.putalpha(im.split()[3].point(lambda v: 0 if v < 100 else 255))
        b1, b2 = roof.split()[3].getbbox(), inte.split()[3].getbbox()
        box = (min(b1[0], b2[0]), min(b1[1], b2[1]), max(b1[2], b2[2]), max(b1[3], b2[3]))
        res = {}
        for name, im in (("roof", roof), ("interior", inte)):
            c = im.crop(box).resize((tw * TS, th * TS), Image.LANCZOS)
            res[name] = clean(c)
            res[name].save(f"{OUT}/{hid}_{name}.png")
        print(hid, (tw * TS, th * TS))
        data[hid] = tile_map(hid, tw, th, res["roof"], res["interior"])
        if grid:
            os.makedirs(grid, exist_ok=True)
            for name, im in res.items():
                big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
                bg = Image.new("RGBA", big.size, (60, 90, 60, 255))
                bg.alpha_composite(big)
                d = ImageDraw.Draw(bg)
                for x in range(0, tw + 1):
                    d.line([(x * TS * 3, 0), (x * TS * 3, big.height)], fill=(255, 255, 255, 90), width=1)
                    if x < tw: d.text((x * TS * 3 + 3, 2), str(x), fill=(255, 255, 0, 255))
                for y in range(0, th + 1):
                    d.line([(0, y * TS * 3), (big.width, y * TS * 3)], fill=(255, 255, 255, 90), width=1)
                    if y < th: d.text((2, y * TS * 3 + 3), str(y), fill=(255, 255, 0, 255))
                bg.convert("RGB").save(f"{grid}/{hid}_{name}.png")
    write_gd(data)


if __name__ == "__main__":
    main()
