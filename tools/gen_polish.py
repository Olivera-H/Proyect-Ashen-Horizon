#!/usr/bin/env python3
"""Acabado comun del arte de edificios: textura de material (ruido por bloques), degradado de
luz (arriba mas claro, abajo mas oscuro) y sombra proyectada en el suelo."""
import random

from PIL import Image, ImageFilter


def polish(im, seed=1, amt=5):
    """im: RGBA a 16 px/tile. Devuelve la imagen ampliada 2x (vecino mas cercano) con textura."""
    big = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
    px = big.load()
    rnd = random.Random(seed)
    W, H = big.size
    for by in range(0, H, 2):
        grad = int(6 - 14.0 * by / H)
        for bx in range(0, W, 2):
            if px[bx, by][3] == 0:
                continue
            n = rnd.randint(-amt, amt) + grad
            for dy in (0, 1):
                for dx in (0, 1):
                    r, g, b, a = px[bx + dx, by + dy]
                    j = rnd.randint(-1, 1)
                    px[bx + dx, by + dy] = (max(0, min(255, r + n + j)), max(0, min(255, g + n + j)),
                                            max(0, min(255, b + n + j)), a)
    return big


def shadow_from(roof_big, off=(12, 14), blur=5, alpha=95, pad=24):
    """Sombra suave de la silueta del techo (a 2x), desplazada hacia abajo-derecha."""
    a = roof_big.split()[3]
    if a.getbbox() is None:
        return None
    W, H = roof_big.size
    canvas = Image.new("L", (W + pad * 2, H + pad * 2), 0)
    canvas.paste(a.point(lambda v: 255 if v > 0 else 0), (pad + off[0], pad + off[1]))
    canvas = canvas.filter(ImageFilter.GaussianBlur(blur))
    canvas = canvas.point(lambda v: int(v * alpha / 255))
    out = Image.new("RGBA", canvas.size, (8, 6, 14, 0))
    out.putalpha(canvas)
    return out
