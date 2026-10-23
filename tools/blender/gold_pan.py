"""Build only the owned GoldPan collection; safe-mode-friendly bpy modeling code.

Run in Blender's Text Editor or send this file's contents to Blender MCP.
Dimensions are visual geometry, not gameplay tuning. Blender Z is up.
"""
import math
import bpy


def build_pan():
    name = "GoldPan_Generated"
    previous = bpy.data.collections.get(name)
    if previous is not None:
        assert previous.get("generator") == "tools/blender/gold_pan.py", "Unowned collection collision"
        for obj in list(previous.objects):
            mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh.users == 0:
                bpy.data.meshes.remove(mesh)
        bpy.data.collections.remove(previous)

    collection = bpy.data.collections.new(name)
    collection["generator"] = "tools/blender/gold_pan.py"
    bpy.context.scene.collection.children.link(collection)
    # Closed cross-section: underside, flared wall, rolled rim, interior riffles, floor.
    profile = [
        (0, 0), (0.64, 0), (0.70, 0.035), (1.04, 0.36),
        (1.09, 0.38), (1.10, 0.42), (1.08, 0.45), (1.03, 0.45),
        (1.00, 0.41), (0.94, 0.35), (0.90, 0.35), (0.89, 0.30),
        (0.84, 0.25), (0.80, 0.25), (0.79, 0.20), (0.74, 0.15),
        (0.70, 0.15), (0.69, 0.10), (0.62, 0.07), (0, 0.07),
    ]
    segments = 48
    vertices, rings, faces = [], [], []
    for radius, height in profile:
        ring = []
        for index in range(1 if radius == 0 else segments):
            angle = 2 * math.pi * index / segments
            ring.append(len(vertices))
            vertices.append((radius * math.cos(angle), radius * math.sin(angle), height))
        rings.append(ring)
    for lower, upper in zip(rings, rings[1:]):
        for index in range(segments):
            nxt = (index + 1) % segments
            if len(lower) == 1:
                faces.append((lower[0], upper[nxt], upper[index]))
            elif len(upper) == 1:
                faces.append((lower[index], lower[nxt], upper[0]))
            else:
                faces.append((lower[index], lower[nxt], upper[nxt], upper[index]))
    mesh = bpy.data.meshes.new("GoldPanMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    assert not mesh.validate(), "Generated mesh needed repair"
    pan = bpy.data.objects.new("GoldPan", mesh)
    collection.objects.link(pan)
    material = bpy.data.materials.get("GoldPan_Green")
    if material is None:
        material = bpy.data.materials.new("GoldPan_Green")
        material["generator"] = "tools/blender/gold_pan.py"
    else:
        assert material.get("generator") == "tools/blender/gold_pan.py", "Unowned material collision"
    material.use_nodes = True
    shader = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (0.035, 0.24, 0.11, 1)
    shader.inputs["Metallic"].default_value = 0.25
    shader.inputs["Roughness"].default_value = 0.38
    material.diffuse_color = (0.035, 0.24, 0.11, 1)
    mesh.materials.append(material)
    print("GoldPan built:", len(mesh.vertices), "vertices;", len(mesh.polygons), "faces")
    return pan


if __name__ == "__main__":
    build_pan()
