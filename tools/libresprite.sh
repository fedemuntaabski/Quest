#!/usr/bin/env bash
# Puente con LibreSprite para retocar a mano el arte propio (assets/art/own).
#   tools/libresprite.sh import   # crea assets/art/own/src/*.ase desde los PNG (no pisa .ase existentes)
#   tools/libresprite.sh export   # .ase -> PNG del juego (+ frames en own/vfx/index.json)
#   tools/libresprite.sh icons    # arma los íconos de habilidades (tools/libresprite_icons.js) y exporta
#   tools/libresprite.sh frames   # SpriteFrames de los héroes desde own/characters (export lo corre al final)
# Flujo: build_own_art.gd genera la base -> import -> retocar el .ase en LibreSprite
# -> export -> correr el juego. Con un .ase presente, build_own_art.gd ya no pisa ese PNG.
# dungeon_decor.ase (mazmorra-32) = interior de las salas: fila 0 de celdas de 16 px en el orden
# OWN_DECOR de build_own_art.gd (las animadas = 4 celdas seguidas), filas 1-2 el altar (32x32 activo
# y usado). Después de exportar: tools/build_tilesets.gd si cambió el ancho.
# abilities/<héroe>_<passive|active>.ase = un ícono de habilidad de 16x16 (juego-36), armado por
# tools/libresprite_icons.js con la paleta y el contorno de 2 px de Kenney; "icons" los pisa.
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
mkdir -p "$SRC/vfx" "$SRC/abilities" "$SRC/characters"
# personajes-46: own/characters/<prefijo>_{attack,fall}.png = tiras de 4 cuadros (48x44, cuerpo 0x72 en el
# lugar del idle) que arma tools/build_personajes_art.gd; mismo formato que vfx (index.json propio).
# "frames" escribe resources/sprite_frames/hero_<prefijo>.tres (idle/run/hit 0x72 + attack/fall de las tiras).
STRIP_DIRS="vfx characters"

case "${1:-}" in
import)
	[ -f "$SRC/items.ase" ] || "$LS" -b "$OWN/items.png" --save-as "$SRC/items.ase" >/dev/null
	[ -f "$SRC/dungeon_decor.ase" ] || { "$LS" -b "$OWN/dungeon_decor.png" --save-as "$SRC/dungeon_decor.ase" >/dev/null && echo "import dungeon_decor"; }
	for dir in $STRIP_DIRS; do
	for png in "$OWN"/$dir/*.png; do
		name=$(basename "$png" .png)
		[ -f "$SRC/$dir/$name.ase" ] && continue
		# Tira horizontal -> frames sueltos name_0.png.. (LibreSprite abre la secuencia como animación).
		python -I - "$png" "$OWN/$dir/index.json" "$TMP/$name" <<'EOF'
import json, sys
from PIL import Image
png, index, out = sys.argv[1:]
e = json.load(open(index))[png.replace("\\", "/").rsplit("/", 1)[1][:-4]]
im = Image.open(png)
for i in range(e["frames"]):
    x, y = (i % e["columns"]) * e["frame_w"], (i // e["columns"]) * e["frame_h"]
    im.crop((x, y, x + e["frame_w"], y + e["frame_h"])).save(f"{out}_{i}.png")
EOF
		"$LS" -b "$TMP/${name}_0.png" --save-as "$SRC/$dir/$name.ase" >/dev/null
		echo "import $name"
	done
	done
	;;
frames)
	python -I - <<'EOF'
import json, os
idx = json.load(open("assets/art/own/characters/index.json"))
FPS = {"idle": 6.0, "run": 10.0, "hit": 1.0}
for prefix in sorted({k.rsplit("_", 1)[0] for k in idx}):
    ext, sub, anims = [], [], []
    def frames_of(paths):
        ids = []
        for p in paths:
            ext.append(f'[ext_resource type="Texture2D" path="res://{p}" id="{len(ext) + 1}_t"]')
            ids.append(f'ExtResource("{len(ext)}_t")')
        return ids
    for anim in ("idle", "run", "hit"):
        paths, i = [], 0
        while os.path.exists(f"assets/art/characters/{prefix}_{anim}_anim_f{i}.png"):
            paths.append(f"assets/art/characters/{prefix}_{anim}_anim_f{i}.png"); i += 1
        anims.append((anim, frames_of(paths), anim != "hit", FPS[anim]))
    for anim in ("attack", "fall"):
        e = idx[f"{prefix}_{anim}"]
        strip = frames_of([f"assets/art/own/characters/{prefix}_{anim}.png"])[0]
        ids = []
        for i in range(e["frames"]):
            sid = f"{anim}_{i}"
            sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = {strip}\nregion = Rect2({i * e["frame_w"]}, 0, {e["frame_w"]}, {e["frame_h"]})\n')
            ids.append(f'SubResource("{sid}")')
        anims.append((anim, ids, False, float(e["fps"])))
    body = ", ".join("{\n\"frames\": [" + ", ".join("{\n\"duration\": 1.0,\n\"texture\": " + t + "\n}" for t in ids) + f"],\n\"loop\": {str(loop).lower()},\n\"name\": &\"{a}\",\n\"speed\": {fps}\n}}" for a, ids, loop, fps in anims)
    out = '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n[resource]\nanimations = [" + body + "]\n"
    open(f"resources/sprite_frames/hero_{prefix}.tres", "w", newline="\n").write(out)
    print("frames", prefix)
EOF
	;;
icons)
	# juego-36: arma los 8 íconos de habilidades en LibreSprite (tools/libresprite_icons.js) y los exporta.
	python -I -c "import sys; from PIL import Image; Image.new('RGBA', (16, 16)).save(sys.argv[1])" "$TMP/blank.png"
	"$LS" -b "$TMP/blank.png" --script tools/libresprite_icons.js 2>&1 | grep '^icono' || true
	"$0" export
	;;
export)
	[ -f "$SRC/items.ase" ] && "$LS" -b "$SRC/items.ase" --save-as "$OWN/items.png" >/dev/null && echo "export items"
	[ -f "$SRC/dungeon_decor.ase" ] && "$LS" -b "$SRC/dungeon_decor.ase" --save-as "$OWN/dungeon_decor.png" >/dev/null && echo "export dungeon_decor"
	for ase in "$SRC"/abilities/*.ase; do
		[ -f "$ase" ] || continue
		name=$(basename "$ase" .ase)
		"$LS" -b "$ase" --save-as "$OWN/abilities/ability_$name.png" >/dev/null && echo "export ability $name"
	done
	for dir in $STRIP_DIRS; do
	for ase in "$SRC"/$dir/*.ase; do
		[ -f "$ase" ] || continue
		name=$(basename "$ase" .ase)
		"$LS" -b "$ase" --sheet "$OWN/$dir/$name.png" --data "$TMP/$name.json" --format json-array --sheet-type horizontal >/dev/null
		python -I - "$OWN/$dir/index.json" "$name" "$TMP/$name.json" <<'EOF'
import json, sys
index, name, data = sys.argv[1:]
d = json.load(open(data)); idx = json.load(open(index))
f = d["frames"][0]["sourceSize"]
idx[name] = {"frame_w": f["w"], "frame_h": f["h"], "frames": len(d["frames"]), "columns": len(d["frames"]), "fps": idx.get(name, {}).get("fps", 15)}
json.dump(idx, open(index, "w"), indent="\t", sort_keys=True)
EOF
		echo "export $name"
	done
	done
	"$0" frames
	;;
*)
	sed -n 2,14p "$0"; exit 1 ;;
esac
