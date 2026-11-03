#!/usr/bin/env python3
"""Build the depot once, then render its four Factorio projections (bpy 4.5)."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import random
import sys

# Set before importing bpy, including when used through its Python wheel.
for key in ('OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS', 'MKL_NUM_THREADS'):
    os.environ[key] = '4'

import bpy
from mathutils import Vector

REVISION = 'depot-v2-geometry-2-open-workshop'
ROOT = Path(__file__).resolve().parents[2]
DIRECTIONS = {'north': 0, 'east': 4, 'south': 8, 'west': 12}
RNG = random.Random(31)
ACTIVE_ROOT = None
M = {}


def material(name, color, metallic=0.0, roughness=0.6, painted=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    coord = nodes.new('ShaderNodeTexCoord')
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 19
    noise.inputs['Detail'].default_value = 3
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.23
    ramp.color_ramp.elements[0].color = (*(c * 0.48 for c in color), 1)
    ramp.color_ramp.elements[1].position = 0.78
    ramp.color_ramp.elements[1].color = (*color, 1)
    links.new(noise.outputs['Fac'], ramp.inputs[0])
    links.new(ramp.outputs['Color'], shader.inputs['Base Color'])
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.19
    bump.inputs['Distance'].default_value = 0.018
    links.new(noise.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], shader.inputs['Normal'])
    if name.startswith('concrete'):
        # Broad ingrained dirt sits below the fine aggregate, without decals.
        broad = nodes.new('ShaderNodeTexNoise')
        broad.inputs['Scale'].default_value = 1.35
        broad.inputs['Detail'].default_value = 2
        links.new(coord.outputs['Object'], broad.inputs['Vector'])
        dirt = nodes.new('ShaderNodeValToRGB')
        dirt.color_ramp.elements[0].position = 0.28
        dirt.color_ramp.elements[0].color = (0.47, 0.39, 0.29, 1)
        dirt.color_ramp.elements[1].position = 0.72
        dirt.color_ramp.elements[1].color = (0.96, 0.91, 0.82, 1)
        links.new(broad.outputs['Fac'], dirt.inputs[0])
        mix = nodes.new('ShaderNodeMixRGB')
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 0.48
        links.new(ramp.outputs['Color'], mix.inputs[1])
        links.new(dirt.outputs['Color'], mix.inputs[2])
        links.new(mix.outputs[0], shader.inputs['Base Color'])
    texture = ROOT / 'tools/art/painted-steel.png'
    if painted and texture.exists():
        image = nodes.new('ShaderNodeTexImage')
        image.image = bpy.data.images.load(str(texture), check_existing=True)
        image.projection = 'BOX'
        image.projection_blend = 0.25
        links.new(coord.outputs['Generated'], image.inputs['Vector'])
        patina = nodes.new('ShaderNodeValToRGB')
        patina.color_ramp.elements[0].position = 0.3
        patina.color_ramp.elements[0].color = (0.38, 0.34, 0.27, 1)
        patina.color_ramp.elements[1].position = 0.68
        patina.color_ramp.elements[1].color = (0.88, 0.82, 0.7, 1)
        links.new(noise.outputs['Fac'], patina.inputs[0])
        wear = nodes.new('ShaderNodeMixRGB')
        wear.blend_type = 'MULTIPLY'
        wear.inputs[0].default_value = 0.7
        links.new(image.outputs['Color'], wear.inputs[1])
        links.new(patina.outputs[0], wear.inputs[2])
        links.new(wear.outputs[0], shader.inputs['Base Color'])
        image.image.pack()
    return mat


def finish(obj, name, mat, bevel=0):
    obj.name = name
    obj.parent = ACTIVE_ROOT
    obj.data.materials.append(M[mat])
    if bevel:
        mod = obj.modifiers.new('Machined edge highlights', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        mod = obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
        mod.keep_sharp = True
    return obj


def box(name, pos, size, mat='steel', bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    # Bake dimensions directly into the mesh: no operator context / negative scale.
    for vertex in obj.data.vertices:
        vertex.co.x *= size[0]
        vertex.co.y *= size[1]
        vertex.co.z *= size[2]
    return finish(obj, name, mat, bevel)


def cylinder(name, pos, radius, depth, mat='steel', axis='Z', vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=depth, location=pos)
    obj = bpy.context.object
    if axis == 'X':
        obj.rotation_euler.y = math.pi / 2
    elif axis == 'Y':
        obj.rotation_euler.x = math.pi / 2
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    return finish(obj, name, mat, 0.009)


def beam(name, start, end, width=0.08, mat='steel'):
    delta = Vector(end) - Vector(start)
    obj = box(name, (Vector(start) + Vector(end)) / 2,
              (width, width, delta.length), mat, min(width / 5, 0.025))
    obj.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    return obj


def bolts(x, y, z, axis='X', count=3, spacing=0.17):
    for i in range(count):
        cylinder('Hexagonal fastener', (x, y + (i-(count-1)/2)*spacing, z),
                 0.039, 0.032, 'silver', axis, 6)


def railings(x, y0, y1, z):
    for y in (y0, (y0+y1)/2, y1):
        cylinder('Guardrail upright', (x, y, z+0.36), 0.035, 0.72, 'yellow')
    for height in (0.22, 0.7):
        beam('Guardrail tube', (x, y0, z+height), (x, y1, z+height), 0.055, 'yellow')


def lamp(x, y, z):
    box('Lamp armored housing', (x, y, z), (0.28, 0.62, 0.19))
    box('Amber diffuser', (x-0.15, y, z-0.03), (0.035, 0.46, 0.1), 'amber', 0.015)
    box('Rear amber diffuser', (x+0.15, y, z-0.03), (0.035, 0.46, 0.1), 'amber', 0.015)
    for offset in (-0.17, 0, 0.17):
        box('Lamp protective cage', (x-0.18, y+offset, z-0.03), (0.035, 0.025, 0.15))
    data = bpy.data.lights.new('Warm work light', 'POINT')
    data.energy, data.color, data.shadow_soft_size = 14, (1, 0.52, 0.17), 0.28
    obj = bpy.data.objects.new('Warm work light', data)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = ACTIVE_ROOT
    obj.location = (x-0.3, y, z-0.13)


def rail_rack(x, y, length=4.0):
    for dy in (-length/2+0.2, length/2-0.2):
        box('Rail rack foot', (x, y+dy, 0.24), (1.8, 0.33, 0.16))
        for dx in (-0.72, 0.72):
            box('Rail rack stanchion', (x+dx, y+dy, 0.96), (0.13, 0.16, 1.5), 'yellow')
    for level in range(3):
        z = 0.48+level*0.41
        for dx in (-0.47, 0, 0.47):
            box('Stored rail flange', (x+dx, y, z), (0.24, length, 0.065), 'silver', 0.012)
            box('Stored rail web', (x+dx, y, z+0.09), (0.065, length, 0.15), 'rust', 0.008)
            box('Stored rail head', (x+dx, y, z+0.19), (0.14, length, 0.07), 'silver', 0.015)
        for dy in (-length/2+0.2, length/2-0.2):
            box('Rail rack shelf', (x, y+dy, z-0.05), (1.7, 0.17, 0.12))


def cabinet(x, y, red=False):
    box('Tool cabinet carcass', (x, y, 0.92), (1.0, 1.22, 1.5), 'red' if red else 'steel', 0.065)
    for z in (0.38, 0.62, 0.86, 1.1, 1.34):
        box('Drawer front', (x-0.515, y, z), (0.045, 1.1, 0.2), 'red' if red else 'panel')
        beam('Drawer brushed handle', (x-0.56, y-0.35, z+0.04),
             (x-0.56, y+0.35, z+0.04), 0.035, 'silver')
    box('Cabinet worktop', (x, y, 1.72), (1.12, 1.32, 0.12), 'silver')


def depot():
    # Deliberately no ground plane in the track corridor, no track or vehicles.
    for row in range(14):
        y = -13+2*row
        for col in range(3):
            x = 3.4+2.2*col
            tone = (row * 7 + col * 11 + row * col) % 5
            box('Expansion joint slab', (x, y, 0.06), (2.18, 1.98, 0.12),
                f'concrete-{tone}', 0.018)
    for y in (-13.7, 13.7):
        box('End curb', (5.65, y, 0.19), (6.65, 0.22, 0.28), 'concrete')
        for i in range(12):
            box('Curb safety paint', (2.65+i*0.52, y-0.005, 0.34), (0.27, 0.23, 0.025), 'yellow', 0.002)
    for y in range(-13, 14, 2):
        box('Platform edge paint', (2.48, y, 0.133), (0.12, 1.05, 0.015), 'yellow', 0)
    # Open on both sides: low cladding, skeletal frame, narrow rear catwalk.
    for index in range(7):
        y = -12+index*4
        box('Low rear cladding', (8.56, y, 0.44), (0.14, 3.9, 0.6), 'panel')
        for dy in (-1.83, 1.83):
            box('Rear frame upright', (8.48, y+dy, 1.39), (0.11, 0.11, 2.5))
            bolts(8.56, y+dy, 0.63, count=2, spacing=0.12)
        box('Rear service skirting', (8.46, y, 0.24), (0.12, 3.9, 0.16), 'rust')
        box('Rear horizontal girder', (8.5, y, 2.46), (0.17, 3.96, 0.16))
        box('Upper service catwalk', (8.36, y, 2.56), (0.48, 4, 0.1))
        for dy in (-1.4, 0, 1.4):
            box('Catwalk tread', (8.36, y+dy, 2.62), (0.43, 0.035, 0.02), 'silver', 0)
        railings(8.6, y-1.95, y+1.95, 2.64)
        lamp(8.18, y, 2.19)
        box('Workshop longitudinal girder', (7.67, y, 2.71), (0.12, 3.95, 0.14))
        if index in (0, 6):
            for sign in (-1, 1):
                beam('Rear tension crossbrace', (8.53, y-sign*1.78, 0.8),
                     (8.53, y+sign*1.78, 2.4), 0.045, 'silver')
    for y in (-13.6, -9.4, -5.2, 3.2, 7.4, 11.6, 13.5):
        box('Column baseplate', (7.43, y, 0.21), (0.66, 0.64, 0.16))
        box('Column web', (7.43, y, 1.42), (0.14, 0.19, 2.3))
        for x in (7.25, 7.61):
            box('Column flange', (x, y, 1.42), (0.085, 0.34, 2.3))
        box('Column yellow toe', (7.2, y, 0.57), (0.07, 0.38, 0.6), 'yellow')
        bolts(7.16, y, 0.33)
        bolts(7.64, y, 2.36, count=2, spacing=0.14)
        beam('Knee brace', (7.43, y, 1.85), (8.25, y, 2.49), 0.12)
    rail_rack(5.2, -10.8, 3.7)
    rail_rack(5.65, 5.8, 3.3)
    cabinet(7.65, -6.9, True)
    # Workbench, vise, sockets and individual laid-out metal tools.
    box('Workbench top', (7.42, -3.8, 1.16), (1.35, 1.8, 0.16), 'wood')
    for x in (6.95, 7.9):
        for y in (-4.48, -3.12):
            box('Workbench leg', (x, y, 0.64), (0.1, 0.1, 1.04))
    box('Workbench lower shelf', (7.42, -3.8, 0.39), (1.2, 1.7, 0.08))
    box('Vise base', (7.02, -4.25, 1.31), (0.4, 0.38, 0.12), 'steel')
    for y in (-4.4, -4.12):
        box('Vise jaw', (7.02, y, 1.43), (0.42, 0.09, 0.2), 'silver')
    beam('Vise spindle', (6.72, -4.25, 1.33), (7.32, -4.25, 1.33), 0.045, 'silver')
    for i in range(5):
        obj = box('Workbench tool', (7.25+i*0.1, -3.55+i*0.12, 1.27), (0.05, 0.35, 0.04), 'silver', 0.01)
        obj.rotation_euler.z = RNG.uniform(-0.5, 0.5)
    box('Electrical cabinet', (7.86, 9.22, 1.16), (0.94, 1.5, 1.95), 'panel', 0.06)
    for dy in (-0.38, 0.38):
        box('Cabinet door', (7.36, 9.22+dy, 1.18), (0.035, 0.7, 1.8), 'steel')
        box('Cabinet handle', (7.31, 9.22+dy-0.19, 1.18), (0.06, 0.04, 0.3), 'silver')
    for z in (0.46, 0.56, 0.66, 0.76):
        box('Cabinet ventilation', (7.32, 9.22, z), (0.025, 1.19, 0.035), 'black', 0)
    # Signal spares with small recessed lenses, not operational track signals.
    for y in (-8.5, -8.05, -7.6):
        box('Signal spares tray', (4.05, y, 0.28), (1.35, 0.38, 0.2))
        for x in (3.6, 4.02, 4.44):
            box('Signal housing', (x, y, 0.7), (0.26, 0.27, 0.68), 'black', 0.07)
            for z, mat in ((0.52, 'red'), (0.73, 'amber'), (0.94, 'green')):
                cylinder('Signal spare lens', (x, y-0.15, z), 0.072, 0.035, mat, 'Y')
    # Compact lateral hoist: all of it stays well clear of the track.
    y = 11.65
    for x in (4.45, 7.1):
        box('Hoist base', (x, y, 0.25), (0.68, 0.8, 0.2))
        box('Hoist upright', (x, y, 1.61), (0.26, 0.3, 2.6), 'yellow')
        bolts(x-0.15, y, 0.37)
        beam('Hoist diagonal gusset', (x, y, 2.2), (x+(-0.55 if x>5 else 0.55), y, 2.85), 0.14)
    box('Hoist crossbeam', (5.77, y, 2.99), (3.15, 0.38, 0.32), 'yellow')
    box('Hoist beam lower flange', (5.77, y, 2.81), (3.25, 0.52, 0.07))
    box('Hoist trolley', (5.35, y, 2.66), (0.54, 0.6, 0.26))
    cylinder('Hoist winch drum', (5.35, y, 2.42), 0.19, 0.42, 'steel', 'Y', 24)
    beam('Hoist hanging cable', (5.35, y, 2.35), (5.35, y, 1.55), 0.028, 'silver')
    cylinder('Hook pulley', (5.35, y, 1.52), 0.13, 0.13, 'yellow', 'Y', 24)
    # A real curved hook, not a billboard.
    points = [(5.35, y, 1.45), (5.35, y, 1.22), (5.49, y, 1.15), (5.6, y, 1.24)]
    for a, b in zip(points, points[1:]):
        beam('Forged hook', a, b, 0.065, 'silver')
    # Pipework and low roof extractors, kept on the back edge.
    for y in (-10.3, 6.3):
        cylinder('Extractor duct', (8.05, y, 2.9), 0.24, 0.53, 'silver', vertices=24)
        cylinder('Extractor rain cap', (8.05, y, 3.18), 0.34, 0.08, 'steel', vertices=24)
    for z in (0.45, 1.87):
        beam('Wall conduit', (8.36, -13.5, z), (8.36, 13.5, z), 0.045, 'rust')
    # Sparse irregular absorbed stains; no repeated opaque ellipse pattern.
    for x, y in ((6.8, -4.1), (7.1, -6.6), (4.2, 10.8)):
        vertices = []
        for i in range(15):
            angle = i*math.tau/15
            radius = RNG.uniform(0.13, 0.32)
            vertices.append((x+radius*math.cos(angle),
                             y+radius*0.65*math.sin(angle), 0.121))
        mesh = bpy.data.meshes.new('Absorbed oil outline')
        mesh.from_pydata(vertices, [], [list(range(15))])
        mesh.update()
        obj = bpy.data.objects.new('Irregular old oil stain', mesh)
        bpy.context.scene.collection.objects.link(obj)
        finish(obj, 'Irregular old oil stain', 'oil')
    for x, y in ((3.7, -9.2), (5.5, 8.1), (3.3, 3.8)):
        for a, b in (((x, y, 0.123), (x+0.22, y+0.28, 0.123)),
                     ((x+0.22, y+0.28, 0.123), (x+0.15, y+0.53, 0.123))):
            beam('Fine slab hairline', a, b, 0.008, 'oil')


def stock():
    # Origin-centered standalone child inventory; all geometry inside +/-1.3.
    box('Stock skid', (0, 0, 0.14), (2.55, 2.55, 0.24))
    box('Stock armored body', (0, 0, 0.7), (2.36, 2.32, 0.99), 'yellow', 0.08)
    box('Stock top rim', (0, 0, 1.25), (2.55, 2.51, 0.14))
    for y in (-0.74, 0, 0.74):
        box('Sliding stock lid', (0, y, 1.34), (2.28, 0.69, 0.1), 'panel')
        beam('Lid grip', (-0.3, y, 1.43), (0.3, y, 1.43), 0.06, 'silver')
    for x in (-1.21, 1.21):
        for y in (-1.08, 1.08):
            box('Stock corner armor', (x, y, 0.73), (0.12, 0.21, 1.05))
        for y in (-0.8, -0.4, 0, 0.4, 0.8):
            box('Stock side rib', (x, y, 0.7), (0.085, 0.09, 0.77))
        for y in (-0.86, 0.86):
            bolts(x*1.04, y, 1.14, count=2, spacing=0.12)
    for y in (-1.19, 1.19):
        box('Stock access panel', (0, y, 0.72), (1.87, 0.055, 0.7), 'steel')
        for x in (-0.67, 0.67):
            box('Stock latch', (x, y*1.025, 0.87), (0.12, 0.08, 0.28), 'silver')
        box('Inventory identification plate', (0, y*1.03, 0.73), (0.65, 0.022, 0.25), 'yellow')
    box('Inventory amber status', (-1.255, 0, 1.13), (0.035, 0.24, 0.09), 'amber')


def empty(name, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def visible(root, value):
    for child in root.children_recursive:
        child.hide_render = not value


def configure():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 4
    scene.cycles.use_denoising = True
    scene.cycles.seed = 31
    scene.cycles.max_bounces = 5
    scene.cycles.diffuse_bounces = 3
    scene.cycles.glossy_bounces = 3
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'
    scene.render.resolution_percentage = 100
    scene.render.use_file_extension = True
    scene.render.use_persistent_data = False
    scene.render.image_settings.compression = 35
    scene.view_settings.view_transform = 'AgX'
    world = bpy.data.worlds.new('Neutral studio ambient')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (0.37, 0.42, 0.5, 1)
    world.node_tree.nodes['Background'].inputs[1].default_value = 0.45
    scene.world = world
    camera_data = bpy.data.cameras.new('Fixed Factorio camera')
    camera = bpy.data.objects.new('Fixed Factorio camera', camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0, -60, 60)
    camera.rotation_euler = (-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.type = 'ORTHO'
    camera_data.clip_end = 250
    scene.camera = camera
    for name, pos, power, size, color in (
        ('Warm northwest key', (-18, -25, 38), 22000, 18, (1, 0.88, 0.71)),
        ('Cool fill', (16, 12, 24), 11000, 20, (0.69, 0.8, 1)),
    ):
        data = bpy.data.lights.new(name, 'AREA')
        data.energy, data.shape, data.size, data.color = power, 'DISK', size, color
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = pos
        obj.rotation_euler = (-obj.location).to_track_quat('-Z', 'Y').to_euler()
    return scene


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--direction', choices=('all', *DIRECTIONS), default='all')
    parser.add_argument('--samples', type=int, default=24)
    parser.add_argument('--output', type=Path, default=Path('.tools/art-output/experimental-renders'))
    parser.add_argument('--work-dir', type=Path, default=Path('.tools/art-output'))
    argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:]
    args = parser.parse_args(argv)
    if args.samples < 1:
        parser.error('--samples must be positive')
    return args


def main():
    global ACTIVE_ROOT
    args = arguments()
    args.output.mkdir(parents=True, exist_ok=True)
    args.work_dir.mkdir(parents=True, exist_ok=True)
    scene = configure()
    scene.cycles.samples = args.samples
    for name, color, metal, rough, painted in (
        ('steel', (0.105, 0.125, 0.14), 0.78, 0.44, False),
        ('panel', (0.23, 0.25, 0.24), 0.65, 0.57, False),
        ('yellow', (0.66, 0.38, 0.065), 0.48, 0.61, True),
        ('silver', (0.43, 0.47, 0.48), 0.85, 0.32, False),
        ('rust', (0.24, 0.105, 0.045), 0.45, 0.77, False),
        ('concrete', (0.27, 0.235, 0.185), 0, 0.92, False),
        ('black', (0.025, 0.032, 0.034), 0.45, 0.56, False),
        ('oil', (0.17, 0.145, 0.11), 0, 0.94, False),
        ('red', (0.34, 0.065, 0.035), 0.5, 0.57, False),
        ('green', (0.055, 0.27, 0.09), 0.3, 0.27, False),
        ('wood', (0.24, 0.15, 0.075), 0, 0.8, False),
        ('amber', (1, 0.44, 0.045), 0.1, 0.3, False),
    ):
        M[name] = material(name, color, metal, rough, painted)
    for index, tone in enumerate((0.85, 0.94, 1.0, 1.07, 1.15)):
        M[f'concrete-{index}'] = material(f'concrete-{index}',
            tuple(value*tone for value in (0.29, 0.255, 0.205)), roughness=0.94)
    shader = M['amber'].node_tree.nodes.get('Principled BSDF')
    shader.inputs['Emission Color'].default_value = (1, 0.32, 0.025, 1)
    shader.inputs['Emission Strength'].default_value = 2.0
    warp = empty('World projection warp AFTER local heading')
    warp.scale = (1, math.sqrt(2), 1)
    rig = empty('Local heading rig', warp)
    depot_root = empty('Depot geometry', rig)
    stock_root = empty('Independent stock geometry', rig)
    ACTIVE_ROOT = depot_root
    depot()
    ACTIVE_ROOT = stock_root
    stock()
    stock_root.location.x = 6.3
    scene.camera.data.ortho_scale = 40
    scene.render.resolution_x = scene.render.resolution_y = 1920
    bpy.ops.wm.save_as_mainfile(filepath=str((args.work_dir/'source.blend').resolve()))
    texture = ROOT/'tools/art/painted-steel.png'
    manifest = {
        'revision': REVISION, 'blender_version': bpy.app.version_string,
        'script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'texture': str(texture.relative_to(ROOT)) if texture.exists() else None,
        'texture_sha256': hashlib.sha256(texture.read_bytes()).hexdigest() if texture.exists() else None,
        'seed': 31, 'samples': args.samples, 'threads': 4, 'device': 'CPU',
        'camera': {'position': [0, -60, 60], 'target': [0, 0, 0], 'type': 'ORTHO'},
        'projection': {'world_scale': [1, math.sqrt(2), 1],
                       'rotation_z': '-heading*pi/8 (heading=0,4,8,12)',
                       'pixels_per_tile': 48, 'lua_scale': 2/3,
                       'depot_shift': [1, 1], 'stock_shift': [0, 0]},
        'local_bounds': {'workshop': [[2.3, -14, 0], [9, 14, 3.4]],
                         'reserved_stock': [[4.7, -2, 0.13], [7.9, 2, 1.6]],
                         'stock': [[-1.3, -1.3, 0], [1.3, 1.3, 1.5]]},
        'source': 'source.blend', 'objects': len(bpy.data.objects), 'renders': [],
    }
    selected = DIRECTIONS if args.direction == 'all' else {args.direction: DIRECTIONS[args.direction]}
    for direction, heading in selected.items():
        # Factorio direction units are sixteenths of a complete revolution.
        rig.rotation_euler.z = -heading * math.pi / 8
        for kind, root, resolution, ortho in (
            ('depot', depot_root, 1920, 40), ('stock', stock_root, 288, 6)
        ):
            visible(depot_root, root == depot_root)
            visible(stock_root, root == stock_root)
            stock_root.location.x = 0 if kind == 'stock' else 6.3
            scene.camera.data.ortho_scale = ortho
            scene.render.resolution_x = scene.render.resolution_y = resolution
            path = args.output / f'{kind}-{direction}.png'
            scene.render.filepath = str(path.resolve())
            bpy.ops.render.render(write_still=True)
            manifest['renders'].append({'file': path.name, 'kind': kind,
                                        'direction': direction, 'heading': heading,
                                        'width': resolution, 'height': resolution,
                                        'ortho_scale': ortho, 'rgba': True})
            (args.work_dir/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f"Rendered {len(manifest['renders'])} sprites; source: {args.work_dir/'source.blend'}", flush=True)


if __name__ == '__main__':
    main()
