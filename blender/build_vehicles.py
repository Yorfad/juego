# -*- coding: utf-8 -*-
"""
Genera 4 vehiculos low-poly (sedan, pickup, van, camion con remolque) y
exporta uno por uno a models/vehicle_<tipo>.glb.

Convencion de ejes: cada vehiculo se construye centrado en el origen, ruedas
tocando Z=0 (suelo), morro/faros hacia +X. Como Blender X y Z mapean 1:1 a
Godot X (mismo eje) e Y (arriba) al exportar, el vehiculo queda "mirando"
+X de Godot sin necesidad de convertir ejes (solo la profundidad/ancho se
invierte, y un coche es simetrico en ese eje).

world.gd instancia estos .glb y los mueve por la carretera con vehicle.gd.

USO: Blender > Scripting > Open > este archivo > Run Script (Alt+P).
"""

import bpy
import os
from math import radians

# Raiz del proyecto. Si abriste el .blend (que vive en juego/blender/) se calcula
# solo. Si corres este .py en un Blender en blanco, usa la ruta de abajo: cambiala
# por la tuya si es distinta.
_blend = bpy.data.filepath
PROJECT_DIR = os.path.dirname(os.path.dirname(_blend)) if _blend else r"C:\Users\Morales\Desktop\juego"

_created = []

# ---------------------------------------------------------------------------
#  Utilidades
# ---------------------------------------------------------------------------
def clear_scene():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for coll in (bpy.data.meshes, bpy.data.materials):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)
    _created.clear()

def mat(name, rgb, rough=0.55):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    for spec in ("Specular IOR Level", "Specular"):
        if spec in b.inputs:
            b.inputs[spec].default_value = 0.15
            break
    return m

def emissive(name, rgb, strength=4.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    for ecol in ("Emission Color", "Emission"):
        if ecol in b.inputs:
            b.inputs[ecol].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
            break
    if "Emission Strength" in b.inputs:
        b.inputs["Emission Strength"].default_value = strength
    return m

def part(size, loc, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    _created.append(o)
    return o

def wheel(x, y, r, w, material):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=w, location=(x, y, r), vertices=10)
    o = bpy.context.active_object
    o.rotation_euler = (radians(90), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    _created.append(o)
    return o

M_TIRE = None
M_GLASS = None
M_METAL = None
M_LIGHT_W = None
M_LIGHT_R = None

def base_materials():
    global M_TIRE, M_GLASS, M_METAL, M_LIGHT_W, M_LIGHT_R
    M_TIRE = mat("veh_tire", (0.05, 0.05, 0.06), rough=0.9)
    M_GLASS = mat("veh_glass", (0.05, 0.09, 0.12), rough=0.15)
    M_METAL = mat("veh_metal", (0.32, 0.33, 0.35), rough=0.35)
    M_LIGHT_W = emissive("veh_headlight", (1.0, 0.92, 0.75), 4.0)
    M_LIGHT_R = emissive("veh_taillight", (0.9, 0.08, 0.06), 3.0)

# ---------------------------------------------------------------------------
#  Sedan
# ---------------------------------------------------------------------------
def build_sedan():
    body = mat("veh_sedan_body", (0.09, 0.11, 0.15))
    r = 0.33
    part((4.3, 1.75, 0.85), (0.0, 0.0, r + 0.425), body)
    part((2.1, 1.55, 0.55), (0.10, 0.0, r + 0.85 + 0.225), M_GLASS)
    part((0.20, 1.85, 0.10), (2.05, 0.0, r + 0.15), M_METAL)      # parachoques
    part((0.20, 1.85, 0.10), (-2.05, 0.0, r + 0.15), M_METAL)
    for sx in (-1, 1):
        wheel(1.45, sx * 0.90, 0.33, 0.22, M_TIRE)
        wheel(-1.45, sx * 0.90, 0.33, 0.22, M_TIRE)
    part((0.08, 1.1, 0.20), (2.14, 0.0, r + 0.45), M_LIGHT_W)
    part((0.08, 1.1, 0.16), (-2.14, 0.0, r + 0.50), M_LIGHT_R)

# ---------------------------------------------------------------------------
#  Pickup
# ---------------------------------------------------------------------------
def build_pickup():
    body = mat("veh_pickup_body", (0.42, 0.22, 0.13))
    r = 0.37
    part((1.9, 1.85, 0.95), (1.0, 0.0, r + 0.475), body)           # cabina
    part((1.55, 1.55, 0.55), (1.15, 0.0, r + 0.95 + 0.15), M_GLASS)
    part((2.7, 1.75, 0.55), (-1.15, 0.0, r + 0.275), body)         # caja
    part((2.7, 1.75, 0.10), (-1.15, 0.0, r + 0.55 + 0.03), M_METAL)  # borde caja
    for sx in (-1, 1):
        wheel(1.7, sx * 0.95, 0.37, 0.26, M_TIRE)
        wheel(-1.1, sx * 0.95, 0.37, 0.26, M_TIRE)
    part((0.08, 1.5, 0.22), (1.95, 0.0, r + 0.5), M_LIGHT_W)
    part((0.08, 1.75, 0.16), (-2.5, 0.0, r + 0.55), M_LIGHT_R)

# ---------------------------------------------------------------------------
#  Furgon (van)
# ---------------------------------------------------------------------------
def build_van():
    body = mat("veh_van_body", (0.72, 0.70, 0.62))
    r = 0.34
    part((4.6, 1.9, 1.55), (0.0, 0.0, r + 0.775), body)
    part((0.10, 1.6, 0.55), (2.28, 0.0, r + 1.55 - 0.35), M_GLASS)  # parabrisas
    for sx in (-1, 1):
        wheel(1.7, sx * 0.98, 0.34, 0.24, M_TIRE)
        wheel(-1.6, sx * 0.98, 0.34, 0.24, M_TIRE)
    part((0.08, 1.3, 0.20), (2.33, 0.0, r + 0.45), M_LIGHT_W)
    part((0.08, 1.6, 0.16), (-2.33, 0.0, r + 0.55), M_LIGHT_R)

# ---------------------------------------------------------------------------
#  Camion con remolque
# ---------------------------------------------------------------------------
def build_truck():
    cab_col = mat("veh_truck_cab", (0.24, 0.26, 0.20))
    trailer_col = mat("veh_truck_trailer", (0.36, 0.28, 0.18))
    r = 0.42
    part((1.7, 2.0, 1.7), (2.2, 0.0, r + 0.85), cab_col)
    part((0.08, 1.7, 0.55), (3.03, 0.0, r + 1.7 - 0.32), M_GLASS)
    part((4.7, 2.15, 2.0), (-1.95, 0.0, r + 1.0), trailer_col)
    part((4.7, 2.15, 0.08), (-1.95, 0.0, r + 2.0 + 0.04), M_METAL)
    for sx in (-1, 1):
        wheel(2.65, sx * 1.05, 0.42, 0.28, M_TIRE)     # eje cabina
        wheel(0.2, sx * 1.10, 0.42, 0.28, M_TIRE)       # eje remolque delantero
        wheel(-1.9, sx * 1.10, 0.42, 0.28, M_TIRE)      # eje remolque trasero 1
        wheel(-3.4, sx * 1.10, 0.42, 0.28, M_TIRE)      # eje remolque trasero 2
    part((0.08, 1.6, 0.22), (3.05, 0.0, r + 0.55), M_LIGHT_W)
    part((0.08, 2.05, 0.18), (-4.3, 0.0, r + 0.55), M_LIGHT_R)

# ---------------------------------------------------------------------------
def export(kind):
    root = bpy.data.objects.new("Vehicle", None)
    bpy.context.collection.objects.link(root)
    for o in _created:
        if o.parent is None:
            o.parent = root

    out_dir = os.path.join(PROJECT_DIR, "models")
    os.makedirs(out_dir, exist_ok=True)
    glb_path = os.path.join(out_dir, "vehicle_%s.glb" % kind)

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=glb_path, export_format='GLB', use_selection=True, export_apply=True,
    )
    print("Exportado:", glb_path)

    blend_dir = os.path.join(PROJECT_DIR, "blender")
    os.makedirs(blend_dir, exist_ok=True)
    try:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "vehicle_%s.blend" % kind))
    except Exception as e:
        print("No se pudo guardar el .blend de %s:" % kind, e)


BUILDERS = {
    "sedan": build_sedan,
    "pickup": build_pickup,
    "van": build_van,
    "truck": build_truck,
}

for kind, builder in BUILDERS.items():
    clear_scene()
    base_materials()
    builder()
    export(kind)

print("Vehiculos generados:", ", ".join(BUILDERS.keys()))
