# Plan — Puesto Fronterizo (3D, primera persona)

Es un hobby. La economía del usuario no depende de esto. Plazo objetivo: **hasta
~1 año** si hace falta, con tal de que salga divertido y con personalidad.

Regla base: **si el juego funciona, se actualiza; si no, se deja con las mecánicas
que tiene y se cierra.** Sin bucle de "una actualización más".

Decisión ya tomada: **3D en primera persona**, aunque cueste ~2x que en 2D,
porque el miedo y la personalidad de las mecánicas se pierden en 2D.

---

## Alcance CONGELADO (lo que sale sí o sí, funcione o no)

- Primera persona, un **único escenario**: la caseta del puesto (interior + la
  ventanilla + un exterior mínimo tras el cristal).
- Bucle: acercarte a la ventanilla → atender → decisión de 2–4 opciones → consecuencias.
- 5 medidores: Caja, Lealtad, Sospecha de mandos, Presión del cártel, Nervio.
- El dilema central: ser limpio sube Sospecha; ser corrupto sube Cártel y Sospecha
  por otro lado. No hay ruta segura.
- Nómina al final del turno (en la litera) + fase de Nervio (religión/vicio).
- 5 turnos, dificultad creciente, equipo nuevo a mitad.
- Capa de terror **visual**: 4–6 anomalías guionizadas (una figura que aparece y
  se va, luces que fallan, el visitante que no debería estar ahí...).
- Enemigos/apariciones **sin rig**: estáticas o que "teleportan". Nada de ciclos de animación.
- 40–50 situaciones escritas.
- Estética PSX: baja resolución interna, niebla, grano/dither por shader. Tapa que no eres artista 3D.
- Menú, guardado, opciones de audio/ratón. Un idioma: español.

Coste de esta fase: **0 $** aparte de la suscripción de Claude. Godot, Blender,
Krita, packs de assets libres (Kenney, itch.io), sonido de freesound.
Presupuesto flexible más adelante para 1–2 packs de assets (10–40 $) si hace falta.

---

## Fases

### Fase 0 — Esqueleto 3D  ✅ HECHO
Proyecto Godot que corre: primera persona, escenario en cajas grises, ventanilla
que dispara las situaciones, 5 medidores, fin de turno en la litera, fase de
Nervio, 5 turnos, finales. Contenido en JSON editable.

### Fase 1 — Vertical slice jugable  (~2–4 meses)
Un turno completo que ya se *sienta* como el juego final:
- Modelar/vestir la caseta con arte real (o packs) + dirección de luz.
- Shader PSX + niebla + grano. Sonido ambiente (zumbido de fluorescente, viento, radio).
- Interacción con el visitante: que se acerque, entregue un documento, reaccione.
- 2–3 anomalías visuales funcionando.
- 15–20 situaciones buenas, balanceadas para que una partida honesta y una
  corrupta pierdan por motivos distintos.
- Menú + guardado básicos.
- **Entregable:** build privada para 5–10 testers. ¿Da miedo? ¿Se entiende el dilema?

### Fase 2 — Validación en Steam  (puerta de decisión)
- Pagar los **100 $ de Steam Direct** (única vez; se recuperan al facturar 1 000 $).
- Página de Steam con cápsula, tráiler corto, 6–8 capturas.
- **Demo** (el vertical slice pulido) + meterla en un **Steam Next Fest**.
- Clips a TikTok / YouTube Shorts / Reddit (r/IndieGaming, r/horrorgames).
- Métrica: **wishlists** y si algún streamer prueba la demo solo.

#### Regla SEGUIR / CONGELAR

| Señal | Interpretación | Acción |
|---|---|---|
| > ~2 000–3 000 wishlists tras Next Fest, o streamers lo prueban solos | Hay demanda | **SEGUIR** → Fase 3 (juego completo) |
| < ~1 000 wishlists y los clips no mueven nada | No engancha | **CONGELAR** |

**Si CONGELAR:** terminar solo lo del alcance congelado (los 5 turnos), pulir,
lanzar a 4–6 $ como "contenido completo", pasar página. Objetivo cumplido igual:
terminaste y publicaste un juego 3D y sabes lo que renta.

**Si SEGUIR:** ahí sí se justifica el año entero y meter dinero (del que haya
entrado) en assets, música original o ayuda puntual.

### Fase 3 — Juego completo  (solo si se pasó la puerta)
1. Los 5 turnos con arte y anomalías completas.
2. Cadenas de eventos con memoria (decisiones que vuelven turnos después).
3. Segundo escenario / segundo "acto" con reglas nuevas.
4. Logros de Steam + cromos.
5. Modos de dificultad.
6. Inglés, y más idiomas si las ventas lo pagan.

---

## Riesgos específicos del 3D (y cómo se contienen)

| Riesgo | Contención |
|---|---|
| Modelar lleva meses | Packs de assets, cero modelado propio salvo retoques |
| Animar personajes es un pozo | Apariciones estáticas / que teleportan; visitante con 2 poses |
| "Se ve a asset flip" | Comprometerse con la estética PSX: resolución baja + niebla + dither esconde mucho |
| No da miedo y no lo sabes | Testers externos desde Fase 1; tú ya sabes los sustos |
| La polish 3D se multiplica | Un solo escenario. Punto. |

---

## Expectativa de rentabilidad (sin adornos)

- La mediana de un juego en Steam factura unos cientos de dólares en toda su vida.
  La mayoría no recupera los 100 $ de la cuota.
- El PSX horror corto tiene techos altos si un streamer grande lo agarra, pero eso
  es azar, no plan.
- Meta realista del primer juego: **publicarlo** y aprender el pipeline entero de
  Steam. Cualquier ingreso por encima de eso es extra.
- Lo que predice las ventas es cuántas wishlists llevas al lanzamiento.

---

## Referencias a estudiar antes de programar de más

- **Beholder** — estructura más cercana (informante, sobornos, facciones, finales).
- **This Is the Police** — gestión de equipo + mafia + política + días.
- **Papers, Please** — el bucle "sujeto llega a tu mesa → decides".
- **Shift at Midnight**, **The Convenience Store**, **Night of the Consumers** —
  cómo un solo dev monta atmósfera PSX en un local pequeño con casi nada.
