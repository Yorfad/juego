# -*- coding: utf-8 -*-
"""
Genera los companeros: UN glb por persona (crew_nava.glb, crew_robles.glb, ...)
construido en el origen local, mirando -Z (Godot). world.gd los instancia como
CharacterBody3D con companion.gd y los mueve por el mapa.

El brazo derecho es un nodo aparte llamado "arm_r" con el pivote en el hombro:
companion.gd lo rota para el saludo militar.

Colores y datos salen de data/crew.json.

USO: Blender > Scripting > abrir este .py > Run Script (Alt+P).
"""

import bpy
import os
import json
from math import radians

# Raiz del proyecto: se calcula desde el .blend abierto (juego/blender/). Si abres
# Blender en blanco, cambia la ruta de abajo por la tuya.
_blend = bpy.data.filepath
PROJECT_DIR = os.path.dirname(os.path.dirname(_blend)) if _blend else r"C:\Users\Morales\Desktop\juego"

# --- ejes: Godot (x, y=alto, z=prof) -> Blender (x, -z, y) -------------------
def gloc(x, y, z):
    return (x, -z, y)

def gsize(sx, sy, sz):
    return (sx, sz, sy)

_created = []


def clear_scene():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for coll in (bpy.data.meshes, bpy.data.materials):
        for b in list(coll):
            if b.users == 0:
                coll.remove(b)
    _created.clear()


def mat(name, rgb, rough=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    for s in ("Specular IOR Level", "Specular"):
        if s in b.inputs:
            b.inputs[s].default_value = 0.0
            break
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


def cyl(name, r, h, gl, material):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=gloc(*gl), vertices=10)
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    _created.append(o)
    return o


def build_figure(cid, uniform_rgb):
    U = mat("u_%s" % cid, uniform_rgb)
    SKIN = mat("skin", (0.55, 0.42, 0.34))
    BOOT = mat("boot", (0.09, 0.09, 0.10))
    DARK = mat("dark", (0.12, 0.12, 0.13))
    CAP = mat("cap_%s" % cid, (uniform_rgb[0] * 0.65, uniform_rgb[1] * 0.65, uniform_rgb[2] * 0.65))

    root = bpy.data.objects.new("crew_%s" % cid, None)
    bpy.context.collection.objects.link(root)

    wide = 1.16 if cid == "pena" else 1.0
    gbox("pelvis", (0.34 * wide, 0.30, 0.22), (0.0, 0.95, 0.0), U)
    gbox("torso",  (0.42 * wide, 0.26, 0.50), (0.0, 1.35, 0.0), U)
    gbox("neck",   (0.11, 0.11, 0.10), (0.0, 1.62, 0.0), SKIN)
    gbox("head",   (0.20, 0.22, 0.22), (0.0, 1.80, -0.02), SKIN)

    for sx in (-1, 1):
        gbox("leg_%d" % sx,  (0.15, 0.15, 0.92), (sx * 0.10, 0.47, 0.0), U)
        gbox("boot_%d" % sx, (0.16, 0.28, 0.12), (sx * 0.10, 0.06, -0.05), BOOT)

    gbox("arm_l",  (0.11, 0.11, 0.60), (-0.29, 1.28, 0.0), U)
    gbox("hand_l", (0.10, 0.10, 0.10), (-0.29, 0.97, 0.0), SKIN)

    # brazo derecho: pivote (Empty) en el hombro, malla colgando -> saludo
    ar = bpy.data.objects.new("arm_r", None)
    bpy.context.collection.objects.link(ar)
    ar.location = gloc(0.29, 1.56, 0.0)
    am = gbox("arm_r_mesh", (0.11, 0.11, 0.58), (0.29, 1.27, 0.0), U)
    ah = gbox("hand_r", (0.10, 0.10, 0.10), (0.29, 0.98, 0.0), SKIN)
    bpy.context.view_layer.update()
    for ch in (am, ah):
        ch.parent = ar
        ch.matrix_parent_inverse = ar.matrix_world.inverted()
    _created.append(ar)

    if cid in ("nava", "ruiz"):
        gbox("cap_top",  (0.21, 0.22, 0.11), (0.0, 1.96, 0.0), CAP)
        gbox("cap_brim", (0.24, 0.34, 0.04), (0.0, 1.91, -0.13), CAP)
    if cid == "robles":
        gbox("collar", (0.30, 0.10, 0.28), (0.0, 1.56, 0.0), DARK)
    if cid == "pena":
        gbox("belly", (0.40, 0.32, 0.24), (0.0, 1.12, -0.03), U)
        cyl("bottle", 0.04, 0.20, (0.30, 1.00, -0.12), DARK)
    if cid == "ruiz":
        gbox("clipboard", (0.24, 0.02, 0.30), (0.0, 1.24, -0.20), DARK)

    for o in _created:
        if o.parent is None and o is not root:
            o.parent = root


def export(cid):
    out_dir = os.path.join(PROJECT_DIR, "models")
    os.makedirs(out_dir, exist_ok=True)
    glb = os.path.join(out_dir, "crew_%s.glb" % cid)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=glb, export_format='GLB', use_selection=True, export_apply=True,
    )
    print("Exportado:", glb)
    blend_dir = os.path.join(PROJECT_DIR, "blender")
    try:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "crew_%s.blend" % cid))
    except Exception as e:
        print("No se pudo guardar el .blend de %s:" % cid, e)


CREW = json.load(open(os.path.join(PROJECT_DIR, "data", "crew.json"), encoding="utf-8"))["crew"]
for c in CREW:
    clear_scene()
    build_figure(c["id"], c.get("uniform", [0.30, 0.32, 0.26]))
    export(c["id"])

print("Companeros generados:", ", ".join(c["id"] for c in CREW))
