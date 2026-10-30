#!/usr/bin/env python3
"""Skins extra del protagonista (solo cambian el aspecto): soldado, medica, mecanico, motero y granjero.
Usan el mismo molde de cuerpo que Mateo y Lena (tools/gen_sprites.py) y escriben
assets/sprites/<id>.png con el mismo formato (12 filas x 4 columnas, cuadros de 24x32).
Uso: python3 tools/gen_skins.py [--preview ARCHIVO.png]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sprites as g  # noqa: E402
from gen_sprites import hx, dark, lite, Spec  # noqa: E402
from PIL import Image  # noqa: E402

EYE = (25, 20, 28)


def torso_factory(jacket, under=None, belt="5a3e2a", pack=None, stripe=None, collar=None):
    jacket, belt = hx(jacket) if isinstance(jacket, str) else jacket, hx(belt)
    under = hx(under) if under else None
    pack = hx(pack) if pack else None
    stripe = hx(stripe) if stripe else None
    collar = hx(collar) if collar else None

    def torso(f, facing, ox, oy, pose, spec):
        if facing == "side" and pack:
            g.backpack(f, facing, ox, oy, pack)
        if facing in ("down", "up"):
            f.srect(7 + ox, 11 + oy, 16 + ox, 18 + oy, jacket)
            if stripe:
                f.rect(7 + ox, 15 + oy, 16 + ox, 15 + oy, stripe)
            f.rect(7 + ox, 18 + oy, 16 + ox, 18 + oy, belt)
            if facing == "down":
                f.rect(10 + ox, 11 + oy, 13 + ox, 11 + oy, dark(spec.skin))
                if under:
                    f.rect(10 + ox, 12 + oy, 13 + ox, 17 + oy, under)
                    f.rect(10 + ox, 12 + oy, 13 + ox, 12 + oy, dark(under))
                else:
                    f.rect(11 + ox, 12 + oy, 12 + ox, 14 + oy, dark(jacket))
                if collar:
                    f.rect(7 + ox, 11 + oy, 9 + ox, 11 + oy, collar)
                    f.rect(14 + ox, 11 + oy, 16 + ox, 11 + oy, collar)
                f.put(11 + ox, 18 + oy, hx("b8bcc4"))
                f.put(12 + ox, 18 + oy, hx("b8bcc4"))
            else:
                if pack:
                    g.backpack(f, facing, ox, oy, pack)
                if collar:
                    f.rect(7 + ox, 11 + oy, 16 + ox, 11 + oy, collar)
        else:
            f.srect(8 + ox, 11 + oy, 15 + ox, 18 + oy, jacket)
            if stripe:
                f.rect(8 + ox, 15 + oy, 15 + ox, 15 + oy, stripe)
            if under:
                f.rect(13 + ox, 12 + oy, 15 + ox, 17 + oy, under)
            f.rect(8 + ox, 18 + oy, 15 + ox, 18 + oy, belt)
            f.put(14 + ox, 18 + oy, hx("b8bcc4"))
    return torso


def head_gear_factory(skin, top, brim, mark=None, beard=None, visor=None, hair=None, camo=False):
    skin, top, brim = hx(skin), hx(top), hx(brim)
    mark = hx(mark) if mark else None
    beard = hx(beard) if beard else None
    visor = hx(visor) if visor else None
    hair = hx(hair) if hair else None

    def head(f, facing, ox, oy, pose, spec):
        if facing == "down":
            f.srect(8 + ox, 6 + oy, 15 + ox, 10 + oy, skin)
            f.rect(8 + ox, 10 + oy, 15 + ox, 10 + oy, beard or dark(skin))
            if beard:
                f.rect(9 + ox, 9 + oy, 14 + ox, 9 + oy, beard)
            if hair:
                f.rect(8 + ox, 6 + oy, 8 + ox, 8 + oy, hair); f.rect(15 + ox, 6 + oy, 15 + ox, 8 + oy, hair)
            f.srect(8 + ox, 2 + oy, 15 + ox, 5 + oy, top)
            f.rect(7 + ox, 6 + oy, 16 + ox, 6 + oy, brim)
            if mark:
                f.rect(11 + ox, 3 + oy, 12 + ox, 4 + oy, mark)
            if camo:
                f.put(9 + ox, 3 + oy, dark(top)); f.put(13 + ox, 4 + oy, dark(top)); f.put(14 + ox, 3 + oy, lite(top))
            if visor:
                f.rect(8 + ox, 7 + oy, 15 + ox, 8 + oy, visor)
                f.put(9 + ox, 7 + oy, lite(visor))
            else:
                f.put(10 + ox, 8 + oy, EYE); f.put(13 + ox, 8 + oy, EYE)
            f.put(11 + ox, 10 + oy, hx("7a3a2a")); f.put(12 + ox, 10 + oy, hx("7a3a2a"))
            f.clear(8 + ox, 2 + oy); f.clear(15 + ox, 2 + oy)
        elif facing == "up":
            f.srect(8 + ox, 2 + oy, 15 + ox, 8 + oy, top)
            f.clear(8 + ox, 2 + oy); f.clear(15 + ox, 2 + oy)
            f.rect(8 + ox, 5 + oy, 15 + ox, 5 + oy, brim)
            f.rect(7 + ox, 8 + oy, 16 + ox, 9 + oy, brim)
            f.rect(9 + ox, 10 + oy, 14 + ox, 10 + oy, hair or dark(skin))
            if camo:
                f.put(10 + ox, 4 + oy, dark(top)); f.put(13 + ox, 6 + oy, dark(top))
        else:
            f.srect(9 + ox, 6 + oy, 15 + ox, 10 + oy, skin)
            f.rect(9 + ox, 10 + oy, 14 + ox, 10 + oy, beard or dark(skin))
            f.put(16 + ox, 9 + oy, skin)
            f.srect(7 + ox, 2 + oy, 15 + ox, 5 + oy, top)
            f.rect(7 + ox, 4 + oy, 15 + ox, 4 + oy, brim)
            f.rect(10 + ox, 6 + oy, 17 + ox, 6 + oy, brim)
            f.rect(7 + ox, 6 + oy, 9 + ox, 9 + oy, hair or brim)
            if visor:
                f.rect(12 + ox, 7 + oy, 16 + ox, 8 + oy, visor)
            else:
                f.put(13 + ox, 8 + oy, EYE)
            if mark:
                f.put(11 + ox, 3 + oy, mark)
            f.clear(7 + ox, 2 + oy); f.clear(15 + ox, 2 + oy)
    return head


def head_hair_factory(skin, hair, accent, style="bun"):
    skin, hair, accent = hx(skin), hx(hair), hx(accent)

    def head(f, facing, ox, oy, pose, spec):
        if facing == "down":
            f.srect(8 + ox, 5 + oy, 15 + ox, 10 + oy, skin)
            f.srect(8 + ox, 2 + oy, 15 + ox, 5 + oy, hair)
            f.rect(7 + ox, 3 + oy, 7 + ox, 8 + oy, hair); f.rect(16 + ox, 3 + oy, 16 + ox, 8 + oy, hair)
            f.rect(9 + ox, 6 + oy, 11 + ox, 6 + oy, hair)
            f.rect(8 + ox, 4 + oy, 15 + ox, 4 + oy, accent)                  # cinta
            f.put(10 + ox, 8 + oy, EYE); f.put(13 + ox, 8 + oy, EYE)
            f.put(11 + ox, 10 + oy, hx("a8584e")); f.put(12 + ox, 10 + oy, hx("a8584e"))
            f.clear(8 + ox, 2 + oy); f.clear(15 + ox, 2 + oy)
        elif facing == "up":
            f.srect(8 + ox, 2 + oy, 15 + ox, 10 + oy, hair)
            f.clear(8 + ox, 2 + oy); f.clear(15 + ox, 2 + oy)
            f.rect(8 + ox, 4 + oy, 15 + ox, 4 + oy, accent)
            if style == "bun":
                f.srect(10 + ox, 0 + oy, 13 + ox, 2 + oy, lite(hair)); f.rect(11 + ox, 1 + oy, 12 + ox, 1 + oy, accent)
            else:
                f.rect(11 + ox, 10 + oy, 12 + ox, 13 + oy, hair)
        else:
            f.srect(9 + ox, 5 + oy, 15 + ox, 10 + oy, skin)
            f.put(16 + ox, 9 + oy, skin)
            f.srect(7 + ox, 2 + oy, 15 + ox, 5 + oy, hair)
            f.rect(7 + ox, 5 + oy, 10 + ox, 9 + oy, hair)
            f.rect(8 + ox, 4 + oy, 15 + ox, 4 + oy, accent)
            if style == "bun":
                f.srect(5 + ox, 1 + oy, 8 + ox, 4 + oy, lite(hair)); f.put(6 + ox, 3 + oy, accent)
            f.put(13 + ox, 8 + oy, EYE)
            f.put(14 + ox, 10 + oy, hx("a8584e"))
            f.clear(7 + ox, 2 + oy)
    return head


def head_straw(skin, hat, band):
    skin, hat, band = hx(skin), hx(hat), hx(band)

    def head(f, facing, ox, oy, pose, spec):
        if facing == "down":
            f.srect(8 + ox, 6 + oy, 15 + ox, 10 + oy, skin)
            f.rect(8 + ox, 10 + oy, 15 + ox, 10 + oy, dark(skin))
            f.srect(8 + ox, 2 + oy, 15 + ox, 4 + oy, hat)
            f.rect(8 + ox, 4 + oy, 15 + ox, 4 + oy, band)
            f.srect(5 + ox, 5 + oy, 18 + ox, 6 + oy, hat)                      # ala ancha
            f.rect(6 + ox, 7 + oy, 17 + ox, 7 + oy, dark(skin))                # sombra bajo el ala
            f.put(10 + ox, 8 + oy, EYE); f.put(13 + ox, 8 + oy, EYE)
            f.put(11 + ox, 10 + oy, hx("7a3a2a")); f.put(12 + ox, 10 + oy, hx("7a3a2a"))
            f.clear(8 + ox, 2 + oy); f.clear(15 + ox, 2 + oy)
        elif facing == "up":
            f.srect(8 + ox, 2 + oy, 15 + ox, 4 + oy, hat)
            f.rect(8 + ox, 4 + oy, 15 + ox, 4 + oy, band)
            f.srect(5 + ox, 5 + oy, 18 + ox, 8 + oy, hat)
            f.rect(9 + ox, 9 + oy, 14 + ox, 10 + oy, dark(skin))
            f.clear(8 + ox, 2 + oy); f.clear(15 + ox, 2 + oy)
        else:
            f.srect(9 + ox, 6 + oy, 15 + ox, 10 + oy, skin)
            f.rect(9 + ox, 10 + oy, 14 + ox, 10 + oy, dark(skin))
            f.put(16 + ox, 9 + oy, skin)
            f.srect(8 + ox, 2 + oy, 15 + ox, 4 + oy, hat)
            f.rect(8 + ox, 4 + oy, 15 + ox, 4 + oy, band)
            f.srect(6 + ox, 5 + oy, 18 + ox, 6 + oy, hat)
            f.rect(8 + ox, 7 + oy, 16 + ox, 7 + oy, dark(skin))
            f.put(13 + ox, 8 + oy, EYE)
            f.clear(8 + ox, 2 + oy)
    return head


SKINS = {
    # soldado: casco y chaleco de camuflaje verde oliva
    "soldado": Spec(pants=hx("4c5a3a"), boots=hx("3a2e22"), skin=hx("c98f5a"), sleeve=hx("5f6e45"), cuff=hx("3a4529"),
                    leg_band=hx("3a4529"),
                    torso=torso_factory("5f6e45", under="3a4529", belt="3a2e22", pack="4a4a38", stripe="3a4529"),
                    head=head_gear_factory("c98f5a", "5c6a45", "3a4529", camo=True)),
    # medica: uniforme verde quirurgico, cinta blanca y moño
    "medica": Spec(pants=hx("2f7a72"), boots=hx("e4e6ea"), skin=hx("f0c7a0"), sleeve=hx("3fa296"), cuff=hx("e4e6ea"),
                   torso=torso_factory("3fa296", under="e4e6ea", belt="e4e6ea", pack="c8c2b0", stripe="e4e6ea"),
                   head=head_hair_factory("f0c7a0", "e0b050", "e4e6ea", "bun")),
    # mecanico: overol azul, gorra gris y barba
    "mecanico": Spec(pants=hx("33527a"), boots=hx("2a2a30"), skin=hx("b9825a"), sleeve=hx("8a5a38"), cuff=hx("33527a"),
                     torso=torso_factory("33527a", under="b8602a", belt="2a2a30", pack="5a4a3a", stripe="f2a62c"),
                     head=head_gear_factory("b9825a", "8a8f98", "5a5e66", mark="f2a62c", beard="3a2a1c")),
    # motero: chaqueta de cuero negra con franja roja y casco con visera
    "motero": Spec(pants=hx("2b2b36"), boots=hx("1a1a20"), skin=hx("d6a066"), sleeve=hx("26262e"), cuff=hx("c8342a"),
                   torso=torso_factory("26262e", under="c8342a", belt="1a1a20", pack="3a3a44", stripe="c8342a", collar="4a4a56"),
                   head=head_gear_factory("d6a066", "1e1e26", "32323c", mark="c8342a", visor="3b6fa0")),
    # granjero: camisa de cuadros roja, overol y sombrero de paja
    "granjero": Spec(pants=hx("4a6a8a"), boots=hx("5a3e2a"), skin=hx("e0b088"), sleeve=hx("b0382e"), cuff=hx("e8d8b0"),
                     torso=torso_factory("b0382e", under="4a6a8a", belt="5a3e2a", pack="8a6a3e", stripe="7a2820"),
                     head=head_straw("e0b088", "d9b45a", "8a3a2a")),
}


def build_all():
    return {k: g.build_sheet(s) for k, s in SKINS.items()}


def main():
    sheets = build_all()
    for k, img in sheets.items():
        img.save(os.path.join(g.OUT, k + ".png"))
    print("skins:", ", ".join(sheets))
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        names = ["mateo", "lena"] + list(sheets)
        sheet = Image.new("RGBA", (len(names) * 24 * 5 + 20, 32 * 5 * 3 + 10), (60, 80, 60, 255))
        for i, n in enumerate(names):
            img = sheets[n] if n in sheets else Image.open(os.path.join(g.OUT, n + ".png"))
            for j, (row, col) in enumerate(((0, 0), (1, 0), (2, 0))):     # idle abajo/arriba/lado
                fr = img.crop((col * 24, row * 32, col * 24 + 24, row * 32 + 32)).resize((120, 160), Image.NEAREST)
                sheet.alpha_composite(fr, (i * 120 + 6, j * 160 + 4))
        sheet.save(path)


if __name__ == "__main__":
    main()
