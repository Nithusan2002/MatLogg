"""Export a selected V8 clip, without modifying the Blender source.

Blender --background docs/assets/brand/3d/spor-mascot-v8.blend
  --python scripts/export-spor-mobile.py -- --output-dir /tmp/spor-export
  --clip idle [--ascii]
"""
import argparse
import math
from pathlib import Path
import sys
import bpy
from mathutils import Quaternion, Vector

parser = argparse.ArgumentParser()
parser.add_argument('--output-dir', type=Path, required=True)
parser.add_argument('--clip', choices=['idle', 'greeting', 'walk'], default='idle')
parser.add_argument('--ascii', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
args.output_dir.mkdir(parents=True, exist_ok=True)
s = bpy.context.scene
rig = bpy.data.objects['SPOR • animasjonsrigg V8']
skin = bpy.data.objects['SPOR • sammenhengende formstudie']
kind = {'idle': 'Hvile', 'greeting': 'Hilsen', 'walk': 'Gange'}[args.clip]
rig.animation_data.action = bpy.data.actions[f'Spor • {kind} V8']
s.frame_start, s.frame_end = 1, 49 if args.clip == 'walk' else 145
s.frame_set(1)
if args.clip != 'walk':
    # This USD exporter drops the very small animated bone scales. Preserve
    # the breathing cue with a sampled, sub-centimetre torso translation.
    body = rig.pose.bones['Kropp']
    axis = body.bone.matrix_local.to_3x3().inverted() @ Vector((0, 0, 1))
    for frame in range(s.frame_start, s.frame_end + 1):
        s.frame_set(frame)
        body.location = axis * ((body.scale.y - 1) * 1.8)
        body.keyframe_insert('location', frame=frame)
    s.frame_set(1)
if args.clip == 'walk':
    # Export a fixed-position cycle for the app's fixed preview camera.
    action = rig.animation_data.action
    for layer in action.layers:
        for strip in layer.strips:
            for slot in action.slots:
                bag = strip.channelbag(slot)
                if bag:
                    for curve in bag.fcurves:
                        if curve.data_path == 'pose.bones["Root"].location':
                            for point in curve.keyframe_points:
                                point.co.y = 0
                                point.handle_left.y = point.handle_right.y = 0
    s.frame_set(1)

# Remove Blender-only surface modifiers in this export copy. Keep skinning.
for modifier in list(skin.modifiers):
    if modifier.type != 'ARMATURE':
        skin.modifiers.remove(modifier)
decimate = skin.modifiers.new('Mobile topology', 'DECIMATE')
decimate.ratio = 0.14
bpy.ops.object.select_all(action='DESELECT')
skin.select_set(True)
bpy.context.view_layer.objects.active = skin
bpy.ops.object.modifier_move_to_index(modifier=decimate.name, index=0)
bpy.ops.object.modifier_apply(modifier=decimate.name)
if args.clip == 'greeting':
    # The welded arm's blended body/arm weights squash its tip in USD skinning.
    # Reconstruct this arm as a rounded, rigidly skinned flipper in the export
    # copy. Its hidden proximal end overlaps the torso at the existing pivot.
    arm_group = skin.vertex_groups['Arm.R']
    body_group = skin.vertex_groups['Kropp']
    for vertex in skin.data.vertices:
        x, y, z = vertex.co
        if x <= 0 or not 1.08 < z < 2.15:
            continue
        # Restore the original analytical torso beneath the welded flipper.
        c = max(-1, min(1, (z - 1.73) / 1.10))
        radius = 1.12 * max(0, 1 - c * c) ** 0.34 * (1 - 0.25 * c)
        center = 0.18 * max(0, min(1, (z - 0.63) / 2.20)) ** 2
        ratio = math.hypot((x - center) / radius, y / (0.71 * radius))
        if ratio > 1:
            vertex.co.x = center + (x - center) / ratio
            vertex.co.y = y / ratio
        if any(group.group == arm_group.index for group in vertex.groups):
            arm_group.remove([vertex.index])
            body_group.add([vertex.index], 1, 'REPLACE')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=(1.20, -0.04, 1.65))
    hand = bpy.context.object
    hand.name = 'SPOR • rund mobilarm for hilsen'
    hand.scale = (0.22, 0.21, 0.43)
    hand.rotation_euler[1] = -0.36
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    hand.parent = skin
    hand.data.materials.append(skin.data.materials[0])
    for polygon in hand.data.polygons:
        polygon.use_smooth = True
    group = hand.vertex_groups.new(name='Arm.R')
    group.add(list(range(len(hand.data.vertices))), 1, 'REPLACE')
    modifier = hand.modifiers.new('Hilsen • bevar rund hånd', 'ARMATURE')
    modifier.object = rig

    def smooth(a, b, value):
        t = max(0, min(1, (value - a) / (b - a)))
        return t * t * (3 - 2 * t)

    # Lift the flipper above the shoulder, then make two small, soft waves.
    bone = rig.pose.bones['Arm.R']
    axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector((0, 1, 0))
    for frame in range(s.frame_start, s.frame_end + 1):
        s.frame_set(frame)
        envelope = smooth(19, 45, frame) * (1 - smooth(98, 126, frame))
        wave = 0.10 * math.sin(math.tau * (frame - 45) / 28)
        wave *= smooth(45, 54, frame) * (1 - smooth(88, 98, frame))
        bone.rotation_quaternion = Quaternion(axis, (-1.95 + wave) * envelope)
        bone.keyframe_insert('rotation_quaternion', frame=frame)
    s.frame_set(1)
for obj in [skin] + list(skin.children):
    # Small mobile PBR materials; procedural grain stays in the source model.
    for slot in obj.material_slots:
        if slot.material:
            slot.material = slot.material.copy()
            shader = slot.material.node_tree.nodes.get('Principled BSDF')
            if shader:
                for link in list(slot.material.node_tree.links):
                    slot.material.node_tree.links.remove(link)
                output = slot.material.node_tree.nodes.get('Material Output')
                slot.material.node_tree.links.new(shader.outputs['BSDF'], output.inputs['Surface'])
                shader.inputs['Normal'].default_value = (0, 0, 0)

objects = [rig, skin] + list(skin.children)
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:
    obj.select_set(True)
triangles = sum(len(poly.vertices) - 2 for obj in objects if obj.type == 'MESH' for poly in obj.data.polygons)
assert triangles <= 20000, triangles
name = f'spor-{args.clip}'
suffix = 'usda' if args.ascii else 'usdz'
result = bpy.ops.wm.usd_export(
    filepath=str(args.output_dir / f'{name}.{suffix}'), selected_objects_only=True,
    export_animation=True, export_armatures=True, export_shapekeys=True,
    export_subdivision='IGNORE', export_lights=False, export_cameras=False,
    export_custom_properties=False, generate_materialx_network=False,
    convert_world_material=False, convert_orientation=True,
    export_global_up_selection='Y', export_global_forward_selection='NEGATIVE_Z',
    triangulate_meshes=True, relative_paths=True, evaluation_mode='RENDER')
assert result == {'FINISHED'}, result
print('SPOR_EXPORT_OK', args.clip, triangles, 'triangles', flush=True)
