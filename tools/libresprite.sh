#!/usr/bin/env bash
# Puente con LibreSprite para retocar a mano el arte propio (assets/art/own).
#   tools/libresprite.sh import   # crea assets/art/own/src/*.ase desde los PNG (no pisa .ase existentes)
#   tools/libresprite.sh export   # .ase -> PNG del juego (+ frames en own/vfx/index.json)
# Flujo: build_own_art.gd genera la base -> import -> retocar el .ase en LibreSprite
# -> export -> correr el juego. Con un .ase presente, build_own_art.gd ya no pisa ese PNG.
# items.ase = una imagen de 16 px por celda (orden OWN_CELLS en build_own_art.gd; no
# cambiar el ancho). vfx/<hoja>.ase = animación, un frame por cuadro (se puede
# agregar o quitar frames; el tamaño del lienzo es el frame_w/frame_h del índice).
# LibreSprite: $LIBRESPRITE o E:/LibreSprite/libresprite.exe.
set -euo pipefail
cd "$(dirname "$0")/.."
LS="${LIBRESPRITE:-/e/LibreSprite/libresprite.exe}"
OWN=assets/art/own
SRC=$OWN/src
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
[ -x "$LS" ] || { echo "No encuentro LibreSprite en $LS (definí LIBRESPRITE)"; exit 1; }
mkdir -p "$SRC/vfx"

case "${1:-}" in
import)
	[ -f "$SRC/items.ase" ] || "$LS" -b "$OWN/items.png" --save-as "$SRC/items.ase" >/dev/null
	for png in "$OWN"/vfx/*.png; do
		name=$(basename "$png" .png)
		[ -f "$SRC/vfx/$name.ase" ] && continue
		# Tira horizontal -> frames sueltos name_0.png.. (LibreSprite abre la secuencia como animación).
		python -I - "$png" "$OWN/vfx/index.json" "$TMP/$name" <<'EOF'
import json, sys
from PIL import Image
png, index, out = sys.argv[1:]
e = json.load(open(index))[png.replace("\\", "/").rsplit("/", 1)[1][:-4]]
im = Image.open(png)
for i in range(e["frames"]):
    x, y = (i % e["columns"]) * e["frame_w"], (i // e["columns"]) * e["frame_h"]
    im.crop((x, y, x + e["frame_w"], y + e["frame_h"])).save(f"{out}_{i}.png")
EOF
		"$LS" -b "$TMP/${name}_0.png" --save-as "$SRC/vfx/$name.ase" >/dev/null
		echo "import $name"
	done
	;;
export)
	[ -f "$SRC/items.ase" ] && "$LS" -b "$SRC/items.ase" --save-as "$OWN/items.png" >/dev/null && echo "export items"
	for ase in "$SRC"/vfx/*.ase; do
		[ -f "$ase" ] || continue
		name=$(basename "$ase" .ase)
		"$LS" -b "$ase" --sheet "$OWN/vfx/$name.png" --data "$TMP/$name.json" --format json-array --sheet-type horizontal >/dev/null
		python -I - "$OWN/vfx/index.json" "$name" "$TMP/$name.json" <<'EOF'
import json, sys
index, name, data = sys.argv[1:]
d = json.load(open(data)); idx = json.load(open(index))
f = d["frames"][0]["sourceSize"]
idx[name] = {"frame_w": f["w"], "frame_h": f["h"], "frames": len(d["frames"]), "columns": len(d["frames"]), "fps": idx.get(name, {}).get("fps", 15)}
json.dump(idx, open(index, "w"), indent="\t", sort_keys=True)
EOF
		echo "export $name"
	done
	;;
*)
	sed -n 2,11p "$0"; exit 1 ;;
esac
