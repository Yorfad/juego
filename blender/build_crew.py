# -*- coding: utf-8 -*-
"""
Genera los 4 companeros del puesto como figuras low-poly a bloques, posadas
(sin rig, sin animacion), colocadas dentro de la caseta.

Exporta models/crew.glb.  Cada figura es un Empty con nombre que Godot y los
encuentros pueden referenciar:
  crew_nava    (Sargento Nava)  - de pie junto a la ventanilla
  crew_robles  (Cabo Robles)    - sentado en la silla del escritorio
  crew_pena    (Guardia Pena)   - sentado en el borde de la litera
  crew_ruiz    (Cabo Ruiz)      - de pie al fondo

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

# --- ejes: Godot (x, y=alto, z=prof) -> Blender (x, -z, y) -------------------
def gloc(x, y, z):
    return (x, -z, y)

_created = []

def mat(name, rgb, rough=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    for spec in ("Specular IOR Level", "Specular"):
        if spec in b.inputs:
            b.inputs[spec].default_value = 0.0
            break
    return m

M_UNIFORM = mat("crew_uniform", (0.28, 0.31, 0.24))
M_SKIN    = mat("crew_skin",    (0.54, 0.41, 0.33))
M_BOOT    = mat("crew_boot",    (0.10, 0.10, 0.11))
M_CAP     = mat("crew_cap",     (0.20, 0.22, 0.17))

# local: Z arriba, ADELANTE = +Y, pies en Z=0
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

def _standing():
    ps = []
    ps.append(part((0.44, 0.24, 0.78), (0, 0, 1.18), M_UNIFORM))   # torso
    ps.append(part((0.30, 0.22, 0.10), (0, 0, 1.60), M_UNIFORM))   # hombros
    ps.append(part((0.22, 0.22, 0.24), (0, 0.02, 1.80), M_SKIN))   # cabeza
    ps.append(part((0.24, 0.26, 0.10), (0, 0.03, 1.94), M_CAP))    # gorra
    for sx in (-1, 1):
        ps.append(part((0.12, 0.12, 0.66), (sx * 0.30, 0, 1.30), M_UNIFORM))  # brazo
        ps.append(part((0.10, 0.10, 0.12), (sx * 0.30, 0.02, 0.96), M_SKIN))  # mano
        ps.append(part((0.16, 0.16, 0.92), (sx * 0.11, 0, 0.47), M_UNIFORM))  # pierna
        ps.append(part((0.16, 0.28, 0.12), (sx * 0.11, 0.07, 0.06), M_BOOT))  # bota
    return ps

def _sitting():
    ps = []
    ps.append(part((0.44, 0.24, 0.60), (0, 0, 0.78), M_UNIFORM))   # torso
    ps.append(part((0.30, 0.22, 0.10), (0, 0, 1.08), M_UNIFORM))   # hombros
    ps.append(part((0.22, 0.22, 0.24), (0, 0.02, 1.28), M_SKIN))   # cabeza
    ps.append(part((0.24, 0.26, 0.10), (0, 0.03, 1.42), M_CAP))    # gorra
    ps.append(part((0.42, 0.50, 0.18), (0, 0.30, 0.46), M_UNIFORM))  # muslos
    for sx in (-1, 1):
        ps.append(part((0.12, 0.12, 0.50), (sx * 0.28, 0.02, 0.85), M_UNIFORM))  # brazo
        ps.append(part((0.15, 0.16, 0.46), (sx * 0.12, 0.52, 0.23), M_UNIFORM))  # espinilla
        ps.append(part((0.15, 0.28, 0.12), (sx * 0.12, 0.62, 0.06), M_BOOT))     # bota
    return ps

def figure(name, gpos, gyaw_deg, sitting=False):
    empty = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(empty)
    parts = _sitting() if sitting else _standing()
    for p in parts:
        p.parent = empty          # empty en origen: local == mundo, sin salto
    empty.location = gloc(*gpos)
    empty.rotation_euler = (0.0, 0.0, radians(gyaw_deg))  # yaw 0 => mira a Godot -Z
    _created.append(empty)
    return empty

# ---------------------------------------------------------------------------
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for coll in (bpy.data.meshes,):
    for block in list(coll):
        if block.users == 0:
            coll.remove(block)
_created.clear()

# Posiciones dentro de la caseta (X[-4,4] Z[-4,4], ventanilla en Z=-4)
figure("crew_nava",   (2.55, 0.0, -1.7),  -60.0)                 # de pie, junto a ventanilla
figure("crew_robles", (2.70, 0.0,  1.65), 175.0, sitting=True)   # sentado, mirando al escritorio
figure("crew_pena",   (-2.95, 0.0, 1.45), -115.0, sitting=True)  # sentado en la litera
figure("crew_ruiz",   (-1.8, 0.0,  3.2),  5.0)                   # de pie, al fondo

# ---------------------------------------------------------------------------
root = bpy.data.objects.new("Crew", None)
bpy.context.collection.objects.link(root)
for o in _created:
    if o.parent is None:
        o.parent = root

out_dir = os.path.join(PROJECT_DIR, "models")
os.makedirs(out_dir, exist_ok=True)
glb_path = os.path.join(out_dir, "crew.glb")
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=glb_path, export_format='GLB', use_selection=True, export_apply=True,
)
print("Exportado:", glb_path)

blend_dir = os.path.join(PROJECT_DIR, "blender")
try:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "crew.blend"))
    print("Guardado blend:", os.path.join(blend_dir, "crew.blend"))
except Exception as e:
    print("No se pudo guardar el .blend:", e)
