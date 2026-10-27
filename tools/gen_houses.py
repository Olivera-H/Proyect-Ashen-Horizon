#!/usr/bin/env python3
"""Prepara el arte de las casas: recorta cada par techo/interior con el mismo marco y lo
escala a una cantidad exacta de tiles (16 px). Entrada: assets/houses/originales/<id>_techo.png
y <id>_interior.png. Salida: assets/houses/<id>_roof.png y <id>_interior.png.
Uso: python3 tools/gen_houses.py [--grid DIR]   (--grid guarda vistas con la cuadricula de tiles)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter

TS = 16
SC = 2          # resolucion del arte: 2 px por pixel de juego (el sprite se dibuja a escala 0.5)
HOUSES = {            # id: (tiles de ancho, tiles de alto)
    "cabana":  (18, 10),
    "casa":    (20, 11),
    "chalet":  (12, 10),
    "taller":  (24, 12),
}

# Zonas caminables de cada interior, medidas sobre el arte (en tiles, x0, y0, x1, y1 incluidos),
# y la columna de la puerta (2 tiles de ancho) por la que se baja hasta el porche.
LAYOUT = {
    "cabana": {"floor": [(1, 4, 12, 5)], "door_x": 8, "boxes": [
        (6.3, 4.0, 0.4, 1.3),    # tabique 1
        (11.6, 4.0, 0.4, 1.3),   # tabique 2
        (9.0, 4.0, 2.6, 1.0),    # cama
        (1.4, 5.4, 3.8, 0.35),   # banca
        (4.2, 5.7, 2.7, 0.3),    # mesa izquierda
        (11.0, 5.75, 2.5, 0.25),  # mesa derecha
    ]},
    "casa": {"floor": [(8, 3, 14, 6)], "door_x": 9, "boxes": [
        (8.0, 3.0, 3.3, 0.7),    # biblioteca
        (8.8, 4.15, 2.1, 1.2),   # escritorio
        (7.9, 5.0, 1.2, 1.2),    # sillon
        (11.15, 3.6, 1.3, 2.6),  # tabique y alacena
        (12.0, 3.0, 1.1, 0.8),   # estufa
        (13.2, 4.1, 2.1, 1.7),   # mesa de la cocina
        (14.8, 3.0, 0.6, 0.5),   # planta
    ]},
    "chalet": {"floor": [(1, 3, 6, 6)], "door_x": 5, "boxes": [
        (0.5, 3.0, 1.3, 0.4),    # reloj
        (4.4, 3.0, 2.7, 0.7),    # sofa de arriba
        (0.7, 3.7, 3.0, 1.8),    # sofa de la izquierda
        (4.0, 4.1, 1.5, 1.7),    # sillon
        (6.5, 5.4, 0.9, 1.0),    # baul
    ]},
    "taller": {"floor": [(1, 4, 22, 5), (5, 6, 17, 7)], "door_x": 11, "boxes": [
        (0.5, 3.8, 1.0, 2.0),    # estante izquierdo
        (3.9, 4.5, 1.2, 1.2),    # yunque
        (5.5, 4.0, 1.7, 0.3),    # base de la fragua
        (7.6, 4.6, 1.2, 1.2),    # olla sobre soporte
        (8.5, 3.5, 1.1, 2.4),    # poste y repisa
        (10.3, 3.7, 2.4, 1.0),   # mesa de dibujo
        (13.5, 3.8, 1.9, 1.2),   # librero
        (15.4, 3.5, 0.5, 2.5),   # poste
        (16.2, 3.8, 1.4, 1.4),   # maquina
        (17.9, 3.6, 1.5, 1.7),   # generador
        (19.8, 3.5, 3.5, 1.6),   # estantes
        (5.5, 6.9, 1.0, 0.9),    # barril
        (16.4, 7.1, 2.0, 0.8),   # trapos
    ]},
}


SRC = "assets/houses/originales"
OUT = "assets/houses"


def clean(im):
    a = im.split()[3].point(lambda v: 0 if v < 128 else 255)
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
            cx, cy = (x * TS + TS // 2) * SC, (y * TS + TS // 2) * SC
            solid_px = a1.getpixel((cx, cy)) > 0 or a2.getpixel((cx, cy)) > 0
            c = "#" if solid_px else "."
            for (x0, y0, x1, y1) in lay["floor"]:
                if x0 <= x <= x1 and y0 <= y <= y1:
                    c = "f"
                    for (bx, by, bw, bh) in lay["boxes"]:
                        if bx <= x + 0.5 <= bx + bw and by <= y + 0.5 <= by + bh:
                            c = "o"      # piso con un mueble encima (sin botin)
            if lay["door_x"] <= x <= lay["door_x"] + 1 and floor_bottom < y < th:
                c = "p"
            row += c
        rows.append(row)
    return {"w": tw, "h": th, "rows": rows, "door_x": lay["door_x"], "boxes": lay["boxes"]}


def write_gd(data):
    out = ["# GENERADO por tools/gen_houses.py - no editar a mano.",
           "# Mapa de tiles de cada casa: '.' libre, '#' muro, 'f' piso, 'o' piso con mueble, 'p' camino de la puerta.",
           "# boxes: cajas de colision de muebles y tabiques, en tiles (x, y, ancho, alto) desde la esquina de la casa.",
           "class_name HouseData", "", "const TYPES := {"]
    for hid, d in data.items():
        out.append(f'\t"{hid}": {{"w": {d["w"]}, "h": {d["h"]}, "door_x": {d["door_x"]}, "rows": [')
        for r in d["rows"]:
            out.append(f'\t\t"{r}",')
        out.append("\t], \"boxes\": [")
        for (bx, by, bw, bh) in d["boxes"]:
            out.append(f"\t\tRect2({bx}, {by}, {bw}, {bh}),")
        extra = ""
        if "terminal" in d:
            extra += ', "terminal": Vector2(%s, %s)' % d["terminal"]
            extra += ', "door_block": Rect2(%s, %s, %s, %s)' % tuple(d["door_block"])
        out.append("\t]" + extra + "},")
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
            c = im.crop(box).resize((tw * TS * SC, th * TS * SC), Image.LANCZOS)
            c = c.filter(ImageFilter.UnsharpMask(radius=1.2, percent=70, threshold=2))
            res[name] = clean(c)
            res[name].save(f"{OUT}/{hid}_{name}.png")
        print(hid, (tw * TS * SC, th * TS * SC))
        data[hid] = tile_map(hid, tw, th, res["roof"], res["interior"])
        # ajusta los muebles para que el circulo del jugador pueda recorrer todo el interior
        import audit_houses
        nb, reach = audit_houses.relax(data[hid])
        data[hid]["boxes"] = nb
        print("   interior transitable: %.0f%%" % (100 * reach))
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
    import gen_lab
    _imgs, lab = gen_lab.build()
    import audit_houses
    lab["boxes"], reach = audit_houses.relax(lab)
    print("   laboratorio transitable: %.0f%%" % (100 * reach))
    data["laboratorio"] = lab
    import gen_buildings
    _bi, bdata = gen_buildings.build()
    for nm, bd in bdata.items():
        bd["boxes"], rr = audit_houses.relax(bd)
        print("   %s transitable: %.0f%%" % (nm, 100 * rr))
        data[nm] = bd
    print("laboratorio", _imgs["laboratorio_interior"].size)
    write_gd(data)


if __name__ == "__main__":
    main()
