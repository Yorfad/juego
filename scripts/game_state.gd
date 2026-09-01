extends Node
## Estado global de la partida (autoload "GameState").
## Toda la regla del juego vive aqui. El contenido (situaciones) vive en
## data/encounters.json y los numeros de balance en data/config.json.

const METER_KEYS := ["cash", "loyalty", "command_suspicion", "cartel_pressure", "nerve"]

var config: Dictionary = {}
var encounters: Array = []

# --- Companeros (data/crew.json) ---
var crew_defs: Array = []
var crew_bands: Dictionary = {"loyal": 68, "hostile": 26}
var crew_talk_options: Array = []
var crew_orders: Array = []

# --- Estado de la partida en curso ---
var meters: Dictionary = {}
var day: int = 1
var shift_queue: Array = []
var current_encounter: Dictionary = {}
var bribes_taken_today: int = 0
var used_once_ids: Array = []
var last_deltas: Dictionary = {}

# Confianza por companero (id -> 0..100) y si le has metido miedo esta partida.
var crew_trust: Dictionary = {}
var crew_feared: Dictionary = {}
# Ordenes activas este turno (id -> order_id). Se limpian al empezar cada turno.
var crew_order: Dictionary = {}
# Ultimo apoyo/traicion disparado por una eleccion, para que world.gd lo muestre.
# {} o {"name": String, "kind": "assist"|"betray", "text": String}
var last_crew_event: Dictionary = {}

# Ranura activa (1..3). 0 = sin ranura (p. ej. abrir world.tscn suelto en el editor);
# en ese caso no se persiste nada.
var active_slot: int = 0
# true si la partida en curso viene de cargar una ranura (world.gd se salta la intro).
var resumed: bool = false


func _ready() -> void:
	_load_data()
	reset_run()


func _load_data() -> void:
	config = _read_json("res://data/config.json")
	var enc: Variant = _read_json("res://data/encounters.json")
	if enc is Dictionary:
		encounters = enc.get("encounters", [])
	elif enc is Array:
		encounters = enc
	else:
		encounters = []

	var crew: Variant = _read_json("res://data/crew.json")
	if crew is Dictionary:
		crew_defs = crew.get("crew", [])
		crew_bands = crew.get("trust_bands", crew_bands)
		crew_talk_options = crew.get("talk_options", [])
		crew_orders = crew.get("orders", [])


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("No se encontro el archivo: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir: " + path)
		return {}
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if data == null:
		push_error("JSON invalido en: " + path)
		return {}
	return data


# ---------------------------------------------------------------------------
#  Ciclo de partida
# ---------------------------------------------------------------------------

func reset_run() -> void:
	day = 1
	used_once_ids.clear()
	var start: Dictionary = config.get("start_meters", {})
	meters = start.duplicate(true)
	for k in METER_KEYS:
		if not meters.has(k):
			meters[k] = 0
	_clamp_meters()
	crew_trust.clear()
	crew_feared.clear()
	crew_order.clear()
	last_crew_event = {}
	for c in crew_defs:
		crew_trust[str(c.get("id", ""))] = int(c.get("start_trust", 50))
	_build_shift()


# ---------------------------------------------------------------------------
#  Companeros
# ---------------------------------------------------------------------------

func crew_def(id: String) -> Dictionary:
	for c in crew_defs:
		if str(c.get("id", "")) == id:
			return c
	return {}


func crew_name(id: String) -> String:
	var c := crew_def(id)
	return str(c.get("name", id))


func trust_of(id: String) -> int:
	return int(crew_trust.get(id, 50))


func trust_band(id: String) -> String:
	var t := trust_of(id)
	if t >= int(crew_bands.get("loyal", 68)):
		return "loyal"
	if t <= int(crew_bands.get("hostile", 26)):
		return "hostile"
	return "neutral"


func adjust_trust(id: String, delta: int) -> void:
	if id == "" or not crew_trust.has(id):
		return
	crew_trust[id] = clampi(int(crew_trust[id]) + delta, 0, 100)


## Aplica una opcion de "hablar con el equipo". Devuelve un reporte para la UI.
func crew_talk(id: String, option: Dictionary) -> Dictionary:
	var cost := int(option.get("cost", 0))
	var base_trust := int(option.get("trust", 0))
	var greed: float = float(crew_def(id).get("greed", 1.0))
	var dtrust := roundi(base_trust * greed) if base_trust > 0 else base_trust
	meters["cash"] = int(meters["cash"]) - cost
	meters["nerve"] = int(meters["nerve"]) + int(option.get("nerve", 0))
	adjust_trust(id, dtrust)
	if option.get("fear", false):
		crew_feared[id] = true
	_clamp_meters()
	return {"name": crew_name(id), "trust": trust_of(id), "band": trust_band(id), "dtrust": dtrust}


## Da una orden al companero para el resto del turno (press / silent / backoff).
func give_order(id: String, order_id: String) -> void:
	if id == "" or order_id == "":
		return
	crew_order[id] = order_id


func _crew_with_order(order_id: String) -> String:
	for id in crew_order.keys():
		if str(crew_order[id]) == order_id:
			return str(id)
	return ""


func _build_shift() -> void:
	bribes_taken_today = 0
	crew_order.clear()
	shift_queue.clear()
	var count: int = int(config.get("base_encounters", 7)) \
		+ (day - 1) * int(config.get("encounters_per_day", 2))

	# Candidatas de hoy (descarta las 'once' ya vistas en esta partida).
	var candidates: Array = []
	for e in encounters:
		if int(e.get("day_min", 1)) > day:
			continue
		if e.get("once", false) and (str(e.get("id", "")) in used_once_ids):
			continue
		candidates.append(e)

	# Reparto ponderado SIN reposicion: nadie se repite dentro del mismo turno.
	# Si hay menos candidatas que 'count', la fila simplemente sale mas corta.
	while shift_queue.size() < count and not candidates.is_empty():
		var total: int = 0
		for e in candidates:
			total += max(1, int(e.get("weight", 10)))
		var r: int = randi() % total
		var acc: int = 0
		var chosen: int = candidates.size() - 1
		for i in candidates.size():
			acc += max(1, int(candidates[i].get("weight", 10)))
			if r < acc:
				chosen = i
				break
		shift_queue.append(candidates[chosen])
		candidates.remove_at(chosen)


func has_next_encounter() -> bool:
	return shift_queue.size() > 0


func next_encounter() -> Dictionary:
	current_encounter = shift_queue.pop_front()
	return current_encounter


func apply_choice(choice: Dictionary) -> void:
	last_deltas = {}
	last_crew_event = {}
	_apply_effects(choice.get("effects", {}))

	# Confianza que da/quita la eleccion (id -> delta)
	var ct: Dictionary = choice.get("crew_trust", {})
	for cid in ct.keys():
		adjust_trust(str(cid), int(ct[cid]))

	# Orden "aprieta al proximo": si esta eleccion es un soborno, saca mas mordida
	# a costa de mas sospecha. Se gasta al usarla.
	var presser := _crew_with_order("press")
	if presser != "" and choice.get("is_bribe", false):
		var bonus := roundi(int(choice.get("effects", {}).get("cash", 0)) * 0.35)
		if bonus > 0:
			_apply_effects({"cash": bonus, "command_suspicion": 4})
			last_crew_event = {"name": crew_name(presser), "kind": "assist",
				"text": "Aprieta al conductor como le ordenaste: saca $%d mas, pero hace ruido." % bonus}
		crew_order.erase(presser)

	# Un companero leal puede mejorar la resolucion...
	var assist: Dictionary = choice.get("crew_assist", {})
	if last_crew_event.is_empty() and not assist.is_empty():
		var aid := str(assist.get("id", ""))
		var muted := str(crew_order.get(aid, "")) == "backoff"
		if not muted and trust_of(aid) >= int(assist.get("min_trust", int(crew_bands.get("loyal", 68)))):
			_apply_effects(assist.get("effects", {}))
			last_crew_event = {"name": crew_name(aid), "kind": "assist",
				"text": str(assist.get("result", ""))}

	# ...o uno hostil (o con miedo mal gestionado) puede venderte.
	var betray: Dictionary = choice.get("crew_betray", {})
	if last_crew_event.is_empty() and not betray.is_empty():
		var bid := str(betray.get("id", ""))
		var silenced := str(crew_order.get(bid, "")) in ["backoff", "silent"]
		var hostile := trust_of(bid) <= int(betray.get("max_trust", int(crew_bands.get("hostile", 26))))
		if not silenced and (hostile or (crew_feared.get(bid, false) and randi() % 100 < 35)):
			_apply_effects(betray.get("effects", {}))
			last_crew_event = {"name": crew_name(bid), "kind": "betray",
				"text": str(betray.get("result", ""))}

	if choice.get("is_bribe", false):
		bribes_taken_today += 1

	if current_encounter.get("once", false):
		var id: String = str(current_encounter.get("id", ""))
		if id != "" and not (id in used_once_ids):
			used_once_ids.append(id)

	_clamp_meters()


func _apply_effects(effects: Dictionary) -> void:
	for k in effects.keys():
		var v: int = int(effects[k])
		meters[k] = int(meters.get(k, 0)) + v
		last_deltas[k] = int(last_deltas.get(k, 0)) + v


func _clamp_meters() -> void:
	meters["loyalty"] = clampi(int(meters.get("loyalty", 0)), 0, 100)
	meters["command_suspicion"] = clampi(int(meters.get("command_suspicion", 0)), 0, 100)
	meters["cartel_pressure"] = clampi(int(meters.get("cartel_pressure", 0)), 0, 100)
	meters["nerve"] = clampi(int(meters.get("nerve", 0)), 0, 100)
	meters["cash"] = int(meters.get("cash", 0))  # sin tope; puede ser negativo


## Devuelve la clave del medidor que provoco el fin de partida, o "" si sigues vivo.
func failed_meter() -> String:
	if int(meters["loyalty"]) <= 0:
		return "loyalty"
	if int(meters["nerve"]) <= 0:
		return "nerve"
	if int(meters["command_suspicion"]) >= 100:
		return "command_suspicion"
	if int(meters["cartel_pressure"]) >= 100:
		return "cartel_pressure"
	return ""


## Cierre de turno: nomina, castigo por turno "demasiado limpio", presiones pasivas.
func end_shift_report() -> Dictionary:
	var report: Dictionary = {}

	var payroll: int = int(config.get("team_size", 4)) * int(config.get("wage_per_member", 55))
	report["payroll"] = payroll
	if int(meters["cash"]) >= payroll:
		meters["cash"] -= payroll
		meters["loyalty"] = int(meters["loyalty"]) + int(config.get("paid_loyalty_bonus", 4))
		report["paid"] = true
		for id in crew_trust.keys():
			adjust_trust(str(id), 4)
	else:
		meters["loyalty"] = int(meters["loyalty"]) - int(config.get("unpaid_loyalty_penalty", 18))
		report["paid"] = false
		for id in crew_trust.keys():
			adjust_trust(str(id), -10)

	# Companeros hostiles: pueden filtrar algo a los mandos entre turnos.
	report["crew_leak"] = ""
	for id in crew_trust.keys():
		if trust_band(str(id)) == "hostile" and randi() % 100 < 45:
			meters["command_suspicion"] = int(meters["command_suspicion"]) + 7
			report["crew_leak"] = crew_name(str(id))
			break
	crew_feared.clear()   # el miedo no dura de un turno al siguiente

	report["clean_shift"] = bribes_taken_today == 0
	if bribes_taken_today == 0:
		meters["command_suspicion"] = int(meters["command_suspicion"]) \
			+ int(config.get("clean_shift_suspicion", 8))

	meters["cartel_pressure"] = int(meters["cartel_pressure"]) \
		+ (day - 1) * int(config.get("passive_cartel_per_day", 3))

	_clamp_meters()
	report["failed"] = failed_meter()
	report["won"] = day >= int(config.get("total_days", 5)) and report["failed"] == ""
	return report


func advance_day() -> void:
	day += 1
	var resets: Dictionary = config.get("loyalty_reset_days", {})
	if resets.has(str(day)):
		meters["loyalty"] = int(resets[str(day)])
	_build_shift()


func apply_relief(option: Dictionary) -> void:
	meters["cash"] = int(meters["cash"]) - int(option.get("cost", 0))
	meters["nerve"] = int(meters["nerve"]) + int(option.get("nerve", 0))
	_clamp_meters()


## Cerrar el puesto antes de tiempo: vacia la fila y penaliza segun cuantos
## vehiculos quedaban.
func close_post_early() -> void:
	var n := shift_queue.size()
	shift_queue.clear()
	meters["command_suspicion"] = int(meters["command_suspicion"]) + 6 + n * 2
	meters["loyalty"] = int(meters["loyalty"]) - 5
	_clamp_meters()


# ---------------------------------------------------------------------------
#  Guardado por ranuras (user://save_1.json .. save_3.json)
# ---------------------------------------------------------------------------

func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func has_save(slot: int) -> bool:
	return slot >= 1 and FileAccess.file_exists(slot_path(slot))


## Resumen para pintar el boton de la ranura en el menu. {} si esta vacia.
func slot_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var d: Variant = _read_json(slot_path(slot))
	if not (d is Dictionary) or d.is_empty():
		return {}
	var m: Dictionary = d.get("meters", {})
	return {
		"day": int(d.get("day", 1)),
		"cash": int(m.get("cash", 0)),
		"nerve": int(m.get("nerve", 0)),
	}


func clear_save(slot: int) -> void:
	if not has_save(slot):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("save_%d.json" % slot)


func start_new_run(slot: int) -> void:
	active_slot = slot
	resumed = false
	reset_run()
	save_run()


func save_run() -> void:
	if active_slot < 1:
		return
	var ids: Array = []
	for e in shift_queue:
		ids.append(str(e.get("id", "")))
	var data := {
		"day": day,
		"meters": meters,
		"used_once_ids": used_once_ids,
		"bribes_taken_today": bribes_taken_today,
		"queue_ids": ids,
		"crew_trust": crew_trust,
	}
	var f := FileAccess.open(slot_path(active_slot), FileAccess.WRITE)
	if f == null:
		push_error("No se pudo guardar la ranura %d" % active_slot)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_run(slot: int) -> bool:
	if not has_save(slot):
		return false
	var d: Variant = _read_json(slot_path(slot))
	if not (d is Dictionary) or d.is_empty():
		return false
	active_slot = slot
	day = int(d.get("day", 1))
	meters = (d.get("meters", {}) as Dictionary).duplicate(true)
	for k in METER_KEYS:
		if not meters.has(k):
			meters[k] = 0
	used_once_ids = (d.get("used_once_ids", []) as Array).duplicate()
	bribes_taken_today = int(d.get("bribes_taken_today", 0))
	crew_trust.clear()
	crew_feared.clear()
	crew_order.clear()
	last_crew_event = {}
	for c in crew_defs:
		var cid := str(c.get("id", ""))
		crew_trust[cid] = int(c.get("start_trust", 50))
	var saved_trust: Dictionary = d.get("crew_trust", {})
	for sid in saved_trust.keys():
		if crew_trust.has(sid):
			crew_trust[sid] = int(saved_trust[sid])
	shift_queue.clear()
	for id in d.get("queue_ids", []):
		var e := _encounter_by_id(str(id))
		if not e.is_empty():
			shift_queue.append(e)
	_clamp_meters()
	resumed = true
	return true


func _encounter_by_id(id: String) -> Dictionary:
	for e in encounters:
		if str(e.get("id", "")) == id:
			return e
	return {}
