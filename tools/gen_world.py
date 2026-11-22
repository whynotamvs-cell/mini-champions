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


# --- Hub and club plots ----------------------------------------------------------------

PLOT_POSITIONS = [(-25, -40), (-55, -40), (-85, -40), (-25, 40), (-55, 40), (-85, 40)]
PLOT_TOP = 1.5


def build_hub():
    children = [
        # Desk top: hub floor and the ground under the track. Top surface at y = 1.
        part("DeskTop", (760, 4, 180), (270, 1, 0), COLORS["desk"], material="WoodPlanks"),
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
