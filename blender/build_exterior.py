# -*- coding: utf-8 -*-
"""
Genera el exterior de "Puesto Fronterizo": desierto de noche con carretera de
tierra que pasa frente a la ventanilla, dos talanqueras (una por sentido),
rocas y plantas como tapavistas, valla de frontera y mesas lejanas.

Exporta models/exterior.glb.  Ejes ya adaptados a Godot (Y arriba, ventanilla -Z).
La caseta ocupa aprox. X[-4,4] Z[-4,4]; la carretera corre en X a la altura Z=-9.

Objetos con nombre que Godot va a manipular:
  boom_arm_west / boom_arm_east   -> brazos de las talanqueras (origen en el pivote;
                                     rotar en X para subirlas)
  boom_post_west / boom_post_east -> postes fijos

USO: Blender > Scripting > Open > este archivo > Run Script (Alt+P).
"""

import bpy
import os
import random
from math import radians

# Raiz del proyecto. Si abriste el .blend (que vive en juego/blender/) se calcula
# solo. Si corres este .py en un Blender en blanco, usa la ruta de abajo: cambiala
# por la tuya si es distinta.
_blend = bpy.data.filepath
PROJECT_DIR = os.path.dirname(os.path.dirname(_blend)) if _blend else r"C:\Users\Morales\Desktop\juego"
SEED = 7

random.seed(SEED)

# --- ejes: Godot (x, y=alto, z=prof) -> Blender (x, -z, y) --------------------
def gloc(x, y, z):
    return (x, -z, y)

def gsize(sx, sy, sz):
    return (sx, sz, sy)

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

def _finish(o, material):
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    _created.append(o)
    return o

def box(name, size, loc, material, rot_z=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    if rot_z:
        o.rotation_euler = (0.0, 0.0, rot_z)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, material)

def gbox(name, gs, gl, material, rot_z=0.0):
    return box(name, gsize(*gs), gloc(*gl), material, rot_z)

def rock(name, r, loc, material):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (random.uniform(0.8, 1.6), random.uniform(0.8, 1.6), random.uniform(0.5, 1.0))
    o.rotation_euler = (random.uniform(0, 6.28), random.uniform(0, 6.28), random.uniform(0, 6.28))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, material)

def set_origin(o, world_co):
    bpy.context.scene.cursor.location = world_co
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.view_layer.update()

# ---------------------------------------------------------------------------
#  Limpiar
# ---------------------------------------------------------------------------
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for coll in (bpy.data.meshes, bpy.data.materials):
    for block in list(coll):
        if block.users == 0:
            coll.remove(block)
_created.clear()
bpy.context.scene.cursor.location = (0, 0, 0)

# ---------------------------------------------------------------------------
#  Materiales
# ---------------------------------------------------------------------------
M_SAND    = mat("ext_sand",     (0.74, 0.63, 0.43))
M_ROAD    = mat("ext_road",     (0.42, 0.35, 0.27))
M_LINE    = mat("ext_roadline", (0.66, 0.60, 0.45))
M_ROCK    = mat("ext_rock",     (0.40, 0.38, 0.36))
M_ROCK_D  = mat("ext_rock_dark",(0.27, 0.26, 0.25))
M_CACTUS  = mat("ext_cactus",   (0.28, 0.38, 0.22))
M_BUSH    = mat("ext_bush",     (0.40, 0.33, 0.21))
M_RED     = mat("ext_barrier_red",   (0.68, 0.12, 0.10))
M_WHITE   = mat("ext_barrier_white", (0.84, 0.82, 0.76))
M_METAL   = mat("ext_metal",    (0.32, 0.35, 0.34))
M_MESA    = mat("ext_mesa",     (0.16, 0.15, 0.18))

ROAD_Z = -9.0          # eje de la carretera (Godot Z)
ROAD_HALF = 3.2        # semiancho de calzada

# ---------------------------------------------------------------------------
#  Terreno + dunas
# ---------------------------------------------------------------------------
gbox("ground", (200.0, 0.4, 200.0), (0.0, -0.30, -30.0), M_SAND)

for i in range(9):
    dx = random.uniform(-70, 70)
    dz = random.uniform(-75, -12)
    if abs(dz - ROAD_Z) < 6.0:            # no dunas sobre la carretera
        dz -= 10.0
    w = random.uniform(10, 26)
    h = random.uniform(0.6, 2.2)
    gbox("dune_%d" % i, (w, h, w * random.uniform(0.6, 1.1)),
         (dx, h * 0.5 - 0.1, dz), M_SAND, rot_z=random.uniform(0, 3.14))

# ---------------------------------------------------------------------------
#  Carretera de tierra + apron frente a la ventanilla
# ---------------------------------------------------------------------------
gbox("road", (200.0, 0.12, ROAD_HALF * 2), (0.0, 0.0, ROAD_Z), M_ROAD)
gbox("road_apron", (16.0, 0.13, ROAD_HALF * 2 + 3.0), (0.0, 0.01, ROAD_Z + 0.5), M_ROAD)
for i in range(-9, 10):
    gbox("road_dash_%d" % (i + 9), (2.2, 0.14, 0.18), (i * 6.0, 0.02, ROAD_Z), M_LINE)

# ---------------------------------------------------------------------------
#  Talanqueras (una a cada lado de la caseta)
# ---------------------------------------------------------------------------
def boom_gate(tag, x):
    pivot_z = ROAD_Z + ROAD_HALF          # borde de calzada del lado caseta
    tip_z = ROAD_Z - ROAD_HALF - 0.6      # cruza toda la calzada
    arm_len = pivot_z - tip_z
    mid_z = (pivot_z + tip_z) * 0.5

    post = gbox("boom_post_%s" % tag, (0.28, 1.35, 0.28), (x, 0.675, pivot_z), M_METAL)
    base = gbox("boom_base_%s" % tag, (0.6, 0.2, 0.6), (x, 0.1, pivot_z), M_METAL)
    arm = gbox("boom_arm_%s" % tag, (0.16, 0.16, arm_len), (x, 1.2, mid_z), M_RED)
    # franja blanca en la punta, hija del brazo para que suba con el
    tip = gbox("boom_tip_%s" % tag, (0.17, 0.17, 0.9), (x, 1.2, tip_z + 0.45), M_WHITE)
    weight = gbox("boom_weight_%s" % tag, (0.35, 0.35, 0.5), (x, 1.2, pivot_z + 0.45), M_METAL)

    set_origin(arm, gloc(x, 1.2, pivot_z))
    for child in (tip, weight):
        child.parent = arm
        child.matrix_parent_inverse = arm.matrix_world.inverted()  # conserva pose mundial

boom_gate("west", -7.0)
boom_gate("east", 7.0)

# ---------------------------------------------------------------------------
#  Valla de frontera al otro lado de la carretera
# ---------------------------------------------------------------------------
for i in range(-24, 25):
    gbox("fence_post_%d" % (i + 24), (0.1, 1.3, 0.1), (i * 2.5, 0.65, ROAD_Z - ROAD_HALF - 1.2), M_METAL)
for k, y in enumerate((0.5, 1.0)):
    gbox("fence_wire_%d" % k, (122.0, 0.04, 0.04), (0.0, y, ROAD_Z - ROAD_HALF - 1.2), M_METAL)

# ---------------------------------------------------------------------------
#  Rocas (algunas pegadas a la carretera como tapavistas)
# ---------------------------------------------------------------------------
for i in range(16):
    near = i < 7
    x = random.uniform(-26, 26) if near else random.uniform(-75, 75)
    z = random.uniform(ROAD_Z - 16, ROAD_Z - 6) if near else random.uniform(-80, 20)
    if abs(z - ROAD_Z) < ROAD_HALF + 1.5:
        z = ROAD_Z - ROAD_HALF - 2.0
    r = random.uniform(0.6, 1.8) if near else random.uniform(1.2, 3.5)
    rock("rock_%d" % i, r, gloc(x, r * 0.35 - 0.1, z), M_ROCK if i % 3 else M_ROCK_D)

# ---------------------------------------------------------------------------
#  Plantas: cactus y matojos secos
# ---------------------------------------------------------------------------
def cactus(name, gx, gz):
    gbox(name,           (0.28, 1.6, 0.28), (gx, 0.80, gz), M_CACTUS)
    gbox(name + "_armL", (0.20, 0.6, 0.20), (gx - 0.32, 1.10, gz), M_CACTUS)
    gbox(name + "_armR", (0.20, 0.5, 0.20), (gx + 0.32, 0.90, gz), M_CACTUS)

def bush(name, gx, gz):
    rock(name, random.uniform(0.4, 0.7), gloc(gx, 0.15, gz), M_BUSH)

for i in range(8):
    x = random.uniform(-30, 30)
    z = random.uniform(ROAD_Z - 22, ROAD_Z - 5)
    if abs(z - ROAD_Z) < ROAD_HALF + 1.0:
        z -= 3.0
    cactus("cactus_%d" % i, x, z)
for i in range(8):
    x = random.uniform(-35, 35)
    z = random.uniform(ROAD_Z - 24, ROAD_Z - 4)
    bush("bush_%d" % i, x, z)

# ---------------------------------------------------------------------------
#  Mesas lejanas (siluetas en el horizonte)
# ---------------------------------------------------------------------------
for i, x in enumerate((-70, -35, 20, 60)):
    h = random.uniform(6, 12)
    w = random.uniform(14, 26)
    gbox("mesa_%d" % i, (w, h, w * 0.7), (x, h * 0.5, -85.0), M_MESA)

# ---------------------------------------------------------------------------
#  Agrupar y exportar
# ---------------------------------------------------------------------------
root = bpy.data.objects.new("Exterior", None)
bpy.context.collection.objects.link(root)
for o in _created:
    if o.parent is None:
        o.parent = root

out_dir = os.path.join(PROJECT_DIR, "models")
os.makedirs(out_dir, exist_ok=True)
glb_path = os.path.join(out_dir, "exterior.glb")

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=glb_path, export_format='GLB', use_selection=True, export_apply=True,
)
print("Exportado:", glb_path)

blend_dir = os.path.join(PROJECT_DIR, "blender")
os.makedirs(blend_dir, exist_ok=True)
try:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "exterior.blend"))
    print("Guardado blend:", os.path.join(blend_dir, "exterior.blend"))
except Exception as e:
    print("No se pudo guardar el .blend:", e)
