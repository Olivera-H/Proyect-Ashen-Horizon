#!/usr/bin/env bash
# Exporta Ashen Horizon a Web y lo sirve en el puerto 8000.
# Pensado para GitHub Codespaces (no hace falta pantalla ni instalar Godot a mano),
# pero funciona en cualquier Linux con curl, unzip y python3.
#
# Uso:   bash tools/web.sh            (exporta y sirve)
#        EXPORT_ONLY=1 bash tools/web.sh   (solo exporta a build/web)
set -euo pipefail

VERSION="4.3-stable"
GODOT_HOME="$HOME/godot-4.3"
TPL_DIR="$HOME/.local/share/godot/export_templates/4.3.stable"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8000}"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}"

mkdir -p "$GODOT_HOME"

if [ ! -x "$GODOT_HOME/godot" ]; then
  echo ">> Descargando Godot 4.3 (editor, una sola vez)..."
  curl -fsSL -o "$GODOT_HOME/godot.zip" "$BASE/Godot_v${VERSION}_linux.x86_64.zip"
  unzip -oq "$GODOT_HOME/godot.zip" -d "$GODOT_HOME"
  mv "$GODOT_HOME/Godot_v${VERSION}_linux.x86_64" "$GODOT_HOME/godot"
  chmod +x "$GODOT_HOME/godot"
  rm -f "$GODOT_HOME/godot.zip"
fi

if [ ! -f "$TPL_DIR/web_nothreads_release.zip" ]; then
  echo ">> Descargando plantillas de exportación (una sola vez, pesan ~1 GB)..."
  curl -fsSL -o "$GODOT_HOME/templates.tpz" "$BASE/Godot_v${VERSION}_export_templates.tpz"
  mkdir -p "$TPL_DIR"
  unzip -oj "$GODOT_HOME/templates.tpz" 'templates/web_nothreads_*' 'templates/version.txt' -d "$TPL_DIR"
  rm -f "$GODOT_HOME/templates.tpz"
fi

PRESETS="$ROOT/export_presets.cfg"
if [ ! -f "$PRESETS" ]; then
  cat > "$PRESETS" <<'EOF'
[preset.0]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/web/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
EOF
elif ! grep -q 'name="Web"' "$PRESETS"; then
  echo "Ya tienes un export_presets.cfg sin preset 'Web'. Crea uno llamado Web en Proyecto > Exportar." >&2
  exit 1
fi

mkdir -p "$ROOT/build/web"
echo ">> Importando recursos..."
"$GODOT_HOME/godot" --headless --path "$ROOT" --import > /dev/null 2>&1 || true
echo ">> Exportando a Web..."
"$GODOT_HOME/godot" --headless --path "$ROOT" --export-release "Web" "$ROOT/build/web/index.html"

if [ -n "${EXPORT_ONLY:-}" ]; then
  echo ">> Listo: build/web/index.html"
  exit 0
fi

echo ">> Sirviendo en el puerto $PORT. Abre la pestaña PUERTOS y pulsa el icono del navegador."
cd "$ROOT/build/web"
exec python3 -m http.server "$PORT"
