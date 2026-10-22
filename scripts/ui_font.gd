class_name UiFont
extends RefCounted
## Fuente pixel unica del juego (Pixelify Sans, licencia OFL en assets/fonts/OFL.txt).
## Se ve nitida desde 10 px; con tamanos menores pierde legibilidad.

const PATH := "res://assets/fonts/PixelifySans.ttf"

static var _font: Font


static func get_font() -> Font:
	if _font == null:
		var f = load(PATH)
		if f is FontFile:
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			f.hinting = TextServer.HINTING_NONE
			_font = f
		else:
			_font = ThemeDB.fallback_font
	return _font
