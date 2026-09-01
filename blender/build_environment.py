# -*- coding: utf-8 -*-
"""
Genera el entorno completo de "Puesto Fronterizo" (caseta, ventanilla, mobiliario)
y lo exporta a models/environment.glb, listo para Godot.

Estetica PSX: geometria a bloques, sombreado plano, materiales mate sin specular.
Las medidas y posiciones replican el greybox de scripts/world.gd (_build_room).

COMO USARLO
-----------
1. Abre Blender.
2. Pestana "Scripting" -> Open -> elige este archivo (o pega el contenido).
3. Ajusta PROJECT_DIR si tu ruta cambia.
4. Pulsa "Run Script" (Alt+P con el raton sobre el editor de texto).
   -> escribe  <PROJECT_DIR>/models/environment.glb
   -> guarda   <PROJECT_DIR>/blender/environment.blend  (para retocar a mano)

En Godot: arrastra models/environment.glb a la escena, o instancialo desde world.gd.
El eje ya sale bien (Y arriba, -Z hacia la ventanilla).
"""

import bpy
import os
from math import radians

# Raiz del proyecto. Si abriste el .blend (que vive en juego/blender/) se calcula
# solo. Si corres este .py en un Blender en blanco, usa la ruta de abajo: cambiala
# por la tuya si es distinta.
_blend = bpy.data.filepath
PROJECT_DIR = os.path.dirname(os.path.dirname(_blend)) if _blend else r"C:\Users\Morales\Desktop\juego"

# ---------------------------------------------------------------------------
#  Conversion de ejes: Godot (x, y=alto, z=prof) -> Blender (x, -z, y)
# ---------------------------------------------------------------------------
def gloc(x, y, z):
    return (x, -z, y)

def gsize(sx, sy, sz):          # Godot (ancho, alto, prof) -> Blender (x, y, z)
    return (sx, sz, sy)

# ---------------------------------------------------------------------------
#  Utilidades
# ---------------------------------------------------------------------------
_created = []

def mat(name, rgb, rough=1.0, emission=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    for spec in ("Specular IOR Level", "Specular"):
        if spec in b.inputs:
            b.inputs[spec].default_value = 0.0
            break
    if emission > 0.0:
        for ecol in ("Emission Color", "Emission"):
            if ecol in b.inputs:
                b.inputs[ecol].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
                break
        if "Emission Strength" in b.inputs:
            b.inputs["Emission Strength"].default_value = emission
    return m

def box(name, size, loc, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    _created.append(o)
    return o

def gbox(name, gs, gl, material):
    return box(name, gsize(*gs), gloc(*gl), material)

def disc(name, r, depth, loc, material):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, vertices=12)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(90), 0, 0)      # cara plana hacia la sala
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    _created.append(o)
    return o

# ---------------------------------------------------------------------------
#  Limpiar escena
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

# ---------------------------------------------------------------------------
#  Materiales
# ---------------------------------------------------------------------------
M_WALL   = mat("wall",    (0.60, 0.56, 0.48))
M_FLOOR  = mat("floor",   (0.17, 0.16, 0.15))
M_CEIL   = mat("ceiling", (0.28, 0.28, 0.30))
M_METAL  = mat("metal",   (0.33, 0.37, 0.35))
M_WOOD   = mat("wood",    (0.34, 0.25, 0.17))
M_FABRIC = mat("fabric",  (0.44, 0.41, 0.39))
M_GLASS  = mat("lampglass", (1.00, 0.93, 0.78), rough=0.4, emission=3.0)
M_DARK   = mat("dark",    (0.10, 0.10, 0.12))

# ---------------------------------------------------------------------------
#  Cascaron de la caseta  (hueco de ventanilla en la pared frontal -Z)
# ---------------------------------------------------------------------------
gbox("floor",       (8.0, 0.2, 8.0), (0.0, -0.10, 0.0), M_FLOOR)
gbox("ceiling",     (8.0, 0.2, 8.0), (0.0,  3.00, 0.0), M_CEIL)
gbox("wall_west",   (0.2, 3.2, 8.0), (-4.0, 1.50, 0.0), M_WALL)
gbox("wall_east",   (0.2, 3.2, 8.0), ( 4.0, 1.50, 0.0), M_WALL)
gbox("wall_back",   (8.0, 3.2, 0.2), (0.0,  1.50, 4.0), M_WALL)
gbox("front_left",  (3.15, 3.2, 0.2), (-2.425, 1.50, -4.0), M_WALL)
gbox("front_right", (3.15, 3.2, 0.2), ( 2.425, 1.50, -4.0), M_WALL)
gbox("lintel",      (1.7, 0.85, 0.2), (0.0, 2.675, -4.0), M_WALL)

# ---------------------------------------------------------------------------
#  Ventanilla: mostrador interior + repisa exterior + reja
# ---------------------------------------------------------------------------
gbox("counter_base", (1.9, 0.95, 0.6), (0.0, 0.475, -3.60), M_METAL)
gbox("counter_top",  (2.0, 0.06, 0.7), (0.0, 0.980, -3.60), M_METAL)
gbox("ext_ledge",    (1.9, 0.08, 0.35), (0.0, 0.960, -4.28), M_METAL)
for i, x in enumerate((-0.7, -0.35, 0.0, 0.35, 0.7)):
    gbox("bars_%d" % i, (0.04, 1.25, 0.04), (x, 1.60, -3.95), M_METAL)

# ---------------------------------------------------------------------------
#  Escritorio + silla + radio
# ---------------------------------------------------------------------------
gbox("desk_top", (1.6, 0.06, 1.1), (2.70, 0.90, 2.40), M_WOOD)
for i, (dx, dz) in enumerate(((-0.72, -0.48), (0.72, -0.48), (-0.72, 0.48), (0.72, 0.48))):
    gbox("desk_leg_%d" % i, (0.08, 0.9, 0.08), (2.70 + dx, 0.45, 2.40 + dz), M_WOOD)
gbox("chair_seat", (0.45, 0.06, 0.45), (2.70, 0.50, 1.55), M_WOOD)
gbox("chair_back", (0.45, 0.5, 0.06), (2.70, 0.78, 1.35), M_WOOD)
for i, (dx, dz) in enumerate(((-0.18, -0.18), (0.18, -0.18), (-0.18, 0.18), (0.18, 0.18))):
    gbox("chair_leg_%d" % i, (0.05, 0.5, 0.05), (2.70 + dx, 0.25, 1.55 + dz), M_WOOD)
gbox("radio", (0.3, 0.18, 0.2), (3.15, 1.02, 2.60), M_DARK)
gbox("tray_papers", (0.4, 0.07, 0.3), (-0.55, 1.04, -3.45), M_WALL)
gbox("stamp_block", (0.12, 0.12, 0.12), (0.55, 1.06, -3.45), M_DARK)

# ---------------------------------------------------------------------------
#  Litera (dos camas) en la pared oeste
# ---------------------------------------------------------------------------
BX, BZ = -3.20, 1.80
for lvl, y in (("low", 0.35), ("up", 1.50)):
    gbox("bunk_%s_frame" % lvl,   (1.05, 0.12, 2.05), (BX, y, BZ), M_METAL)
    gbox("bunk_%s_mattress" % lvl, (0.95, 0.16, 1.92), (BX, y + 0.14, BZ), M_FABRIC)
    gbox("bunk_%s_pillow" % lvl,   (0.85, 0.12, 0.4), (BX, y + 0.16, BZ - 0.75), M_FABRIC)
for i, (dx, dz) in enumerate(((-0.5, -1.0), (0.5, -1.0), (-0.5, 1.0), (0.5, 1.0))):
    gbox("bunk_post_%d" % i, (0.08, 1.9, 0.08), (BX + dx, 1.0, BZ + dz), M_METAL)

# La puerta de salida (pared trasera) la dibuja world.gd por codigo, no va aqui.

# ---------------------------------------------------------------------------
#  Archivador, lampara de techo, reloj de pared
# ---------------------------------------------------------------------------
gbox("cabinet", (0.5, 1.2, 0.6), (3.55, 0.60, -1.00), M_METAL)
for i, y in enumerate((0.35, 0.70, 1.05)):
    gbox("cabinet_drawer_%d" % i, (0.42, 0.02, 0.62), (3.55, y, -1.00), M_DARK)

gbox("lamp_housing", (0.95, 0.12, 0.35), (0.0, 2.86, 0.40), M_METAL)
gbox("lamp_panel",   (0.75, 0.04, 0.25), (0.0, 2.78, 0.40), M_GLASS)

disc("wall_clock", 0.18, 0.06, gloc(1.6, 2.05, 3.88), M_DARK)

# ---------------------------------------------------------------------------
#  Agrupar bajo un Empty y exportar
# ---------------------------------------------------------------------------
env = bpy.data.objects.new("Environment", None)
bpy.context.collection.objects.link(env)
for o in _created:
    o.parent = env

out_dir = os.path.join(PROJECT_DIR, "models")
os.makedirs(out_dir, exist_ok=True)
glb_path = os.path.join(out_dir, "environment.glb")

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print("Exportado:", glb_path)

blend_dir = os.path.join(PROJECT_DIR, "blender")
os.makedirs(blend_dir, exist_ok=True)
try:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "environment.blend"))
    print("Guardado blend:", os.path.join(blend_dir, "environment.blend"))
except Exception as e:
    print("No se pudo guardar el .blend:", e)
