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
# Turned 90 degrees about Y: the Front face (where SurfaceGuis go) looks back along -X, at runners.
YAW_90 = [[0, 0, 1], [0, 1, 0], [-1, 0, 0]]
# Turned 90 degrees about Z: a cylinder (axis X by default) stands upright.
ROLL_90 = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]

COLORS = {
    "desk": [0.70, 0.50, 0.32],
    "hub": [0.93, 0.88, 0.78],
    "book": [0.86, 0.33, 0.30],
    "book_alt": [0.25, 0.58, 0.72],
    "book_green": [0.36, 0.67, 0.45],
    "book_purple": [0.55, 0.42, 0.72],
    "pages": [0.97, 0.94, 0.84],
    "pencil": [0.98, 0.78, 0.18],
    "pencil_stripe": [0.85, 0.52, 0.10],
    "ruler": [0.93, 0.86, 0.60],
    "ruler_tick": [0.30, 0.24, 0.16],
    "eraser": [0.96, 0.52, 0.58],
    "note": [1.00, 0.92, 0.42],
    "note_alt": [0.60, 0.90, 0.62],
    "checkpoint": [0.30, 0.78, 0.48],
    "start": [0.30, 0.52, 0.95],
    "finish": [1.00, 0.78, 0.20],
    "plot": [0.88, 0.84, 0.76],
    "banner": [1.00, 0.80, 0.25],
    "post": [0.52, 0.40, 0.30],
    "board": [0.18, 0.22, 0.32],
    "gold": [1.00, 0.80, 0.20],
    "silver": [0.82, 0.86, 0.92],
    "bronze": [0.80, 0.50, 0.25],
    "dark": [0.20, 0.21, 0.27],
    "wood": [0.85, 0.68, 0.45],
    "cup": [0.30, 0.65, 0.90],
    "lamp": [0.95, 0.35, 0.30],
    "glow": [1.00, 0.95, 0.70],
    "mousepad": [0.32, 0.55, 0.72],
    "steel": [0.70, 0.72, 0.78],
    "tape": [0.95, 0.62, 0.25],
    "stapler": [0.82, 0.22, 0.25],
    "case": [0.58, 0.42, 0.78],
    "mug": [0.92, 0.93, 0.97],
    "coffee": [0.36, 0.22, 0.14],
    "calc": [0.28, 0.30, 0.36],
    "screen": [0.55, 0.85, 0.60],
    "keycap": [0.93, 0.94, 0.97],
    "keycap_dark": [0.30, 0.32, 0.40],
    "key_red": [0.90, 0.35, 0.35],
    "key_blue": [0.30, 0.55, 0.92],
    "key_green": [0.35, 0.75, 0.50],
    "keys_start": [0.85, 0.38, 0.78],
    "cable": [0.16, 0.17, 0.22],
    "enter": [0.96, 0.58, 0.25],
}

# Cover colours cycled over the book staircase.
BOOK_COVERS = ["book", "book_alt", "book_green", "book_purple", "book", "book_alt"]


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


def part(name, size, top_or_center, color, *, center=False, collide=True, touch=False, transparency=0.0, attrs=None, query=True, material="SmoothPlastic"):
    """A block. By default `top_or_center` is (x, top_y, z): the walkable top surface height."""
    x, y, z = top_or_center
    cy = y if center else y - size[1] / 2
    props = {
        "Anchored": True,
        "Size": list(size),
        "CFrame": cframe(x, cy, z),
        "Color": color,
        "Material": material,
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

    def piece(name, length, width, top, color, x0, z=0.0, thickness=2.0, material="SmoothPlastic"):
        """Adds a block that starts at x0 along +X; returns its far edge."""
        geo.append(part(name, (length, thickness, width), (x0 + length / 2, top, z), color, material=material))
        return x0 + length

    def decor(name, size, centre, color, material="SmoothPlastic"):
        """Cosmetic detail: never collides, never touched, never hit by raycasts."""
        geo.append(part(name, size, centre, color, center=True, collide=False, query=False, material=material))

    def book_pages(name, x0, length, width, top, z=0.0, thickness=2.0):
        """Cream page block visible on the front edge of a book."""
        decor(name, (0.4, thickness - 0.6, width - 1.2), (x0 + length + 0.05, top - thickness / 2, z), COLORS["pages"])

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
        x0 = x
        x = piece(f"Book{i + 1}", 10, 16, top, COLORS[BOOK_COVERS[i]], x)
        book_pages(f"Book{i + 1}Pages", x0, 10, 16, top)
    walk0 = x
    x = piece("BookWalkway", 60, 12, top, COLORS["book_purple"], x)
    book_pages("BookWalkwayPages", walk0, 60, 12, top)

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
        p0 = x
        x = piece(f"Pencil{i + 1}", 24, 3, top, COLORS["pencil"], x, material="Plastic")
        # Painted band near the sharpened end and a pink eraser cap on the other.
        decor(f"Pencil{i + 1}Band", (2, 2.1, 3.1), (p0 + 20, top - 1, 0), COLORS["pencil_stripe"])
        decor(f"Pencil{i + 1}Cap", (1.5, 2.1, 3.1), (p0 + 0.75, top - 1, 0), COLORS["eraser"])
    x += 6
    x = checkpoint(2, x, top)

    # Segment 3: ruler bridge, then eraser hops going up and down.
    ruler0 = x
    x = piece("RulerBridge", 90, 4, top, COLORS["ruler"], x, thickness=1.0, material="Plastic")
    # Tick marks along one edge: long every 10, short every 5.
    for tick in range(0, 91, 5):
        long = tick % 10 == 0
        decor(
            f"RulerTick{tick}",
            (0.3, 0.1, 1.4 if long else 0.8),
            (ruler0 + tick, top + 0.05, -1.3 + (0 if long else 0.3)),
            COLORS["ruler_tick"],
        )
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
        x = piece(
            f"Note{i + 1}",
            10,
            10,
            top,
            COLORS["note"] if i % 2 == 0 else COLORS["note_alt"],
            x,
            z=5.0 if i % 2 == 0 else -5.0,
            thickness=1.0,
        )
    x += 5
    x = checkpoint(4, x, top)

    # Segment 5: final climb to the mug (finish).
    for i in range(4):
        top += 3
        x = piece(f"Climb{i + 1}", 10, 14, top, COLORS["book_alt"], x)
    finish_x0 = x
    x = piece("FinishPad", 20, 20, top, COLORS["finish"], x)
    zones.append(zone("FinishZone", "Finish", 5, finish_x0 + 10, top, 0, 18, 18))

    # Results board just past the finish pad, facing the runners. The client draws the table on
    # its Front face (SurfaceGui); this part only carries it.
    board = part("ResultsBoard", (22, 12, 1), (x + 0.5, top + 7, 0), COLORS["board"], center=True)
    board["properties"]["CFrame"]["CFrame"]["orientation"] = YAW_90
    geo.append(board)

    track_length = x - 20
    return geo, zones, spawns, track_length


# --- Keyboard Dash track --------------------------------------------------------------------

KEYS_Z = -140.0  # the track runs along +X at this z; the desk is widened to the north to hold it


def build_keys_track():
    """The second track: over a giant keyboard, along a cable and up the arrow keys.

    Same rules as Desk Dash (zone attributes DashZone/Index, Spawn0..4, 4 checkpoints), built the same
    way. Returns the walkable geometry, zones, spawns, the track length and the zone centres.
    """
    geo = []
    zones = []
    spawns = []
    z0 = KEYS_Z

    def piece(name, length, width, top, color, x0, z=z0, thickness=2.0, material="SmoothPlastic"):
        geo.append(part(name, (length, thickness, width), (x0 + length / 2, top, z), color, material=material))
        return x0 + length

    def spawn_point(name, x, top, z=z0):
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

    # Start pad (magenta), reached by stairs from the desk.
    start_top = 10.0
    for n, (sx, sh) in enumerate(((12, 2.5), (16, 5), (19, 7.5)), start=1):
        width = 4 if n < 3 else 3
        geo.append(part(f"KeyStair{n}", (width, sh, 20), (sx, sh, z0), COLORS["hub"]))
    x = piece("StartPad", 20, 20, start_top, COLORS["keys_start"], 20)
    zones.append(zone("StartZone", "Start", 0, 30, start_top, z0, 18, 18, height=6))
    spawn_point("Spawn0", 30, start_top)

    def checkpoint(index, x0, top_y):
        end = piece(f"Checkpoint{index}Pad", 16, 16, top_y, COLORS["checkpoint"], x0)
        cx = x0 + 8
        zones.append(zone(f"Checkpoint{index}", "Checkpoint", index, cx, top_y, z0, 14, 14))
        spawn_point(f"Spawn{index}", cx, top_y)
        return end

    # Segment 1: a row of keycaps, each one a stud higher.
    top = start_top
    for i in range(8):
        top += 1
        x += 3
        x = piece(f"Key{i + 1}", 10, 10, top, COLORS["keycap"] if i % 2 == 0 else COLORS["keycap_dark"], x, thickness=3.0)
    x += 3
    x = checkpoint(1, x, top)

    # Segment 2: three stretches of cable with gaps (narrow: 3 studs).
    for i in range(3):
        x += 6
        x = piece(f"Cable{i + 1}", 36, 3, top, COLORS["cable"], x, thickness=1.5)
    x += 6
    x = checkpoint(2, x, top)

    # Segment 3: zigzag keys, alternating sides and heights.
    for i in range(8):
        x += 5
        x = piece(
            f"ZigKey{i + 1}",
            9,
            9,
            top + (2 if i % 2 else 0),
            COLORS["key_blue"] if i % 2 == 0 else COLORS["key_red"],
            x,
            z=z0 + (6 if i % 2 == 0 else -6),
            thickness=3.0,
        )
    x += 5
    x = checkpoint(3, x, top)

    # Segment 4: arrow keys climbing up, three studs each.
    for i in range(4):
        top += 3
        x += 4
        x = piece(f"ArrowKey{i + 1}", 9, 9, top, COLORS["keycap_dark"] if i % 2 == 0 else COLORS["keycap"], x, thickness=3.0)
    x += 4
    x = checkpoint(4, x, top)

    # Segment 5: three wide steps up to the Enter key (finish).
    for i in range(3):
        top += 2
        x += 3
        x = piece(f"EnterStep{i + 1}", 10, 12, top, COLORS["key_green"], x)
    x += 3
    finish_x0 = x
    x = piece("FinishPad", 20, 20, top, COLORS["enter"], x)
    zones.append(zone("FinishZone", "Finish", 5, finish_x0 + 10, top, z0, 18, 18))

    board = part("ResultsBoard", (22, 12, 1), (x + 0.5, top + 7, z0), COLORS["board"], center=True)
    board["properties"]["CFrame"]["CFrame"]["orientation"] = YAW_90
    geo.append(board)

    spawns.append(
        {
            "name": "ReturnPoint",
            "className": "Part",
            "properties": {
                "Anchored": True,
                "Size": [2, 1, 2],
                "CFrame": cframe(2, 4.5, z0),
                "Transparency": 1.0,
                "CanCollide": False,
                "CanTouch": False,
                "CanQuery": False,
            },
        }
    )
    return geo, zones, spawns, x - 20


# --- Hub and club plots ----------------------------------------------------------------

PLOT_POSITIONS = [(-25, -40), (-55, -40), (-85, -40), (-25, 40), (-55, 40), (-85, 40)]
PLOT_TOP = 1.5


def build_hub():
    children = [
        # Desk top: hub floor and the ground under the track. Top surface at y = 1.
        part("DeskTop", (820, 4, 270), (300, 1, -45), COLORS["desk"], material="WoodPlanks"),
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
    """Club upgrade models, authored relative to the plot centre at the origin (top surface y = 0).

    The plot is 24 x 24 (x, z in -12..12). One model per upgrade, named by Economy.Upgrades[i].Id.
    Layout: banner back edge, trophy shelf behind the middle, ruler on the left edge, books on the
    right, benches in the middle, pencil fence along the front, lamp back-left, pencil cup front-right.
    """

    def block(name, size, x, y0, z, color, material="SmoothPlastic", collide=True):
        """A block standing on y0 (its bottom), centred on x/z."""
        return part(name, size, (x, y0 + size[1] / 2, z), color, center=True, collide=collide, material=material)

    sticky_banner = model(
        "sticky_banner",
        [
            part("PostLeft", (0.6, 8, 0.6), (-4, 8, -10), COLORS["post"]),
            part("PostRight", (0.6, 8, 0.6), (4, 8, -10), COLORS["post"]),
            part("Banner", (8, 3, 0.3), (0, 7.5, -10), COLORS["banner"], center=True),
        ],
    )

    # 2. Pencil fence: upright pencils with sharpened tips along the front edge.
    palette = ["pencil", "book", "book_alt", "book_green"]
    fence = []
    for i in range(12):
        x = -11 + i * 2
        color = COLORS[palette[i % 4]]
        fence.append(block(f"Pencil{i + 1}", (1.2, 4, 1.2), x, 0, 11, color))
        fence.append(block(f"Tip{i + 1}", (0.8, 0.9, 0.8), x, 4, 11, COLORS["wood"]))
        fence.append(block(f"Lead{i + 1}", (0.3, 0.5, 0.3), x, 4.9, 11, COLORS["dark"], collide=False))
    pencil_fence = model("pencil_fence", fence)

    # 3. Eraser benches: two pink erasers in a blue paper sleeve.
    benches = []
    for n, x in enumerate((-5, 4), start=1):
        benches.append(block(f"Eraser{n}", (5, 1.8, 2.6), x, 0, 4, COLORS["eraser"]))
        benches.append(block(f"Sleeve{n}", (2.2, 1.9, 2.7), x, 0, 4, COLORS["book_alt"]))
    eraser_benches = model("eraser_benches", benches)

    # 4. Book stand: a stack of books with a winner's flag on top.
    stand = [
        block("BookBottom", (5.2, 1.4, 4.6), 9.5, 0, -5, COLORS["book"]),
        block("PagesBottom", (0.3, 1.0, 4.0), 12.0, 0.2, -5, COLORS["pages"], collide=False),
        block("BookMiddle", (4.6, 1.4, 4.1), 9.5, 1.4, -5, COLORS["book_alt"]),
        block("BookTop", (4.0, 1.4, 3.6), 9.5, 2.8, -5, COLORS["book_green"]),
        block("FlagPole", (0.25, 4, 0.25), 9.5, 4.2, -5, COLORS["post"], collide=False),
        block("Flag", (2.2, 1.3, 0.15), 10.6, 6.9, -5, COLORS["finish"], collide=False),
    ]
    book_stand = model("book_stand", stand)

    # 5. Ruler scoreboard: a tall ruler on the left edge with tick marks and a dark score panel.
    ruler = [block("Ruler", (1, 10, 6), -11, 0, 0, COLORS["ruler"], material="Plastic")]
    for tick in range(10):
        long = tick % 5 == 0
        ruler.append(
            block(f"Tick{tick}", (0.2, 0.18, 2.4 if long else 1.4), -10.45, 0.6 + tick, 1.8, COLORS["ruler_tick"], collide=False)
        )
    ruler.append(block("Panel", (0.4, 3.6, 5), -10.2, 6.2, 0, COLORS["board"], collide=False))
    for n, color in enumerate(("gold", "silver", "bronze")):
        ruler.append(block(f"Bar{n + 1}", (0.2, 0.7, 4.2 - n * 0.9), -9.95, 8.4 - n * 1.0, 0, COLORS[color], collide=False))
    ruler_scoreboard = model("ruler_scoreboard", ruler)

    # 6. Paperclip trophy rack: a wooden shelf with gold, silver and bronze trophies.
    rack = [
        block("ShelfLegLeft", (0.8, 3, 1.6), -4.2, 0, -6, COLORS["wood"]),
        block("ShelfLegRight", (0.8, 3, 1.6), 4.2, 0, -6, COLORS["wood"]),
        block("Shelf", (10, 0.6, 2.2), 0, 3, -6, COLORS["wood"], material="Wood"),
    ]
    for n, (x, color) in enumerate(((-3, "gold"), (0, "silver"), (3, "bronze")), start=1):
        rack.append(block(f"TrophyBase{n}", (1.6, 0.4, 1.6), x, 3.6, -6, COLORS["dark"], collide=False))
        rack.append(block(f"TrophyStem{n}", (0.4, 1.4, 0.4), x, 4.0, -6, COLORS[color], material="Metal", collide=False))
        rack.append(block(f"TrophyCup{n}", (1.6, 1.2, 1.6), x, 5.4, -6, COLORS[color], material="Metal", collide=False))
    paperclip_trophies = model("paperclip_trophies", rack)

    # 7. Desk lamp floodlight: a real warm spotlight over the plot.
    head = block("LampHead", (3.2, 1.4, 2.6), -7.8, 8.2, -8, COLORS["lamp"])
    lens = block("LampLens", (2.6, 0.2, 2.0), -7.8, 8.0, -8, COLORS["glow"], material="Neon", collide=False)
    lens["children"] = [
        {
            "name": "Floodlight",
            "className": "SpotLight",
            "properties": {
                "Brightness": 3,
                "Range": 34,
                "Angle": 75,
                "Face": "Bottom",
                "Color": [1.0, 0.9, 0.7],
                "Shadows": False,
            },
        }
    ]
    lamp = [
        block("LampBase", (3.4, 0.6, 3.4), -9.5, 0, -8, COLORS["dark"]),
        block("LampArm", (0.5, 7.8, 0.5), -9.5, 0.6, -8, COLORS["dark"]),
        block("LampBrace", (2.2, 0.5, 0.5), -8.7, 8.0, -8, COLORS["dark"], collide=False),
        head,
        lens,
    ]
    lamp_floodlight = model("lamp_floodlight", lamp)

    # 8. Pencil cup tower: a blue cup bristling with tall pencils and a golden flag.
    cup = [block("Cup", (5, 5, 5), 9, 0, 7.5, COLORS["cup"]), block("CupRim", (5.4, 0.6, 5.4), 9, 5, 7.5, COLORS["silver"])]
    heights = (8.5, 11, 9.5, 12, 10, 8, 10.5)
    spots = ((7.4, 6.0), (10.6, 6.0), (7.4, 9.0), (10.6, 9.0), (9.0, 7.5), (8.2, 7.5), (9.8, 7.5))
    for n, ((x, z), h) in enumerate(zip(spots, heights), start=1):
        cup.append(block(f"CupPencil{n}", (0.9, h, 0.9), x, 5.2, z, COLORS[palette[n % 4]], collide=False))
        cup.append(block(f"CupTip{n}", (0.6, 0.8, 0.6), x, 5.2 + h, z, COLORS["wood"], collide=False))
    cup.append(block("TowerFlagPole", (0.2, 2.5, 0.2), 9.0, 17.4, 7.5, COLORS["post"], collide=False))
    cup.append(block("TowerFlag", (2.4, 1.4, 0.15), 10.2, 18.6, 7.5, COLORS["gold"], collide=False))
    pencil_cup_tower = model("pencil_cup_tower", cup)

    return model(
        "ClubUpgrades",
        [
            sticky_banner,
            pencil_fence,
            eraser_benches,
            book_stand,
            ruler_scoreboard,
            paperclip_trophies,
            lamp_floodlight,
            pencil_cup_tower,
        ],
        "Folder",
    )


# --- Scenery and bounds -------------------------------------------------------------------

DESK_TOP_Y = 1.0  # top surface of the desk


def prop_block(name, size, x, y0, z, color, material="SmoothPlastic", collide=True):
    """A block standing on y0 (its bottom edge), centred on x/z."""
    return part(name, size, (x, y0 + size[1] / 2, z), color, center=True, collide=collide, material=material)


def prop_cylinder(name, diameter, length, x, y0, z, color, material="SmoothPlastic", collide=True, upright=True):
    """A cylinder. Upright: stands on y0 with `length` as its height. Otherwise it lies along X."""
    height = length if upright else diameter
    p = part(name, (length, diameter, diameter), (x, y0 + height / 2, z), color, center=True, collide=collide, material=material)
    if upright:
        p["properties"]["CFrame"]["CFrame"]["orientation"] = ROLL_90
    p["properties"]["Shape"] = "Cylinder"
    return p


def build_scenery():
    """Giant everyday objects around the track so the desk does not feel empty.

    Everything sits at |z| >= 28 (or behind the hub), clear of the track (|z| <= 12), the plots and
    the stairs. Props are solid, so players can climb on them; none is needed for the game.
    """
    y = DESK_TOP_Y
    out = []

    # Mouse pad under the hub: a dark soft floor that makes the start area read as home.
    out.append(prop_block("MousePad", (172, 0.4, 170), -24, y, 0, COLORS["mousepad"], material="Fabric", collide=False))

    # Coffee mug (back row).
    mug = [
        prop_cylinder("MugBody", 28, 32, 120, y, -58, COLORS["mug"]),
        prop_cylinder("MugCoffee", 23, 0.6, 120, y + 29.6, -58, COLORS["coffee"], collide=False),
        prop_block("MugHandleTop", (7, 3, 4), 136.5, y + 24, -58, COLORS["mug"]),
        prop_block("MugHandleSide", (3, 16, 4), 140, y + 11, -58, COLORS["mug"]),
        prop_block("MugHandleBottom", (7, 3, 4), 136.5, y + 8, -58, COLORS["mug"]),
    ]
    out.append(model("Mug", mug))

    # Notebook stack with page edges.
    notebooks = []
    for i, color in enumerate(("book", "book_alt", "book_green", "book_purple")):
        width = 62 - i * 3
        notebooks.append(prop_block(f"Notebook{i + 1}", (width, 4, 44), 250 + i * 1.5, y + i * 4, 56, COLORS[color]))
        notebooks.append(
            prop_block(f"Pages{i + 1}", (0.4, 3, 40), 250 + i * 1.5 + width / 2, y + i * 4 + 0.5, 56, COLORS["pages"], collide=False)
        )
    out.append(model("Notebooks", notebooks))

    # Sticky note pads.
    pads = []
    for i, (color, dx, dz) in enumerate((("note", 0, 0), ("note_alt", 30, 8), ("eraser", -26, 12))):
        pads.append(prop_block(f"Pad{i + 1}", (22, 6, 22), 335 + dx, y, 62 + dz, COLORS[color]))
        pads.append(prop_block(f"PadTop{i + 1}", (22, 0.2, 22), 335 + dx, y + 6, 62 + dz, COLORS["note"], collide=False))
    out.append(model("StickyPads", pads))

    # Tape roll lying on its side.
    tape = [
        prop_cylinder("TapeRing", 36, 16, 405, y, -58, COLORS["tape"], upright=False),
        prop_cylinder("TapeHole", 14, 16.4, 405, y + 11, -58, COLORS["desk"], collide=False, upright=False),
    ]
    out.append(model("TapeRoll", tape))

    # Stapler.
    stapler = [
        prop_block("StaplerBase", (38, 3, 12), 470, y, 58, COLORS["steel"], material="Metal"),
        prop_block("StaplerBody", (36, 6, 11), 470, y + 3, 58, COLORS["stapler"]),
        prop_block("StaplerHead", (14, 3, 11), 482, y + 9, 58, COLORS["dark"]),
    ]
    out.append(model("Stapler", stapler))

    # Calculator with a screen and a grid of keys.
    calc = [
        prop_block("CalcBody", (36, 5, 50), 530, y, -56, COLORS["calc"]),
        prop_block("CalcScreen", (30, 0.4, 10), 530, y + 5, -70, COLORS["screen"], material="Neon", collide=False),
    ]
    palette = ("book", "pencil", "book_alt", "book_green")
    for row in range(4):
        for col in range(4):
            calc.append(
                prop_block(
                    f"Key{row}{col}",
                    (6, 1, 6),
                    530 - 10.5 + col * 7,
                    y + 5,
                    -62 + row * 8 + 2,
                    COLORS[palette[(row + col) % 4]],
                    collide=False,
                )
            )
    out.append(model("Calculator", calc))

    # Zipped pencil case.
    case = [
        prop_block("CaseBody", (76, 14, 28), 600, y, 58, COLORS["case"], material="Fabric"),
        prop_block("CaseZip", (76, 0.5, 1.8), 600, y + 14, 58, COLORS["steel"], material="Metal", collide=False),
        prop_block("CaseTab", (4, 1.2, 4), 630, y + 14, 58, COLORS["gold"], collide=False),
    ]
    out.append(model("PencilCase", case))

    # Big reading lamp in the back with a real warm glow.
    bulb = prop_block("LampBulb", (14, 2, 14), 300, y + 64, -78, COLORS["glow"], material="Neon", collide=False)
    bulb["children"] = [
        {
            "name": "LampGlow",
            "className": "PointLight",
            "properties": {"Brightness": 1.6, "Range": 150, "Color": [1.0, 0.86, 0.62], "Shadows": False},
        }
    ]
    lamp = [
        prop_cylinder("LampBase", 36, 3, 300, y, -78, COLORS["dark"]),
        prop_block("LampArm", (3, 62, 3), 300, y + 3, -78, COLORS["dark"]),
        prop_block("ShadeBottom", (34, 6, 34), 300, y + 65, -78, COLORS["lamp"]),
        prop_block("ShadeMiddle", (26, 6, 26), 300, y + 71, -78, COLORS["lamp"]),
        prop_block("ShadeTop", (16, 6, 16), 300, y + 77, -78, COLORS["lamp"]),
        bulb,
    ]
    out.append(model("ReadingLamp", lamp))

    # Rulers lying along the front edge, tick marks every 20 studs.
    for n, (x0, color) in enumerate(((60, "ruler"), (330, "pencil")), start=1):
        ruler = [prop_block(f"Ruler{n}", (240, 1.2, 12), x0 + 120, y, 82, COLORS[color], material="Plastic")]
        for tick in range(0, 241, 20):
            ruler.append(
                prop_block(
                    f"Tick{n}_{tick}", (0.6, 0.2, 5 if tick % 40 == 0 else 3), x0 + tick, y + 1.2, 79, COLORS["ruler_tick"], collide=False
                )
            )
        out.append(model(f"Ruler{n}", ruler))

    # Hub props: a giant pen, erasers and thumbtacks around the start area (plots sit at |z| 28..52).
    pen = [
        prop_cylinder("PenBarrel", 9, 78, -40, y, 72, COLORS["cup"], upright=False),
        prop_cylinder("PenGrip", 9.4, 14, -75, y, 72, COLORS["dark"], upright=False),
        prop_cylinder("PenCap", 10, 18, -1, y, 72, COLORS["silver"], material="Metal", upright=False),
        prop_block("PenClip", (16, 1.2, 2), 4, y + 9.4, 72, COLORS["steel"], material="Metal", collide=False),
    ]
    out.append(model("Pen", pen))
    erasers = []
    for i, (color, dx, dz, w) in enumerate((("eraser", 0, 0, 16), ("pages", 20, 6, 14), ("book_alt", 9, 22, 12))):
        erasers.append(prop_block(f"HubEraser{i + 1}", (w, 9, 11), -70 + dx, y, -68 + dz, COLORS[color]))
        erasers.append(prop_block(f"HubSleeve{i + 1}", (w / 2.5, 9.2, 11.2), -70 + dx, y, -68 + dz, COLORS["dark"], collide=False))
    out.append(model("HubErasers", erasers))
    tacks = []
    for i, (color, x, z) in enumerate((("book", -20, -70), ("pencil", -5, -78), ("book_green", 15, -66), ("book_purple", 35, -76))):
        tacks.append(prop_cylinder(f"TackHead{i + 1}", 12, 3, x, y, z, COLORS[color]))
        tacks.append(prop_cylinder(f"TackTop{i + 1}", 6, 4, x, y + 3, z, COLORS[color]))
        tacks.append(prop_cylinder(f"TackPin{i + 1}", 1.6, 6, x, y + 7, z, COLORS["steel"], material="Metal", collide=False))
    out.append(model("Thumbtacks", tacks))

    # Guide to the Keyboard Dash start: a trail of magenta tiles along the desk, and a tall glowing
    # beacon over each start pad so both tracks can be found from the hub.
    trail = []
    for i in range(14):
        trail.append(prop_block(f"Tile{i + 1}", (6, 0.3, 6), 6, y, -16 - i * 9, COLORS["keys_start"], material="Neon", collide=False))
    out.append(model("KeysTrail", trail))
    for name, x, z, color in (("DeskBeacon", 30, 16, "start"), ("KeysBeacon", 30, -126, "keys_start")):
        out.append(model(name, [prop_block("Pillar", (3, 36, 3), x, 10, z, COLORS[color], material="Neon", collide=False)]))

    return out


def build_bounds():
    """Invisible walls round the desk so nobody walks off it; the east end lies past the finish."""

    def wall(name, size, x, z):
        return part(name, size, (x, 100, z), [1, 1, 1], center=True, collide=True, transparency=1.0, query=False)

    return [
        wall("WallWest", (2, 200, 274), -111, -45),
        wall("WallEast", (2, 200, 274), 711, -45),
        wall("WallNorth", (824, 200, 2), 300, -181),
        wall("WallSouth", (824, 200, 2), 300, 91),
    ]


def main():
    geo, zones, spawns, length = build_track()
    key_geo, key_zones, key_spawns, key_length = build_keys_track()
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
            ),
            model(
                "KeyDash",
                [
                    folder("Geometry", key_geo),
                    folder("Zones", key_zones),
                    folder("Spawns", key_spawns),
                ],
            ),
            folder("Scenery", build_scenery()),
            folder("Bounds", build_bounds()),
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
    print(f"keys track length ~{key_length:.0f} studs, {len(key_geo)} pieces, {len(key_zones)} zones")


if __name__ == "__main__":
    main()
