// Íconos de habilidades (juego-36), armados en LibreSprite con la paleta de Kenney Tiny Dungeon
// y su contorno redondeado de 2 px (3f2631), para que combinen con los ítems del juego.
//   tools/libresprite.sh icons   -> assets/art/own/src/abilities/<id>.ase (pisa) + PNG del juego
// Cada ícono = su interior en letras de PAL ('.' vacío); el contorno lo agrega outline().
// Para retocar uno a mano: abrir su .ase en LibreSprite y después tools/libresprite.sh export
// (no volver a correr "icons", que lo regenera desde acá).
// Piezas de Kenney (CC0) copiadas: yunque (tile 74), daga (103), ladrillo de muro (40).

var PAL = {
	o: '3f2631', n: '262b44', s: '52607c', m: '8b9bb4', l: 'c0cbdc', i: 'e4edf9', w: 'ffffff',
	r: '763b36', b: 'bd6c4a', c: 'cf8254', k: 'eaa56c', f: 'f7c282', h: 'fec99c',
	R: 'e84537', P: 'ff706d', V: '9b4ca3', v: 'd176d0', Y: 'feae34', y: 'fee761'
};

var ICONS = {
	// Piel de Hierro: coraza de acero con cinturón.
	warrior_passive: [
		'',
		'',
		'..lll......mmm',
		'..llll....mmmm',
		'..llllliimmmmm',
		'..llllliimmmmm',
		'...lllliimmmm',
		'...lllliimmms',
		'...bbbbYYbbbb',
		'...lllliimmms',
		'....llliimms',
		'.....lliims',
		'......lims',
	],
	// Grito de Guerra: cuerno de guerra con boquilla y aros dorados.
	warrior_active: [
		'',
		'',
		'..........ffff',
		'..f.......frrf',
		'..kf......krrk',
		'..kkf.....kffc',
		'...kkf...kkkc',
		'...kkkf.kkkcc',
		'....kkYYYkcc',
		'....ckYYYkc',
		'.....cckkc',
		'.......cc',
	],
	// Mente Analítica: ojo arcano.
	mage_passive: [
		'',
		'',
		'',
		'',
		'',
		'....iiVVVVii',
		'...iiVvvwVVii',
		'..iiiVvnnVViii',
		'..iiiVVnnVVlll',
		'...iiVVVVVVll',
		'....llVVVVll',
	],
	// Bendición de las Obras: yunque de Kenney con un destello dorado.
	mage_active: [
		'',
		'',
		'',
		'.............y',
		'....lllllll.yYy',
		'..lmlllllll..y',
		'..lmlllllllmll',
		'..imlllllllmii',
		'..mmiiiiiiimmm',
		'...mmmmmmmmmm',
		'....mmmmmmm',
		'....lsmmmsl',
		'....lsssssl',
		'....lllllll',
	],
	// Paso Ligero: bota de cuero con ala.
	rogue_passive: [
		'',
		'',
		'......kkkk',
		'..w...cbbr',
		'..wi..cbbr',
		'..iwi.cbbr',
		'...iwlcbbr',
		'..wiilcbbr',
		'...lllcbbbkk',
		'......cbbbbbkc',
		'......cbbbbbbr',
		'......rrrrrrrr',
	],
	// Golpe Furtivo: daga de Kenney y el destello del golpe.
	rogue_active: [
		'',
		'',
		'.........i.w.i',
		'..........iwi',
		'.....l...wwwww',
		'....ll....iwi',
		'....ll...i.w.i',
		'....ll',
		'....ll',
		'....mm',
		'...llll',
		'....bb',
		'....bb',
	],
	// Muro Viviente: muralla almenada con el ladrillo de Kenney.
	tank_passive: [
		'',
		'',
		'..lll..ll..lll',
		'..mmm..mm..mmm',
		'..ssssssssssss',
		'..mmmmsmllmsmm',
		'..mmmmsmmmmsmm',
		'..ssssssssssss',
		'..lmsmmmmmmsml',
		'..mmsmmmmmmsmm',
		'..ssssssssssss',
		'..mmmmsmllmsmm',
		'..mmmmsmmmmsmm',
		'..ssssssssssss',
	],
	// Interposición: escudo de acero con cruz dorada.
	tank_active: [
		'',
		'',
		'...iiilYYmmmm',
		'...illlYYmmms',
		'...illlYYmmms',
		'...YYYYYYYYYY',
		'...llllYYmmms',
		'...llllYYmmms',
		'...llllYYmmms',
		'....lllYYmms',
		'....lllYYmms',
		'.....llYYms',
		'......lYYm',
		'.......YY',
	],
	// personajes-46 — Botín de Caza: lingote de hierro con destello.
	ranger_passive: [
		'',
		'',
		'',
		'',
		'...........y',
		'....llllll.yYy',
		'...liiiiiil.y',
		'..lmmmmmmmml',
		'..mmmmmmmmms',
		'..ssssssssss',
	],
	// Red de Caza: red de cuerda anudada.
	ranger_active: [
		'',
		'',
		'..b..b..b..b',
		'..kkkkkkkkkk',
		'..b..b..b..b',
		'..b..b..b..b',
		'..kkkkkkkkkk',
		'..b..b..b..b',
		'..b..b..b..b',
		'..kkkkkkkkkk',
		'..b..b..b..b',
		'..b..b..b..b',
		'..kkkkkkkkkk',
	],
	// Plegaria: vela encendida.
	cleric_passive: [
		'',
		'',
		'.......y',
		'......yYy',
		'......YRY',
		'.......Y',
		'......iil',
		'......iil',
		'......iil',
		'......iil',
		'......iil',
		'....mmmmmmm',
		'....sssssss',
	],
	// Luz Sanadora: corazón con la cruz blanca.
	cleric_active: [
		'',
		'',
		'',
		'...RR...RR',
		'..RPPR.RPPR',
		'..RPPRRRRRRR',
		'..RRRRwwRRRR',
		'..RRRwwwwRRR',
		'...RRRwwRRR',
		'....RRwwRR',
		'.....RRRR',
		'......RR',
	]
};

var SIZE = 16;
var col = app.pixelColor;

function rgba(hex) {
	return col.rgba(parseInt(hex.substr(0, 2), 16), parseInt(hex.substr(2, 2), 16), parseInt(hex.substr(4, 2), 16), 255);
}

function cell(rows, x, y) {
	var row = rows[y] || '';
	var ch = x < row.length ? row.charAt(x) : '.';
	return ch === '.' ? null : ch;
}

// Contorno de Kenney: todo píxel vacío a distancia dx² + dy² <= 5 de uno lleno.
function outline(rows, x, y) {
	for (var dy = -2; dy <= 2; dy++)
		for (var dx = -2; dx <= 2; dx++)
			if (dx * dx + dy * dy <= 5 && x + dx >= 0 && y + dy >= 0 && x + dx < SIZE && y + dy < SIZE && cell(rows, x + dx, y + dy))
				return true;
	return false;
}

var sprite = app.activeSprite;
var img = sprite.layer(0).cel(0).image;
var clear = col.rgba(0, 0, 0, 0);
var dark = rgba(PAL.o);
for (var id in ICONS) {
	var rows = ICONS[id];
	img.clear(clear);
	for (var y = 0; y < SIZE; y++)
		for (var x = 0; x < SIZE; x++) {
			var ch = cell(rows, x, y);
			if (ch) {
				if (!PAL[ch]) throw new Error(id + ': letra sin color ' + ch);
				img.putPixel(x, y, rgba(PAL[ch]));
			} else if (outline(rows, x, y)) {
				img.putPixel(x, y, dark);
			}
		}
	sprite.saveAs('assets/art/own/src/abilities/' + id + '.ase');
	console.log('icono ' + id);
}
