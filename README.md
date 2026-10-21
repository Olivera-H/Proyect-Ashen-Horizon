# Ashen Horizon

Juego de **acción, aventura y supervivencia en mundo abierto** con vista cenital 2D y pixel art, pensado para **móvil en horizontal**. Título provisional.

Hace 14 meses el virus **Ceniza** colapsó las ciudades; se propaga con esporas que caen con la lluvia ácida. Este prototipo cubre el **Acto I de Mateo Vargas**, ex-bombero que busca el **Laboratorio Horizonte**, donde podría estar el origen del brote.

| Día | Noche + lluvia ácida |
|---|---|
| ![Día](docs/captura-dia.png) | ![Noche](docs/captura-noche.png) |

## Cómo ejecutarlo

1. Instala **[Godot 4.3](https://godotengine.org/download)** (versión estándar, no .NET).
2. Abre Godot → *Importar* → selecciona `project.godot` de esta carpeta.
3. Pulsa **F5** (la escena principal ya está configurada).

La primera vez Godot importa el proyecto y registra las clases; si ves errores de clases desconocidas, cierra y vuelve a abrir el proyecto.

### Controles

| Acción | Teclado (PC) | Móvil |
|---|---|---|
| Moverse | WASD / flechas | Joystick flotante en la mitad izquierda |
| Correr | Shift | Llevar el joystick al borde |
| Atacar | J / Z | Botón ATACAR |
| Esquivar | Espacio | Botón ESQUIVA |
| Reparar arma (2 chatarras) | R | Botón REPARAR |
| Linterna | F | Botón LUZ |

En PC también puedes usar los botones táctiles con el mouse.

## Qué incluye el prototipo

- **Mateo** jugable, con sus ventajas pasivas: más vida y estamina, y más daño cuerpo a cuerpo (peor puntería). **Lena** ya está definida en `characters.gd` para cuando se agregue la selección.
- **Supervivencia:** vida, estamina, hambre, sed e infección; inventario limitado (chatarra); arma improvisada con **desgaste** y reparación.
- **Combate:** golpe cuerpo a cuerpo con aturdimiento y empuje, esquiva con invulnerabilidad breve.
- **Ruido:** correr, atacar y esquivar hacen ruido y atraen zombis. Es la base para las armas de fuego con silenciador.
- **Zombis:** caminantes (lentos, peligrosos en grupo), **corredores** (ven de más lejos y alcanzan casi al jugador) y **tanque** (220 de vida, apenas retrocede). Oyen, ven en cono (más lejos si llevas linterna) y pierden el rastro.
- **Minimapa estilo GTA:** posición y orientación del jugador, objetivos (los lejanos se pegan al borde), alertas de zombis cercanos, anillo de ruido y **niebla de guerra** que se despeja al explorar.
- **Mundo:** ciudad procedural con calles, edificios con puerta, autopista con barricadas y zona industrial al este.
- **Atmósfera:** ciclo día/noche con linterna, lluvia ácida y niebla tóxica (dañan al aire libre; los edificios protegen).
- **Refugio:** al entrar se guarda el progreso (punto de reaparición), recuperas vida y los zombis pierden tu rastro.
- **Historia:** 6 notas repartidas por el mapa y **eventos aleatorios** (estruendos que mueven a los infectados, cajas de suministros marcadas en el minimapa).
- **Meta:** llegar al Laboratorio Horizonte.

Todo el arte es **placeholder generado por código** (`pixel_art.gd`), así que el proyecto no depende de archivos de imagen. Cuando tengas arte real, reemplaza esas funciones por texturas importadas.

## Estructura

```
scenes/main.tscn        Escena principal (solo carga main.gd)
scripts/
  main.gd               Arma el juego: mundo, jugador, zombis, ciclo día/noche, clima, eventos
  world.gd              Generación procedural del mapa, colisiones y objetivos
  player.gd             Movimiento, estamina, combate, supervivencia, ruido, linterna
  zombie.gd             IA (vagar / investigar / perseguir) y variantes
  characters.gd         Datos de Mateo y Lena (estadísticas y paleta)
  hud.gd                Barras, reloj, objetivos, avisos, pantallas de fin
  minimap.gd            Minimapa con niebla de guerra
  touch_controls.gd     Joystick y botones táctiles
  weather.gd            Lluvia ácida y niebla tóxica
  input_setup.gd        Acciones de entrada (teclado)
  pixel_art.gd          Arte placeholder generado por código
docs/DISENO.md          Documento de diseño (historia, mapa, motor, hoja de ruta)
```

## Exportar a Android

1. En Godot: *Proyecto → Exportar → Añadir… → Android* (requiere el SDK de Android y la plantilla de exportación; la guía oficial está en la documentación de Godot).
2. La orientación ya está en **horizontal** (`window/handheld/orientation`).
3. `export_presets.cfg` y los keystores están en `.gitignore` a propósito: no los subas al repositorio.

## Hoja de ruta

Ver [docs/DISENO.md](docs/DISENO.md).
