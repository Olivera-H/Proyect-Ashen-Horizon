#!/usr/bin/env python3
"""Verifica que el jugador (circulo de radio 4 px) pueda recorrer cada interior de casa.
Lee scripts/house_data.gd (mapa de tiles + cajas), rasteriza a 1 px, erosiona por el radio
del jugador y reporta que porcentaje del piso 'f' queda conectado con la puerta.
Uso: python3 tools/audit_houses.py"""
import re, sys
import numpy as np
from scipy import ndimage

TS = 16
RADIUS = 4.2


def parse(path="scripts/house_data.gd"):
    txt = open(path).read()
    out = {}
    for m in re.finditer(r'"(\w+)": \{"w": (\d+), "h": (\d+), "door_x": (\d+), "rows": \[(.*?)\], "boxes": \[(.*?)\]', txt, re.S):
        name, w, h, dx, rows, boxes = m.groups()
        rows = re.findall(r'"([^"]+)"', rows)
        bx = [tuple(map(float, b)) for b in re.findall(r"Rect2\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)", boxes)]
        out[name] = dict(w=int(w), h=int(h), door_x=int(dx), rows=rows, boxes=bx)
    return out


def audit(d, shrink=1.0):
    w, h = d["w"], d["h"]
    blocked = np.zeros((h * TS, w * TS), bool)
    for y, row in enumerate(d["rows"]):
        for x, c in enumerate(row):
            if c in "#.":
                blocked[y * TS:(y + 1) * TS, x * TS:(x + 1) * TS] = True
    for (bx, by, bw, bh) in d["boxes"]:
        cx, cy = bx + bw / 2, by + bh / 2
        bw2, bh2 = bw * shrink, bh * shrink
        x0, x1 = int(round((cx - bw2 / 2) * TS)), int(round((cx + bw2 / 2) * TS))
        y0, y1 = int(round((cy - bh2 / 2) * TS)), int(round((cy + bh2 / 2) * TS))
        blocked[y0:y1, x0:x1] = True
    pad = np.pad(blocked, 1, constant_values=True)
    free = ndimage.distance_transform_edt(~pad)[1:-1, 1:-1] > RADIUS
    lab, _ = ndimage.label(free)
    dx = d["door_x"] * TS + TS
    door_lab = lab[(h - 1) * TS + 8, dx]
    if door_lab == 0:
        return 0.0, 0
    tot = ok = 0
    for y, row in enumerate(d["rows"]):
        for x, c in enumerate(row):
            if c == "f":
                tot += 1
                if lab[y * TS + 8, x * TS + 8] == door_lab:
                    ok += 1
    return (ok / tot if tot else 1.0), tot


def relax(d, target=0.97):
    """Reduce las cajas de muebles (lo minimo) hasta que el piso quede conectado con la puerta."""
    boxes = [list(b) for b in d["boxes"]]
    cur = audit(dict(d, boxes=[tuple(b) for b in boxes]))[0]
    while cur < target:
        best = (cur, None)
        for i, b in enumerate(boxes):
            if b[2] <= 0.3 and b[3] <= 0.3:
                continue
            nb = [list(x) for x in boxes]
            cx, cy = b[0] + b[2] / 2, b[1] + b[3] / 2
            nw, nh = max(0.25, b[2] * 0.85), max(0.25, b[3] * 0.85)
            nb[i] = [round(cx - nw / 2, 2), round(cy - nh / 2, 2), round(nw, 2), round(nh, 2)]
            r = audit(dict(d, boxes=[tuple(x) for x in nb]))[0]
            if r > best[0] + 1e-9:
                best = (r, nb)
            # alternativa: quitar el mueble (se penaliza para preferir achicar)
            nb2 = [list(x) for j, x in enumerate(boxes) if j != i]
            r2 = audit(dict(d, boxes=[tuple(x) for x in nb2]))[0] - 0.04
            if r2 > best[0] + 1e-9:
                best = (r2 + 0.04, nb2)
        if best[1] is None:
            break
        cur, boxes = best[0], best[1]
    return [tuple(b) for b in boxes], cur


if __name__ == "__main__":
    for n, d in parse().items():
        nb, r = relax(d)
        print(n, "%.0f%% -> %.0f%% tras ajustar cajas" % (100 * audit(d)[0], 100 * r))
        for b in nb:
            print("   ", b)
