# Puesto Fronterizo — prototipo 3D

Juego de terror y decisiones en **primera persona**. Eres el comandante de un
puesto de registro fronterizo en el turno de noche y tienes que aguantar hasta el
traslado sin que ningún medidor toque su límite. No hay camino honesto: si te
dejas comprar te delatan; si eres intachable, estorbas.

Referencias: *Papers, Please* + *Beholder* + *This Is the Police*, con la cámara y
la atmósfera de un *Shift at Midnight* / PSX horror.

## Cómo abrirlo

1. Descarga **Godot 4.3 o superior**, versión **estándar** (NO la .NET/Mono):
   https://godotengine.org/download
2. Godot → **Import** → elige la carpeta `juego/` (la que tiene `project.godot`).
3. **F5** para jugar.

Sin dependencias, sin assets externos: el escenario está hecho con cajas grises
generadas por código.

## Controles

| Tecla | Acción |
|---|---|
| WASD | Moverte |
| Espacio | Saltar |
| Ratón | Mirar (también mientras se acerca un vehículo) |
| E | Interactuar: ventanilla, puerta de salida, y **hablar con un compañero** |
| ESC | Menú de pausa (durante el turno) · clic para recapturar el ratón |

## Qué hay implementado (greybox)

- **Menú principal:** título + **3 ranuras** independientes. Cada ranura es el
  autoguardado de su propia partida (continuar / empezar de cero con confirmación).
- **Guardado automático:** al empezar cada turno y tras resolver cada situación.
  El menú de pausa (ESC) tiene "Guardar y salir al menú". Al morir o ganar se
  borra la ranura.
- **Opciones** (menú y pausa): sensibilidad del ratón, invertir eje Y, pantalla
  completa, volumen general. Se guardan en `user://settings.cfg`.
- **Primera persona:** controlador con cámara, colisión, salto y raycast de interacción.
- **Escenario:** la caseta (`environment.glb`), ventanilla con hueco real,
  escritorio, litera y **puerta trasera abrible** (E). El techo tiene un vano
  atrás por el que se sale al desierto.
- **Exterior explorable:** suelo con colisión + `exterior.glb` (carretera, 2
  talanqueras animadas, valla, rocas, mesas). Puedes salir a andar por fuera.
- **Iluminación de ambiente:** niebla, luna direccional, lámpara cálida por dentro.
- **Bucle de turno:** te acercas a la ventanilla → pulsas E → un vehículo entra
  por la carretera y para enfrente (puedes mirar, no andar) → panel de decisión
  con 2–4 opciones → consecuencias → la talanquera sube y sigue, o retrocede.
- **5 medidores:** Caja, Lealtad, Sospecha de mandos, Presión del cártel, Nervio.
- **Compañeros (`data/crew.json`):** 4, cada uno con rasgo y **confianza** 0–100,
  con **barras en el HUD** (arriba a la izquierda; `!` hostil, `+` leal, `[orden]`).
  Bandas: leal (≥68) puede *mejorar* el resultado de ciertas situaciones (`crew_assist`);
  hostil (≤26) puede *venderte* (`crew_betray`) o filtrar a los mandos entre turnos;
  en medio, neutro. La confianza se mueve con: **dinero** (sobre), **trago**,
  **prometer cubrirlo**, **amenaza** (obedece ahora pero baja la confianza), pagar/no
  pagar la nómina, y decisiones concretas en las situaciones (`crew_trust`).
- **Compañeros vivos (`companion.gd`):** son NPCs que rondan puntos dentro y
  fuera de la caseta (`WAYPOINTS`/`LINKS` en `world.gd`). Cada pocos segundos
  "deciden" según su confianza:
  - **leal/neutro** → se acercan a ti, hacen el saludo militar (rotando el brazo)
    y sueltan un parte (bocadillo `Label3D`); si te confían de sobra, a veces te
    cubren algo (−sospecha).
  - **hostil** → se apartan a un rincón **fuera de tu vista** y hacen algo turbio
    (roban de la caja, falsean el libro, filtran). Si te acercas o los miras
    (cono de visión + raycast), **disimulan y se van**. Si lo hacen sin que los
    veas, queda un `did_shady`: al hablarles aparece **"Confrontarlo"**.
- **Hablar / dar órdenes:** mira a un compañero y **E** (también en el paso entre
  turnos). Acciones de confianza (sobre / trago / prometer / amenazar) y órdenes
  del turno (*aprieta al próximo*, *no hables con nadie*, *quítate de en medio*).
- **Puerta trasera:** **E abre/cierra** la hoja. No termina el turno — es para
  salir a explorar. El turno se cierra durmiendo en la **litera** (cuando la fila
  está cubierta).
- **HUD:** panel de medidores con **barras y color** (verde → ámbar → rojo según
  cerca del límite), panel de equipo con barras de confianza, deltas de la
  decisión como chips coloreados, y transiciones suaves.
- **5 turnos**, dificultad creciente.
- **4 finales de derrota** (uno por medidor) + final de victoria.

## Lo que NO está y es el trabajo gordo (ver PLAN.md)

- Arte 3D real: modelos, texturas, props, personajes.
- Dirección de luz y post-proceso (shader PSX, grano, dithering).
- Capa de terror **visual**: anomalías, sustos, sonido ambiente.
- Animación mínima de visitantes (o enemigos que "teleportan", sin rig).
- Audio (buses ya cableados al volumen general, pero no hay sonido todavía).

## Añadir contenido sin tocar código

Todo el contenido vive en **`data/encounters.json`**. Cada situación:

```json
{
  "id": "identificador_unico",
  "speaker": "Quién llega a la ventanilla",
  "text": "Descripción de la situación.",
  "day_min": 1,
  "weight": 10,
  "once": true,
  "vehicle": "sedan",
  "choices": [
    {
      "label": "Texto del botón",
      "result": "Qué pasa tras elegirlo.",
      "is_bribe": true,
      "gate_action": "deny",
      "effects": { "cash": 200, "nerve": -5, "command_suspicion": 6 },
      "crew_trust": { "nava": 8, "ruiz": -6 },
      "crew_assist": { "id": "nava", "min_trust": 60, "result": "...", "effects": { "cash": 100 } },
      "crew_betray": { "id": "ruiz", "max_trust": 30, "result": "...", "effects": { "command_suspicion": 8 } }
    }
  ]
}
```

Claves válidas de `effects`: `cash`, `loyalty`, `command_suspicion`, `cartel_pressure`, `nerve`.

`vehicle` (opcional): `sedan` | `pickup` | `van` | `truck`. **Toda situación llega en
vehículo**; si falta este campo se usa `sedan`. El coche entra desde la izquierda por el
carril cercano, abre la talanquera de entrada y para enfrente de la ventanilla; solo
entonces aparece el panel de texto.

`gate_action` (opcional, por opción): `"pass"` (por defecto) = la talanquera de salida
sube y el vehículo sigue de largo; `"deny"` = se queda bajada y el vehículo retrocede.

Ganchos de equipo (opcionales, por opción): `crew_trust` mueve la confianza de cada
compañero; `crew_assist` = si ese compañero te confía (`min_trust`) y no le diste la
orden "quítate de en medio", aplica su bonus y lo cuenta en el resultado; `crew_betray`
= si su confianza es baja (`max_trust`) o lo amenazaste, te vende (salvo orden
"no hables con nadie" / "quítate de en medio"). Los compañeros, sus acciones y órdenes
están en **`data/crew.json`**.

Balance (medidores iniciales, nómina, duración, opciones de Nervio) en **`data/config.json`**.

## Estructura

```
juego/
├── project.godot              config del proyecto (escena principal: main_menu.tscn)
├── scenes/
│   ├── main_menu.tscn         escena principal (root Node + main_menu.gd)
│   └── world.tscn             la partida (root Node3D + world.gd; lo demás por código)
├── scripts/
│   ├── game_state.gd          TODA la lógica de juego + guardado por ranuras (autoload "GameState")
│   ├── settings.gd            ajustes globales, user://settings.cfg (autoload "Settings")
│   ├── main_menu.gd           menú principal: 3 ranuras, opciones, salir
│   ├── options_panel.gd       panel de opciones reutilizable (menú y pausa)
│   ├── world.gd               monta escenario + luces + jugador; orquesta el flujo y la pausa
│   ├── player.gd              controlador en primera persona (auto-ensamblado)
│   ├── interactable.gd        objeto mirable + "E" (ventanilla, litera)
│   ├── companion.gd           NPC companero: ronda, decide, informa u oculta cosas
│   ├── vehicle.gd              mueve un vehiculo en X hasta un punto y avisa al llegar
│   ├── boom_gate.gd            sube/baja el brazo de una talanquera (tween)
│   └── hud.gd                 HUD y panel de decisiones (CanvasLayer, por código)
├── blender/                   scripts bpy que generan los modelos (ver abajo)
│   ├── build_environment.py   -> models/environment.glb   (caseta y mobiliario)
│   ├── build_exterior.py      -> models/exterior.glb      (desierto, carretera, talanqueras)
│   ├── build_crew.py          -> models/crew_<id>.glb     (un glb por companero; brazo "arm_r" para el saludo)
│   └── build_vehicles.py      -> models/vehicle_{sedan,pickup,van,truck}.glb
├── models/                    .glb generados; world.gd los instancia si existen
└── data/
    ├── config.json            balance
    ├── crew.json              los 4 compañeros: rasgo, confianza inicial, acciones
    └── encounters.json        contenido (situaciones)

Partidas guardadas: `user://save_1.json` .. `save_3.json`. Ajustes: `user://settings.cfg`.
En Windows, `user://` es `%APPDATA%\Godot\app_userdata\<nombre del proyecto>\`.
```

## Modelos 3D

Se generan por script, no a mano. En Blender: pestaña **Scripting** → abrir el
`.py` de `blender/` → **Run Script** (Alt+P). Cada uno exporta su `.glb` a
`models/` y guarda un `.blend` para retocar.

`world.gd` instancia `environment.glb`, `exterior.glb`, `crew_<id>.glb` y los
`vehicle_*.glb` **si existen**; si falta alguno, el juego cae al greybox (o,
para un vehiculo, el encuentro sigue solo con texto) y sigue siendo jugable.

**No arrastres los `.glb` a `world.tscn`.** La escena tiene que quedar solo con el
nodo raiz `World` + `world.gd`; si metes los modelos como nodos se instancian
DOS veces (por la escena y por codigo): duplicados, parpadeo y los 4 vehiculos
clavados en el origen dentro de la caseta. Para recolocar algo, edita el script
de Blender o `world.gd`, no la escena.

## Trabajar desde otra PC (Git)

El repo lleva todo lo necesario: scripts, JSON y los `.glb` ya generados. En la
otra maquina:

```
git clone https://github.com/Yorfad/juego.git
```

1. Instala **la misma version de Godot** (4.7.x) y abre la carpeta. La primera vez
   re-importa los assets (unos segundos). F5 y a trabajar.
2. **Solo para programar/balancear** (scripts, encuentros, HUD): no hace falta
   Blender, los modelos ya estan en `models/`.
3. **Para tocar los modelos 3D**: instala Blender y usa los `.py` de `blender/`.
   `PROJECT_DIR` se autodetecta si primero abres el `.blend` correspondiente
   (`File > Open` -> `blender/xxx.blend`) y luego corres el `.py`. Si abres Blender
   en blanco, cambia la linea `PROJECT_DIR = r"..."` (fallback) al principio del
   script.
4. `blender/.gdignore` evita que Godot intente importar los `.blend` (asi no da
   error si la ruta de Blender no esta configurada en Editor Settings).

**Lo que NO viaja por Git:** las partidas guardadas y los ajustes viven en
`user://` (`%APPDATA%\Godot\app_userdata\...`), fuera del repo. Para llevarte una
partida, copia el `save_N.json` a mano. `.godot/` (cache) tampoco se sube: se
regenera al abrir.

Para subir cambios: `git add -A && git commit -m "..." && git push`.

Ver **`PLAN.md`** para la hoja de ruta y la regla de "seguir o congelar".
