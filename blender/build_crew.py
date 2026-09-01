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
    # gbox espera tamano de Godot: (ancho X, ALTO Y, fondo Z).
    U    = mat("u_%s" % cid, uniform_rgb)
    SKIN = mat("skin", (0.55, 0.42, 0.34))
    BOOT = mat("boot", (0.08, 0.08, 0.09))
    BELT = mat("belt", (0.10, 0.09, 0.09))
    DK   = mat("dk", (0.13, 0.13, 0.14))
    CAP  = mat("cap_%s" % cid, (uniform_rgb[0] * 0.6, uniform_rgb[1] * 0.6, uniform_rgb[2] * 0.6))

    root = bpy.data.objects.new("crew_%s" % cid, None)
    bpy.context.collection.objects.link(root)

    wide = 1.14 if cid == "pena" else 1.0

    # --- piernas (verticales) ---
    for sx in (-1, 1):
        gbox("boot_%d" % sx,  (0.14, 0.13, 0.30), (sx * 0.11, 0.065, -0.05), BOOT)
        gbox("shin_%d" % sx,  (0.13, 0.44, 0.13), (sx * 0.11, 0.34, 0.0), U)
        gbox("knee_%d" % sx,  (0.15, 0.10, 0.15), (sx * 0.11, 0.57, 0.0), U)
        gbox("thigh_%d" % sx, (0.17, 0.40, 0.18), (sx * 0.11, 0.81, 0.0), U)

    # --- torso ---
    gbox("hips",   (0.40 * wide, 0.22, 0.25), (0.0, 1.06, 0.0), U)
    gbox("belt",   (0.44 * wide, 0.07, 0.28), (0.0, 1.15, 0.0), BELT)
    gbox("buckle", (0.09, 0.07, 0.05), (0.0, 1.15, -0.15), CAP)
    gbox("waist",  (0.37 * wide, 0.20, 0.23), (0.0, 1.29, 0.0), U)
    gbox("chest",  (0.46 * wide, 0.30, 0.26), (0.0, 1.51, 0.0), U)
    gbox("pkt_l",  (0.12, 0.11, 0.03), (-0.14, 1.50, -0.14), CAP)
    gbox("pkt_r",  (0.12, 0.11, 0.03), (0.14, 1.50, -0.14), CAP)
    gbox("collar", (0.31, 0.08, 0.25), (0.0, 1.67, 0.0), CAP)

    # --- cabeza ---
    gbox("neck", (0.10, 0.10, 0.10), (0.0, 1.71, 0.0), SKIN)
    gbox("head", (0.19, 0.23, 0.21), (0.0, 1.84, -0.01), SKIN)
    gbox("nose", (0.05, 0.05, 0.06), (0.0, 1.83, -0.12), SKIN)

    # --- hombros + brazo izquierdo (fijo) ---
    for sx in (-1, 1):
        gbox("shldr_%d" % sx, (0.16, 0.11, 0.19), (sx * 0.29, 1.61, 0.0), U)
    gbox("uarm_l", (0.11, 0.33, 0.12), (-0.31, 1.43, 0.0), U)
    gbox("elbo_l", (0.10, 0.09, 0.10), (-0.31, 1.25, 0.0), U)
    gbox("farm_l", (0.10, 0.30, 0.11), (-0.31, 1.08, 0.02), U)
    gbox("hand_l", (0.09, 0.10, 0.12), (-0.31, 0.90, 0.03), SKIN)

    # --- brazo derecho: pivote (Empty) en el hombro -> saludo ---
    ar = bpy.data.objects.new("arm_r", None)
    bpy.context.collection.objects.link(ar)
    ar.location = gloc(0.31, 1.59, 0.0)
    parts_r = [
        gbox("uarm_r", (0.11, 0.33, 0.12), (0.31, 1.43, 0.0), U),
        gbox("elbo_r", (0.10, 0.09, 0.10), (0.31, 1.25, 0.0), U),
        gbox("farm_r", (0.10, 0.30, 0.11), (0.31, 1.08, 0.02), U),
        gbox("hand_r", (0.09, 0.10, 0.12), (0.31, 0.90, 0.03), SKIN),
    ]
    bpy.context.view_layer.update()
    for ch in parts_r:
        ch.parent = ar
        ch.matrix_parent_inverse = ar.matrix_world.inverted()
    _created.append(ar)

    # --- props por persona ---
    if cid in ("nava", "ruiz"):
        gbox("cap_top",  (0.21, 0.11, 0.22), (0.0, 2.00, 0.0), CAP)
        gbox("cap_peak", (0.22, 0.03, 0.13), (0.0, 1.965, -0.16), CAP)
    if cid == "robles":
        gbox("beanie", (0.20, 0.12, 0.21), (0.0, 1.98, 0.0), DK)
    if cid == "pena":
        gbox("belly",  (0.46, 0.28, 0.32), (0.0, 1.31, 0.02), U)
        cyl("bottle", 0.037, 0.19, (0.34, 1.00, 0.08), DK)
    if cid == "ruiz":
        gbox("clipbd", (0.24, 0.30, 0.02), (0.0, 1.25, -0.19), DK)
        gbox("clip",   (0.11, 0.03, 0.03), (0.0, 1.39, -0.20), CAP)

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
