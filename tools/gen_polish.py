#!/usr/bin/env python3
"""Acabado comun del arte de edificios: textura de material (ruido por bloques), degradado de
luz (arriba mas claro, abajo mas oscuro) y sombra proyectada en el suelo."""
import random

from PIL import Image, ImageFilter


def scale2x(im):
    """Ampliacion 2x EPX/Scale2x: mantiene el pixel art nitido pero suaviza las diagonales."""
    import numpy as np
    a = np.array(im.convert("RGBA"))
    h, w = a.shape[:2]
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    P = a
    A, D = p[0:h, 1:w + 1], p[2:h + 2, 1:w + 1]
    C, B = p[1:h + 1, 0:w], p[1:h + 1, 2:w + 2]

    def eq(x, y):
        return np.all(x == y, axis=2)

    out = np.zeros((h * 2, w * 2, 4), dtype=np.uint8)
    o1, o2, o3, o4 = P.copy(), P.copy(), P.copy(), P.copy()
    m1 = eq(C, A) & ~eq(C, D) & ~eq(A, B)
    m2 = eq(A, B) & ~eq(A, C) & ~eq(B, D)
    m3 = eq(D, C) & ~eq(D, B) & ~eq(C, A)
    m4 = eq(B, D) & ~eq(B, A) & ~eq(D, C)
    o1[m1] = A[m1]
    o2[m2] = B[m2]
    o3[m3] = C[m3]
    o4[m4] = D[m4]
    out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = o1, o2, o3, o4
    return Image.fromarray(out, "RGBA").copy()


def polish(im, seed=1, amt=5):
    """im: RGBA a 16 px/tile. Devuelve la imagen ampliada 2x (Scale2x) con textura."""
    big = scale2x(im)
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
