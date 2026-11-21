#!/usr/bin/env python3
"""Generates the gray-box Desk World as Rojo model files.

    python3 tools/gen_world.py

Writes:
    world/DeskWorld.model.json     -> Workspace.DeskWorld (hub, plots, Desk Dash track and zones)
    world/ClubUpgrades.model.json  -> ServerStorage.ClubUpgrades (upgrade placeholder models)

Stage 1 placeholders only: primitives, no art. Edit this script, not the JSON, then re-run it.
Units are studs. Y is up; the track runs along +X from the hub.
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "world")

IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]

COLORS = {
    "desk": [0.62, 0.47, 0.33],
    "hub": [0.75, 0.75, 0.75],
    "book": [0.55, 0.57, 0.62],
    "book_alt": [0.48, 0.50, 0.56],
    "pencil": [0.85, 0.72, 0.35],
    "ruler": [0.80, 0.80, 0.70],
    "eraser": [0.90, 0.60, 0.62],
    "note": [0.95, 0.90, 0.45],
    "checkpoint": [0.40, 0.70, 0.45],
    "start": [0.35, 0.55, 0.85],
    "finish": [0.95, 0.80, 0.30],
    "plot": [0.70, 0.70, 0.72],
    "banner": [0.98, 0.85, 0.40],
    "post": [0.40, 0.40, 0.42],
}


def cframe(x, y, z):
    return {"CFrame": {"position": [x, y, z], "orientation": IDENTITY}}


def attributes(values):
    """Rojo needs the explicit typed form for attributes (implicit values are rejected)."""
    typed = {}
    for key, value in values.items():
        if isinstance(value, bool):
            typed[key] = {"Bool": value}
        elif isinstance(value, (int, float)):
            typed[key] = {"Float64": float(value)}
        else:
            typed[key] = {"String": str(value)}
    return {"Attributes": typed}


def part(name, size, top_or_center, color, *, center=False, collide=True, touch=False, transparency=0.0, attrs=None, query=True):
    """A block. By default `top_or_center` is (x, top_y, z): the walkable top surface height."""
    x, y, z = top_or_center
    cy = y if center else y - size[1] / 2
    props = {
        "Anchored": True,
        "Size": list(size),
        "CFrame": cframe(x, cy, z),
        "Color": color,
        "Material": "SmoothPlastic",
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
        "CanCollide": collide,
        "CanTouch": touch,
        "CanQuery": query,
        "Transparency": transparency,
    }
    if attrs:
        props["Attributes"] = attributes(attrs)
    return {"name": name, "className": "Part", "properties": props}


def zone(name, kind, index, x, top_y, z, sx, sz, height=8):
    """Invisible server trigger above a platform (ARCHITECTURE.md 8.2)."""
    return part(
        name,
        (sx, height, sz),
        (x, top_y + height / 2, z),
        [1, 1, 1],
        center=True,
        collide=False,
        touch=True,
        query=False,
        transparency=1.0,
        attrs={"DashZone": kind, "Index": index},
    )


def model(name, children, class_name="Model"):
    return {"name": name, "className": class_name, "children": children}


def folder(name, children):
    return model(name, children, "Folder")


# --- Desk Dash track ----------------------------------------------------------------

def build_track():
    geo = []  # walkable pieces
    zones = []
    spawns = []  # respawn points per checkpoint (index 0 = start)

    def piece(name, length, width, top, color, x0, z=0.0, thickness=2.0):
        """Adds a block that starts at x0 along +X; returns its far edge."""
        geo.append(part(name, (length, thickness, width), (x0 + length / 2, top, z), color))
        return x0 + length

    def spawn_point(name, x, top, z=0.0):
        spawns.append(
            {
                "name": name,
                "className": "Part",
                "properties": {
                    "Anchored": True,
                    "Size": [2, 1, 2],
                    "CFrame": cframe(x, top + 3, z),
                    "Transparency": 1.0,
                    "CanCollide": False,
                    "CanTouch": False,
                    "CanQuery": False,
                },
            }
        )

    # Start pad (blue), reached from the hub by stairs.
    start_top = 10.0
    x = piece("StartPad", 20, 20, start_top, COLORS["start"], 20)
    zones.append(zone("StartZone", "Start", 0, 30, start_top, 0, 18, 18, height=6))
    spawn_point("Spawn0", 30, start_top)

    # Segment 1: book staircase and a long book-top walkway.
    top = start_top
    for i in range(6):
        top += 2
        x = piece(f"Book{i + 1}", 10, 16, top, COLORS["book"] if i % 2 == 0 else COLORS["book_alt"], x)
    x = piece("BookWalkway", 60, 12, top, COLORS["book"], x)

    def checkpoint(index, x0, top_y):
        end = piece(f"Checkpoint{index}Pad", 16, 16, top_y, COLORS["checkpoint"], x0)
        cx = x0 + 8
        zones.append(zone(f"Checkpoint{index}", "Checkpoint", index, cx, top_y, 0, 14, 14))
        spawn_point(f"Spawn{index}", cx, top_y)
        return end

    x = checkpoint(1, x, top)

    # Segment 2: pencil beams with gaps.
    for i in range(4):
        x += 6
        x = piece(f"Pencil{i + 1}", 24, 3, top, COLORS["pencil"], x)
    x += 6
    x = checkpoint(2, x, top)

    # Segment 3: ruler bridge, then eraser hops going up and down.
    x = piece("RulerBridge", 90, 4, top, COLORS["ruler"], x, thickness=1.0)
    hop_tops = [top + 2, top + 4, top + 2, top, top + 2]
    for i, hop_top in enumerate(hop_tops):
        x += 7
        x = piece(f"Eraser{i + 1}", 8, 8, hop_top, COLORS["eraser"], x, thickness=3.0)
    x += 7
    x = checkpoint(3, x, top + 2)
    top += 2

    # Segment 4: zigzag sticky notes.
    for i in range(6):
        x += 4
        x = piece(f"Note{i + 1}", 10, 10, top, COLORS["note"], x, z=5.0 if i % 2 == 0 else -5.0, thickness=1.0)
    x += 5
    x = checkpoint(4, x, top)

    # Segment 5: final climb to the mug (finish).
    for i in range(4):
        top += 3
        x = piece(f"Climb{i + 1}", 10, 14, top, COLORS["book_alt"], x)
    finish_x0 = x
    x = piece("FinishPad", 20, 20, top, COLORS["finish"], x)
    zones.append(zone("FinishZone", "Finish", 5, finish_x0 + 10, top, 0, 18, 18))

    track_length = x - 20
    return geo, zones, spawns, track_length


# --- Hub and club plots ----------------------------------------------------------------

PLOT_POSITIONS = [(-25, -40), (-55, -40), (-85, -40), (-25, 40), (-55, 40), (-85, 40)]
PLOT_TOP = 1.5


def build_hub():
    children = [
        # Desk top: hub floor and the ground under the track. Top surface at y = 1.
        part("DeskTop", (760, 4, 180), (270, 1, 0), COLORS["desk"]),
        # Stairs from the hub up to the start pad (tops 2.5, 5, 7.5).
        part("StartStair1", (4, 2.5, 20), (12, 2.5, 0), COLORS["hub"], center=False),
        part("StartStair2", (4, 5, 20), (16, 5, 0), COLORS["hub"]),
        part("StartStair3", (4, 7.5, 20), (19, 7.5, 0), COLORS["hub"]),
        {
            "name": "HubSpawn",
            "className": "SpawnLocation",
            "properties": {
                "Anchored": True,
                "Size": [8, 1, 8],
                "CFrame": cframe(-5, 1.5, 0),
                "Color": COLORS["hub"],
                "Material": "SmoothPlastic",
                "Neutral": True,
                "Duration": 0,
            },
        },
        {
            # Where players are sent after a finish or a restart (not on the start pad).
            "name": "ReturnPoint",
            "className": "Part",
            "properties": {
                "Anchored": True,
                "Size": [2, 1, 2],
                "CFrame": cframe(2, 4.5, 0),
                "Transparency": 1.0,
                "CanCollide": False,
                "CanTouch": False,
                "CanQuery": False,
            },
        },
    ]
    plots = []
    for i, (px, pz) in enumerate(PLOT_POSITIONS, start=1):
        plots.append(
            part(f"Plot{i}", (24, 1, 24), (px, PLOT_TOP, pz), COLORS["plot"], attrs={"PlotIndex": i})
        )
    children.append(folder("Plots", plots))
    return children


def build_upgrades():
    """Placeholder models, authored relative to the plot centre at the origin (top surface y = 0)."""
    sticky_banner = model(
        "sticky_banner",
        [
            part("PostLeft", (0.6, 8, 0.6), (-4, 8, -10), COLORS["post"]),
            part("PostRight", (0.6, 8, 0.6), (4, 8, -10), COLORS["post"]),
            part("Banner", (8, 3, 0.3), (0, 7.5, -10), COLORS["banner"], center=True),
        ],
    )
    return model("ClubUpgrades", [sticky_banner], "Folder")


def main():
    geo, zones, spawns, length = build_track()
    world = {
        "className": "Model",
        "children": build_hub()
        + [
            model(
                "DeskDash",
                [
                    folder("Geometry", geo),
                    folder("Zones", zones),
                    folder("Spawns", spawns),
                ],
            )
        ],
    }
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "DeskWorld.model.json"), "w") as f:
        json.dump(world, f, indent=2)
        f.write("\n")
    upgrades = build_upgrades()
    upgrades.pop("name")
    with open(os.path.join(OUT, "ClubUpgrades.model.json"), "w") as f:
        json.dump(upgrades, f, indent=2)
        f.write("\n")
    print(f"track length ~{length:.0f} studs, {len(geo)} pieces, {len(zones)} zones")


if __name__ == "__main__":
    main()
