# Ashen Horizon: documento de diseño

## 1. Concepto

- **Género:** acción, aventura y supervivencia en mundo abierto, vista cenital 2D.
- **Estilo:** pixel art atmosférico, iluminación dinámica (día/noche, linternas) y clima (lluvia ácida, niebla tóxica).
- **Plataforma:** móvil en horizontal (Android primero), jugable también con teclado en PC.
- **Motor:** Godot 4.3 (GDScript), renderizador Compatibility.

## 2. Protagonistas

**Mateo Vargas, ex-bombero rescatista** *(ventaja: resistencia física)*
Estaba de turno cuando se evacuó el distrito central. Salvó a decenas, pero perdió a su hermano menor en un edificio que no alcanzó a despejar. Aguanta más golpes, corre más antes de cansarse y golpea más fuerte, pero tiene peor puntería. Sigue un rastro que sugiere que el brote **no fue un accidente**.

**Lena Ortiz, ex-técnica de laboratorio** *(ventaja: precisión y crafteo)*
Trabajó para una subcontratista de Horizonte y firmó informes maquillados. Apunta mejor, recarga más rápido y rinde más al craftear químicos y botiquines, pero es frágil cuerpo a cuerpo. Busca la **prueba** y una posible cura.

**Arco compartido**

- **Acto I:** cada uno sobrevive, asegura su primer refugio y encuentra notas que apuntan a Horizonte.
- **Acto II:** se cruzan en la zona industrial; pueden aliarse o desconfiar según las decisiones con los PNJs.
- **Acto III:** el laboratorio revela que el virus se liberó **a propósito** para probar una "cura" en población real.
- **Finales:** liberar la verdad, sellar el laboratorio o quedarse con la cura.

La historia se cuenta con notas ambientales, grabaciones, eventos aleatorios y supervivientes con intereses propios.

## 3. Mapa

| Sector | Descripción | Riesgo |
|---|---|---|
| Periferia / inicio | Suburbios y gasolineras | Bajo |
| Casco urbano en ruinas | Calles estrechas, mucho interior | Medio |
| Autopista interestatal | Barricadas y convoyes, campo abierto | Medio-alto (corredores) |
| Zona industrial | Fábricas y depósitos, aire tóxico | Alto |
| Hospital y distrito sanitario | Cuarentenas fallidas | Alto |
| Refugios subterráneos | Metro y búnkeres, oscuridad total | Variable |
| Laboratorio Horizonte | Clímax | Muy alto (tanques) |

Zonas de riesgo transversales: nidos de infectados, niebla tóxica, lluvia ácida y territorios de bandidos. Para móvil, el mapa final debe cargarse por **chunks**.

## 4. Estado del prototipo (Acto I de Mateo)

Hecho: movimiento, estamina, esquiva, combate cuerpo a cuerpo con desgaste, ruido, hambre/sed/infección, inventario limitado, tres tipos de zombi, minimapa con niebla de guerra, ciclo día/noche, lluvia ácida, niebla tóxica, refugio con checkpoint, notas, eventos aleatorios y controles táctiles.

## 5. Hoja de ruta sugerida

1. **Lena jugable** + pantalla de selección de personaje.
2. **Armas de fuego**: pistola, escopeta, rifle y ballesta; munición escasa; silenciadores y balística.
3. **Crafteo real**: chatarra, tela y químicos → botiquines, munición, reparaciones; mesa de trabajo en el refugio.
4. **Refugios asegurables**: barricar cualquier edificio, almacenamiento de loot y guardado persistente en disco.
5. **PNJs y diálogos** con decisiones que afecten los finales.
6. **Mapa por chunks** y sectores completos (hospital, metro, laboratorio).
7. **Arte y sonido reales**: sprites, tilesets, música ambiental y efectos.
8. **Pulido móvil**: rendimiento, ajustes de controles, exportación a Android.
