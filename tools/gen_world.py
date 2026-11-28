#!/usr/bin/env python3
"""Generates the Desk World (one closed square room: hub, two tracks, props) as Rojo model files.

    python3 tools/gen_world.py

Writes:
    world/DeskWorld.model.json     -> Workspace.DeskWorld (hub, plots, Desk Dash track and zones)
    world/ClubUpgrades.model.json  -> ServerStorage.ClubUpgrades (upgrade placeholder models)

Stage 1 placeholders only: primitives, no art. Edit this script, not the JSON, then re-run it.
Units are studs. Y is up; the track runs along +X from the hub.
"""

import json
import math
import os
import random

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
    "ceiling": [0.96, 0.92, 0.82],
    "wall": [0.78, 0.60, 0.40],
    "baseboard": [0.50, 0.36, 0.24],
    "stripe": [0.95, 0.78, 0.40],
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



DESK_TOP_Y = 1.0


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



# --- The room ------------------------------------------------------------------------------
#
# One closed square room (a giant desk drawer): walls and a ceiling with lamps, the hub with the
# club plots along the west wall, and both tracks winding through the middle as snakes. Every
# free corner is filled with giant stationery. Axes: x east, z south, y up. Units are studs.
#
#   room inner area   x, z in [-200, 200], floor top y = 1, ceiling at y = 151
#   hub               x < -100 (west), rug on the floor, spawn at (-150, 0)
#   Desk Dash         north half (z < 0), start pad at (-70, -40)
#   Keyboard Dash     south half (z > 0), start pad at (-70, 40)

import math
import random

ROOM = 200  # half size of the inner room
FLOOR_Y = 1.0
WALL_H = 260
CEILING_Y = FLOOR_Y + WALL_H

# Playability limits (R15: JumpHeight 7.2, WalkSpeed 16). For two neighbouring pieces of a track,
# plan-view distance + 1.5 * rise must stay within JUMP_BUDGET, and the rise within MAX_RISE. A level
# jump of 8 studs is near the physical limit (16 studs/s * 0.54 s air time = 8.7), so the hardest
# jumps need a clean run-up and a late takeoff; most are easier.
MAX_RISE = 3.5
MAX_GAP = 7.8
JUMP_BUDGET = 11.0
SUPPORT_MAX_TOP = 60.0  # higher pieces float (no stilts), a sky course above the desk
EDGE = 4.0  # props keep this clear of walls

HEADINGS = {"E": (1, 0), "W": (-1, 0), "N": (0, -1), "S": (0, 1)}
# Board rotations: the Front face (where the SurfaceGui is) must look back at the runners.
FACE_PLUS_X = [[0, 0, -1], [0, 1, 0], [1, 0, 0]]  # yaw -90
FACE_MINUS_X = YAW_90  # yaw +90


def rect_distance(a, b):
    """Plan-view distance between two rectangles (x0, x1, z0, z1)."""
    dx = max(a[0] - b[1], b[0] - a[1], 0)
    dz = max(a[2] - b[3], b[2] - a[3], 0)
    return math.hypot(dx, dz)


LATERAL_MARGIN = 0.8
LAND_MARGIN = 0.6


def shrink(rect, along, across, horizontal):
    """A rectangle (x0, x1, z0, z1) pulled in by `along` on the heading axis and `across` on the other."""
    dx, dz = (along, across) if horizontal else (across, along)
    x0, x1, z0, z1 = rect
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    return (min(x0 + dx, cx), max(x1 - dx, cx), min(z0 + dz, cz), max(z1 - dz, cz))


def rects_overlap(a, b, margin=0.0):
    return not (
        a[1] + margin <= b[0] or b[1] + margin <= a[0] or a[3] + margin <= b[2] or b[3] + margin <= a[2]
    )


def shade(color, factor):
    return [round(min(1.0, c * factor), 3) for c in color]


class TrackBuilder:
    """Lays a track piece by piece along a heading, turning at pads, and checks every jump."""

    def __init__(self, label):
        self.label = label
        self.geo = []
        self.zones = []
        self.spawns = []
        self.hazards = []  # timed obstacles: Hazards folder, parameters in attributes
        self.path = []  # waypoints (x, top, z) of every piece, in running order
        self.marks = {}  # zone index -> waypoint index
        self.rects = []  # footprints of every piece (for the prop placer)
        self.h = (1, 0)
        self.cx = 0.0
        self.cz = 0.0
        self.last = None  # (rect, top, name)
        self.pad_center = (0.0, 0.0)
        self.pad_size = 0.0

    # -- internals
    def _check(self, name, rect, top):
        if self.last is None:
            return
        prect, ptop, pname = self.last
        # The character's centre must take off from inside the old piece and land inside the new one,
        # so across the heading both pieces count as LATERAL_MARGIN narrower on each side, and the
        # landing piece LAND_MARGIN shorter along the heading (a real jump cannot land on the very edge).
        horizontal = self.h[0] != 0
        gap = rect_distance(shrink(prect, 0.0, LATERAL_MARGIN, horizontal), shrink(rect, LAND_MARGIN, LATERAL_MARGIN, horizontal))
        rise = top - ptop
        assert gap <= MAX_GAP, f"{self.label}: {pname} -> {name}: gap {gap:.1f} > {MAX_GAP}"
        assert rise <= MAX_RISE, f"{self.label}: {pname} -> {name}: rise {rise:.1f} > {MAX_RISE}"
        need = gap + 1.5 * max(rise, 0)
        assert need <= JUMP_BUDGET, f"{self.label}: {pname} -> {name}: jump {need:.1f} > {JUMP_BUDGET}"

    def _decorate(self, name, cx, cz, sx, sz, top, thick, color):
        """Cosmetic details on and under a piece (never collide, never hit by raycasts): a support
        column to the floor, and themed marks (page edges, pencil bands, keycap plates, ...)."""

        def deco(label, size, x, y, z, col, material="SmoothPlastic"):
            self.geo.append(part(f"{name}_{label}", size, (x, y, z), col, center=True, collide=False, query=False, material=material))

        base = name.rstrip("0123456789")
        along_x = sx >= sz
        surface = top  # top surface of the piece
        mid = top - thick / 2  # centre height of the piece body

        # Support column: a stack / stilt under the platform, so nothing floats in the air.
        height = top - thick - FLOOR_Y
        if height > 1 and top < SUPPORT_MAX_TOP:
            if self.label == "keys":
                col = COLORS["keycap_dark"] if base in ("Key", "ZigKey", "ArrowKey") else shade(COLORS["dark"], 1.2)
            else:
                col = shade(color, 0.55)
            width_x = max(1.0, min(sx * 0.6, 8.0)) if sx > 3.5 else 1.2
            width_z = max(1.0, min(sz * 0.6, 8.0)) if sz > 3.5 else 1.2
            deco("Support", (width_x, height, width_z), cx, FLOOR_Y + height / 2, cz, col)

        long_len = max(sx, sz)

        if base in ("Book", "BookWalkway", "Climb"):
            # cream page edges along both long sides and a darker title band on the cover
            if along_x:
                deco("PagesA", (sx * 0.96, thick * 0.5, 0.5), cx, mid, cz + sz / 2 - 0.1, COLORS["pages"])
                deco("PagesB", (sx * 0.96, thick * 0.5, 0.5), cx, mid, cz - sz / 2 + 0.1, COLORS["pages"])
                deco("Band", (sx * 0.8, 0.15, 1.6), cx, surface + 0.08, cz, shade(color, 0.7))
            else:
                deco("PagesA", (0.5, thick * 0.5, sz * 0.96), cx + sx / 2 - 0.1, mid, cz, COLORS["pages"])
                deco("PagesB", (0.5, thick * 0.5, sz * 0.96), cx - sx / 2 + 0.1, mid, cz, COLORS["pages"])
                deco("Band", (1.6, 0.15, sz * 0.8), cx, surface + 0.08, cz, shade(color, 0.7))
        elif base == "Pencil":
            deco("Ferrule", (2.2, thick + 0.2, sz + 0.2), cx + sx / 2 - 5, mid, cz, COLORS["steel"], "Metal")
            deco("Cap", (3.0, thick + 0.2, sz + 0.2), cx - sx / 2 + 1.5, mid, cz, COLORS["eraser"])
            deco("Stripe", (long_len * 0.4, 0.12, 0.6), cx - 2, surface + 0.06, cz, COLORS["pencil_stripe"])
        elif base == "Eraser":
            deco("Sleeve", (sx * 0.42, thick + 0.2, sz + 0.2), cx, mid, cz, COLORS["dark"])
        elif base == "RulerBridge":
            for k in range(int(long_len / 4)):
                off = -long_len / 2 + 2 + k * 4
                tick = (0.3, 0.12, 1.0) if along_x else (1.0, 0.12, 0.3)
                if along_x:
                    deco(f"Tick{k}", tick, cx + off, surface + 0.06, cz - sz / 2 + 0.7, COLORS["ruler_tick"])
                else:
                    deco(f"Tick{k}", tick, cx - sx / 2 + 0.7, surface + 0.06, cz + off, COLORS["ruler_tick"])
        elif base == "Note":
            deco("Glue", (sx, 0.14, 2.2), cx, surface + 0.07, cz - sz / 2 + 1.1, shade(color, 0.8))
            deco("ScribbleA", (sx * 0.6, 0.12, 0.35), cx, surface + 0.06, cz + 0.5, COLORS["dark"])
            deco("ScribbleB", (sx * 0.45, 0.12, 0.35), cx - 1, surface + 0.06, cz + 2.3, COLORS["dark"])
        elif base == "StartPad":
            for k in (-5, 0, 5):
                deco(f"Chevron{k}", (1.4, 0.14, 11), cx + k, surface + 0.07, cz, COLORS["pages"])
        elif base == "FinishPad":
            for i in range(5):
                for j in range(5):
                    if (i + j) % 2 == 0:
                        deco(f"Check{i}{j}", (3.6, 0.14, 3.6), cx - 7.2 + i * 3.6, surface + 0.07, cz - 7.2 + j * 3.6, COLORS["dark"])
        elif base.startswith("Checkpoint") and base.endswith("Pad"):
            for fx, fz in ((-5.5, -5.5), (5.5, 5.5)):
                deco(f"Pole{fx}", (0.5, 7, 0.5), cx + fx, surface + 3.5, cz + fz, COLORS["post"])
                deco(f"Flag{fx}", (3, 2, 0.2), cx + fx + 1.5, surface + 6, cz + fz, COLORS["key_green"])
        elif base in ("Key", "ZigKey", "ArrowKey"):
            plate = shade(color, 1.1 if color[0] < 0.9 else 0.96)
            deco("Plate", (sx - 2.4, 0.25, sz - 2.4), cx, surface + 0.12, cz, plate)
            deco("LegendStem", (0.8, 0.14, 3.4), cx, surface + 0.32, cz, COLORS["dark"] if color[0] > 0.6 else COLORS["pages"])
            deco("LegendBar", (3.2, 0.14, 0.8), cx, surface + 0.32, cz - 1.4, COLORS["dark"] if color[0] > 0.6 else COLORS["pages"])
        elif base == "Cable":
            plug_long = (3.0, thick + 1.0, 3.8) if along_x else (3.8, thick + 1.0, 3.0)
            for sign in (-1, 1):
                if along_x:
                    deco(f"Plug{sign}", plug_long, cx + sign * (sx / 2 - 1.5), mid, cz, COLORS["steel"], "Metal")
                else:
                    deco(f"Plug{sign}", plug_long, cx, mid, cz + sign * (sz / 2 - 1.5), COLORS["steel"], "Metal")
            for k in range(1, 3):
                if along_x:
                    deco(f"Clip{k}", (1.2, thick + 0.5, 3.8), cx - sx / 2 + k * sx / 3, mid, cz, shade(COLORS["cable"], 2.4))
                else:
                    deco(f"Clip{k}", (3.8, thick + 0.5, 1.2), cx, mid, cz - sz / 2 + k * sz / 3, shade(COLORS["cable"], 2.4))
        elif base == "EnterStep":
            deco("EnterBar", (6, 0.14, 0.8), cx, surface + 0.07, cz + 1, COLORS["pages"])
            deco("EnterDrop", (0.8, 0.14, 3.2), cx + 2.6, surface + 0.07, cz - 0.4, COLORS["pages"])

    def _spawn(self, name, x, top, z):
        self.spawns.append(
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

    def _place(self, name, size_x, size_z, cx, cz, top, color, thickness, material):
        self.geo.append(part(name, (size_x, thickness, size_z), (cx, top, cz), color, material=material))
        rect = (cx - size_x / 2, cx + size_x / 2, cz - size_z / 2, cz + size_z / 2)
        self._check(name, rect, top)
        self.last = (rect, top, name)
        self.rects.append(rect)
        self.path.append((cx, top, cz))
        self._decorate(name, cx, cz, size_x, size_z, top, thickness, color)
        return len(self.path) - 1

    # -- public
    def start_pad(self, center, heading, top, color, size=20):
        self.h = HEADINGS[heading]
        cx, cz = center
        self._place("StartPad", size, size, cx, cz, top, color, 2.0, "SmoothPlastic")
        self.zones.append(zone("StartZone", "Start", 0, cx, top, cz, size - 2, size - 2, height=6))
        self._spawn("Spawn0", cx, top, cz)
        self.marks[0] = len(self.path) - 1
        self.pad_center = (cx, cz)
        self.pad_size = size
        self.arch(cx, cz, top, "StartArch", color, half=size / 2 - 1, height=15, trim=COLORS["glow"])
        self.cx = cx + self.h[0] * size / 2
        self.cz = cz + self.h[1] * size / 2

    def piece(self, name, length, width, top, color, *, gap=0.0, lateral=0.0, thickness=2.0, material="SmoothPlastic"):
        hx, hz = self.h
        sx = self.cx + hx * gap
        sz = self.cz + hz * gap
        cx = sx + hx * length / 2 - hz * lateral
        cz = sz + hz * length / 2 + hx * lateral
        size_x, size_z = (length, width) if hx else (width, length)
        self._place(name, size_x, size_z, cx, cz, top, color, thickness, material)
        self.cx = sx + hx * length
        self.cz = sz + hz * length

    def pad(self, index, top, color, *, size=16, gap=0.0, kind="Checkpoint", name=None, height=8):
        hx, hz = self.h
        label = name or f"Checkpoint{index}Pad"
        self.piece(label, size, size, top, color, gap=gap)
        cx = self.cx - hx * size / 2
        cz = self.cz - hz * size / 2
        if kind == "Checkpoint":
            self.zones.append(zone(f"Checkpoint{index}", kind, index, cx, top, cz, size - 2, size - 2, height=height))
            self._spawn(f"Spawn{index}", cx, top, cz)
        else:
            self.zones.append(zone("FinishZone", kind, index, cx, top, cz, size - 2, size - 2, height=height))
        self.marks[index] = len(self.path) - 1
        self.pad_center = (cx, cz)
        self.pad_size = size
        if kind == "Checkpoint":
            self.arch(cx, cz, top, f"CheckpointArch{index}", color, half=size / 2 - 1, height=11, trim=COLORS["checkpoint"])
        else:
            self.arch(cx, cz, top, "FinishArch", COLORS["finish"], half=size / 2 - 1, height=17, trim=COLORS["glow"], checker=True)

    def turn(self, heading):
        self.h = HEADINGS[heading]
        px, pz = self.pad_center
        self.cx = px + self.h[0] * self.pad_size / 2
        self.cz = pz + self.h[1] * self.pad_size / 2

    def landing(self, top, color, *, size=14, gap=0.0, name="Landing"):
        """A rest pad at a corner: not a checkpoint, only room to turn."""
        hx, hz = self.h
        self.piece(name, size, size, top, color, gap=gap)
        self.pad_center = (self.cx - hx * size / 2, self.cz - hz * size / 2)
        self.pad_size = size

    def laser(self, top, *, period=3.0, on=1.2, phase=0.0, height=2.6, along=0.0):
        """A pulsing laser beam across the last piece (the whole width, so it cannot be walked around).
        Jump over it or cross while it is off. The server tests the hit, the client animates it."""
        rect, _, pname = self.last
        cx, cz = (rect[0] + rect[1]) / 2, (rect[2] + rect[3]) / 2
        wx, wz = rect[1] - rect[0], rect[3] - rect[2]
        hx, hz = self.h
        cx += hx * along
        cz += hz * along
        # across the heading: the beam is as wide as the piece plus a little
        size = (0.7, height, wz + 1.0) if hx else (wx + 1.0, height, 0.7)
        self.hazards.append(
            part(
                f"Laser{len(self.hazards) + 1}",
                size,
                (cx, top + 0.6 + height / 2, cz),
                [1.0, 0.15, 0.2],
                center=True,
                collide=False,
                query=False,
                material="Neon",
                attrs={"HazardKind": "Laser", "Period": period, "OnSec": on, "Phase": phase},
            )
        )
        # emitters on both ends of the beam (decor)
        for sign in (-1, 1):
            ex = cx + (0 if hx else sign * (wx / 2 + 0.9))
            ez = cz + (sign * (wz / 2 + 0.9) if hx else 0)
            self.geo.append(part(f"{pname}_Emitter{len(self.hazards)}_{sign}", (1.2, height + 1.2, 1.2), (ex, top + 0.6 + height / 2, ez), COLORS["dark"], center=True, collide=False, query=False))

    def spinner(self, top, *, length, speed=1.4, phase=0.0, height=2.0, width=1.2):
        """A sweeping bar turning above the centre of the last piece: jump it or time it."""
        rect, _, _ = self.last
        cx, cz = (rect[0] + rect[1]) / 2, (rect[2] + rect[3]) / 2
        self.hazards.append(
            part(
                f"Spinner{len(self.hazards) + 1}",
                (length, height, width),
                (cx, top + 0.6 + height / 2, cz),
                [0.95, 0.35, 0.25],
                center=True,
                collide=False,
                query=False,
                attrs={"HazardKind": "Spinner", "Speed": speed, "Phase": phase},
            )
        )

    def arch(self, cx, cz, top, name, color, *, half=9.0, height=15.0, trim=None, checker=False, glow=True):
        """A gateway over a pad: two pillars and a beam across the heading, neon trim underneath, and
        (optionally) a checkered band. Decor only: nothing collides, so it never blocks a jump."""
        hx, hz = self.h
        trim = trim or COLORS["glow"]
        along_z = hx != 0  # heading along x -> the arch spans z
        width = 1.6

        def block(label, size_across, size_up, size_along, ax, ay, col, material="SmoothPlastic"):
            # ax: offset across the heading, ay: bottom y above the pad top
            ox = hx * 0 if along_z else ax
            oz = ax if along_z else 0
            sx, sy, sz = (size_along, size_up, size_across) if along_z else (size_across, size_up, size_along)
            self.geo.append(part(f"{name}_{label}", (sx, sy, sz), (cx + ox, top + ay + size_up / 2, cz + oz), col, center=True, collide=False, query=False, material=material))

        for sign, side in ((-1, "L"), (1, "R")):
            block(f"Pillar{side}", width, height, width, sign * (half + width / 2), 0, color)
            block(f"Foot{side}", width * 2, 1.0, width * 2, sign * (half + width / 2), 0, shade(color, 0.7))
        span = (half + width) * 2
        block("Beam", span, 2.4, width, 0, height, color)
        if glow:
            block("Trim", span - 1.0, 0.5, width * 0.6, 0, height - 0.5, trim, material="Neon")
        if checker:
            cells = 12
            cell = (span - 1.0) / cells
            for i in range(cells):
                col = [0.08, 0.08, 0.1] if i % 2 == 0 else [0.97, 0.97, 0.97]
                block(f"Check{i + 1}", cell, 1.1, width * 1.05, -span / 2 + 0.5 + cell * (i + 0.5), height + 0.6, col)
        # a small invisible anchor the client dresses with sparkles
        ox, oz = (0, 0)
        self.geo.append(
            part(f"{name}_FxSparkle", (1, 1, 1), (cx + ox, top + height + 1.5, cz + oz), [1, 1, 1], center=True, collide=False, query=False, transparency=1.0, attrs={"FxKind": "Sparkle"})
        )

    def board(self, top, face):
        """Results board just past the finish pad (the track heading), facing the runners."""
        px, pz = self.pad_center
        hx, hz = self.h
        bx = px + hx * (self.pad_size / 2 + 0.5)
        bz = pz + hz * (self.pad_size / 2 + 0.5)
        board = part("ResultsBoard", (22, 12, 1), (bx, top + 7, bz), COLORS["board"], center=True)
        board["properties"]["CFrame"]["CFrame"]["orientation"] = face
        self.geo.append(board)
        self.rects.append((bx - 1, bx + 1, bz - 11, bz + 11))

    def stairs(self, x_edge, z, top):
        """Three steps up to the start pad, west of it (the pad starts at x_edge)."""
        for n, (sx, h) in enumerate(((x_edge - 10, top * 0.25), (x_edge - 6, top * 0.5), (x_edge - 2, top * 0.75)), start=1):
            self.geo.append(part(f"StartStair{n}", (4, h, 20), (sx, h, z), COLORS["hub"]))
            self.rects.append((sx - 2, sx + 2, z - 10, z + 10))

    def segment_lengths(self):
        """Walking distance (plan view) between consecutive zones along the path."""
        out = []
        for i in range(len(self.marks) - 1):
            a, b = self.marks[i], self.marks[i + 1]
            d = 0.0
            for k in range(a, b):
                x0, _, z0 = self.path[k]
                x1, _, z1 = self.path[k + 1]
                d += math.hypot(x1 - x0, z1 - z0)
            out.append(d)
        return out

    def model(self, name, return_point):
        path_json = json.dumps([[round(x, 1), round(y, 1), round(z, 1)] for x, y, z in self.path], separators=(",", ":"))
        self.spawns.append(
            {
                "name": "ReturnPoint",
                "className": "Part",
                "properties": {
                    "Anchored": True,
                    "Size": [2, 1, 2],
                    "CFrame": cframe(return_point[0], 4.5, return_point[1]),
                    "Transparency": 1.0,
                    "CanCollide": False,
                    "CanTouch": False,
                    "CanQuery": False,
                },
            }
        )
        node = model(
            name,
            [folder("Geometry", self.geo), folder("Zones", self.zones), folder("Spawns", self.spawns), folder("Hazards", self.hazards)],
        )
        # The walking path (x, top, z per piece) is kept as an attribute for tools and tests only.
        node["properties"] = attributes({"Path": path_json})
        return node


def build_desk_track():
    """Desk Dash: books, pencils, erasers, a ruler and sticky notes, up to the golden finish."""
    b = TrackBuilder("desk")
    top = 10.0
    b.stairs(-80, -40, top)
    b.start_pad((-70, -40), "E", top, COLORS["start"])

    # Segment 1: five narrow books climbing with small gaps, then a short walkway after a longer jump.
    for i in range(5):
        top += 2
        b.piece(f"Book{i + 1}", 9, 12, top, COLORS[BOOK_COVERS[i]], gap=2)
    b.piece("BookWalkway", 10, 8, top, COLORS["book_purple"], gap=5)
    b.pad(1, top, COLORS["checkpoint"], gap=3)

    # Segment 2: three thin pencils, wide gaps, heights up and down.
    for i, rise in enumerate((0, 2, -2)):
        top += rise
        b.piece(f"Pencil{i + 1}", 20, 2.6, top, COLORS["pencil"], gap=7, material="Plastic")
    b.pad(2, top, COLORS["checkpoint"], gap=7)

    # Segment 3 (north): small eraser hops over wide gaps, rising and dropping.
    b.turn("N")
    for i, rise in enumerate((2, 2, -3, 2)):
        top += rise
        b.piece(f"Eraser{i + 1}", 6, 6, top, COLORS["eraser"], gap=7, thickness=3.0)
    b.pad(3, top, COLORS["checkpoint"], gap=6)

    # Segment 4 (west): a thin ruler, then sticky notes in a zigzag that also changes height.
    b.turn("W")
    b.piece("RulerBridge", 36, 3, top, COLORS["ruler"], thickness=1.0, material="Plastic")
    for i in range(5):
        b.piece(
            f"Note{i + 1}",
            7,
            7,
            top + (2 if i % 2 else 0),
            COLORS["note"] if i % 2 == 0 else COLORS["note_alt"],
            gap=6,
            lateral=3.5 if i % 2 == 0 else -3.5,
            thickness=1.0,
        )
    b.pad(4, top, COLORS["checkpoint"], gap=5)

    # Segment 5: a climb of four steps (each a jump), a laser across the last one.
    for i in range(4):
        top += 3.5
        b.piece(f"Climb{i + 1}", 9, 9, top, COLORS["book_alt"], gap=3.5)
    b.laser(top, period=3.2, on=1.2, phase=0.0)
    b.pad(5, top, COLORS["checkpoint"], gap=3.5)

    # Segment 6 (north): the laser gallery. Narrow shelves, each with its own pulsing beam.
    b.turn("N")
    for i in range(3):
        top += 1.5 if i % 2 else 0
        b.piece(f"Pencil{4 + i}", 12, 3.2, top, COLORS["pencil"], gap=5, material="Plastic")
        b.laser(top, period=3.0, on=1.1, phase=0.6 * i)
    b.pad(6, top, COLORS["checkpoint"], gap=5)

    # Segment 7 (east): the sky bridge. Small islands over the void with sweeping bars and beams.
    b.turn("E")
    for i in range(14):
        top += 1.0 if i % 3 == 2 else 0.0
        color = COLORS["note"] if i % 2 == 0 else COLORS["note_alt"]
        b.piece(f"Note{6 + i}", 9, 8, top, color, gap=6, lateral=(2.0 if i % 2 else -2.0), thickness=1.0)
        if i % 4 == 1:
            b.spinner(top, length=7.5, speed=1.6 if i % 8 == 1 else -1.6, phase=0.7 * i)
        elif i % 4 == 3:
            b.laser(top, period=2.8, on=1.0, phase=0.5 * i)
    b.pad(7, top, COLORS["checkpoint"], gap=6)

    # Segment 8 (south, then up in a square spiral): the tower, to the golden finish on top.
    b.turn("S")
    cp = 7
    for loop in range(2):
        for side in range(4):
            for i in range(4):
                top += 3.5
                b.piece(f"Climb{5 + loop * 16 + side * 4 + i}", 9, 9, top, COLORS[("book_alt", "book", "book_green", "book_purple")[side]], gap=3.5, thickness=1.5)
                if i == 2 and (loop + side) % 2 == 0:
                    b.laser(top, period=3.4, on=1.2, phase=0.8 * side)
            if not (loop == 1 and side == 3):
                if side in (1, 3) or (loop == 1 and side == 1):
                    cp += 1
                    b.pad(cp, top, COLORS["checkpoint"], size=14, gap=3.5)
                else:
                    b.landing(top, COLORS["hub"], size=12, gap=3.5)
                b.turn(("W", "N", "E", "S")[side])
    b.pad(cp + 1, top, COLORS["finish"], size=20, gap=3.5, kind="Finish", name="FinishPad", height=8)
    b.board(top, FACE_PLUS_X)
    return b


def build_keys_track():
    """Keyboard Dash: keycaps, a cable, scroll keys, the arrow keys and the Enter key."""
    b = TrackBuilder("keys")
    top = 10.0
    b.stairs(-80, 40, top)
    b.start_pad((-70, 40), "E", top, COLORS["keys_start"])

    # Segment 1: small keycaps, higher by one or two studs each, with real gaps.
    for i, rise in enumerate((1, 2, 1, 2, 1)):
        top += rise
        b.piece(f"Key{i + 1}", 8, 8, top, COLORS["keycap"] if i % 2 == 0 else COLORS["keycap_dark"], gap=4, thickness=3.0)
    b.pad(1, top, COLORS["checkpoint"], gap=4)

    # Segment 2: three stretches of thin cable over wide gaps, not all at the same height.
    for i, rise in enumerate((0, 1.5, -1.5)):
        top += rise
        b.piece(f"Cable{i + 1}", 22, 2.5, top, COLORS["cable"], gap=7, thickness=1.5)
    b.pad(2, top, COLORS["checkpoint"], gap=7)

    # Segment 3 (south): scroll keys in a wide zigzag, alternating heights.
    b.turn("S")
    for i in range(6):
        b.piece(
            f"ZigKey{i + 1}",
            7,
            7,
            top + (2 if i % 2 else 0),
            COLORS["key_blue"] if i % 2 == 0 else COLORS["key_red"],
            gap=6,
            lateral=3.5 if i % 2 == 0 else -3.5,
            thickness=3.0,
        )
    b.pad(3, top, COLORS["checkpoint"], gap=6)

    # Segment 4 (west): the arrow keys climbing, three and a half studs each.
    b.turn("W")
    for i in range(4):
        top += 3.5
        b.piece(f"ArrowKey{i + 1}", 7, 7, top, COLORS["keycap_dark"] if i % 2 == 0 else COLORS["keycap"], gap=3.5, thickness=3.0)
    b.pad(4, top, COLORS["checkpoint"], gap=3.5)

    # Segment 5 (west): steps up to the Enter key, a laser across the last one.
    for i in range(3):
        top += 2.5
        b.piece(f"EnterStep{i + 1}", 9, 9, top, COLORS["key_green"], gap=4)
    b.laser(top, period=3.2, on=1.2, phase=0.4)
    b.pad(5, top, COLORS["checkpoint"], gap=4)

    # Segment 6 (north, over the start): cable gallery. Thin cables, each with a pulsing beam.
    b.turn("N")
    for i in range(5):
        top += 1.5 if i % 2 else 0
        b.piece(f"Cable{4 + i}", 12, 2.5, top, COLORS["cable"], gap=5, thickness=1.5)
        b.laser(top, period=3.0, on=1.1, phase=0.6 * i)
    b.pad(6, top, COLORS["checkpoint"], gap=5)

    # Segment 7 (east): the function row. Small keycap islands with sweeping bars and beams.
    b.turn("E")
    for i in range(11):
        top += 1.0 if i % 3 == 2 else 0.0
        b.piece(f"ZigKey{7 + i}", 8, 8, top, COLORS["key_blue"] if i % 2 == 0 else COLORS["key_red"], gap=6, lateral=(2.0 if i % 2 else -2.0), thickness=2.0)
        if i % 4 == 1:
            b.spinner(top, length=7.0, speed=1.6 if i % 8 == 1 else -1.6, phase=0.7 * i)
        elif i % 4 == 3:
            b.laser(top, period=2.8, on=1.0, phase=0.5 * i)
    b.pad(7, top, COLORS["checkpoint"], gap=6)

    # Segment 8 (south, then up in a square spiral): the tower, to the Enter key on top.
    b.turn("S")
    cp = 7
    for loop in range(2):
        for side in range(4):
            for i in range(4):
                top += 3.5
                b.piece(f"ArrowKey{5 + loop * 16 + side * 4 + i}", 8, 8, top, COLORS[("keycap_dark", "keycap", "key_green", "key_blue")[side]], gap=3.5, thickness=2.0)
                if i == 2 and (loop + side) % 2 == 0:
                    b.laser(top, period=3.4, on=1.2, phase=0.8 * side)
            if not (loop == 1 and side == 3):
                if side in (1, 3) or (loop == 1 and side == 1):
                    cp += 1
                    b.pad(cp, top, COLORS["checkpoint"], size=14, gap=3.5)
                else:
                    b.landing(top, COLORS["keycap_dark"], size=12, gap=3.5)
                b.turn(("W", "N", "E", "S")[side])
    b.pad(cp + 1, top, COLORS["enter"], size=20, gap=3.5, kind="Finish", name="FinishPad", height=8)
    b.board(top, FACE_PLUS_X)
    return b


# --- Hub and club plots ----------------------------------------------------------------

# Plots along the west wall, turned so the front of every club faces east, into the hub.
PLOT_POSITIONS = [(-ROOM + 20, z) for z in (-150, -110, -70, 70, 110, 150)]
PLOT_TOP = 1.5


def build_hub(desk, keys):
    children = [
        # A soft rug makes the west end read as home.
        prop_block("Rug", (ROOM - 104, 0.4, ROOM * 2 - 8), (-ROOM + 4 - 100) / 2, FLOOR_Y, 0, COLORS["mousepad"], material="Fabric", collide=False),
        {
            "name": "HubSpawn",
            "className": "SpawnLocation",
            "properties": {
                "Anchored": True,
                "Size": [8, 1, 8],
                "CFrame": cframe(-150, 1.5, 0),
                "Color": COLORS["hub"],
                "Material": "SmoothPlastic",
                "Neutral": True,
                "Duration": 0,
            },
        },
    ]
    # The big welcome sign (the client paints the title on it) and a spinning golden star above the spawn.
    sign = part("LogoSign", (70, 22, 2), (-ROOM + 6, 42, 0), COLORS["dark"], center=True, collide=False, query=False, attrs={"FxKind": "LogoSign"})
    sign["properties"]["CFrame"]["CFrame"]["orientation"] = FACE_PLUS_X
    children.append(sign)
    for i, x in enumerate((-ROOM + 6,)):
        for sz in (-37, 37):
            children.append(prop_block(f"SignPost{sz}", (2.4, 31, 2.4), x, FLOOR_Y, sz, COLORS["post"], collide=False))
    star_a = part("TrophyStarA", (8, 8, 1.5), (-150, 22, 0), COLORS["gold"], center=True, collide=False, query=False, material="Neon", attrs={"Spin": 40})
    star_b = part("TrophyStarB", (8, 8, 1.5), (-150, 22, 0), COLORS["gold"], center=True, collide=False, query=False, material="Neon", attrs={"Spin": 40, "SpinOffset": 45})
    children.append(model("Trophy", [star_a, star_b, prop_block("Stand", (4, 14, 4), -150, FLOOR_Y, 0, COLORS["steel"], collide=False)]))
    plots = []
    for i, (px, pz) in enumerate(PLOT_POSITIONS, start=1):
        p = part(f"Plot{i}", (24, 1, 24), (px, PLOT_TOP, pz), COLORS["plot"], attrs={"PlotIndex": i})
        p["properties"]["CFrame"]["CFrame"]["orientation"] = YAW_90
        plots.append(p)
    children.append(folder("Plots", plots))

    # Guide trails from the hub to the two start stairs, and a beacon above each start pad.
    for name, color, z in (("DeskTrail", "start", -40), ("KeysTrail", "keys_start", 40)):
        tiles = []
        for i in range(8):
            t = i / 7
            tiles.append(
                prop_block(
                    f"Tile{i + 1}",
                    (5, 0.3, 5),
                    -118 + t * 22,
                    FLOOR_Y,
                    (z * 0.12) + t * (z - z * 0.12),
                    COLORS[color],
                    material="Neon",
                    collide=False,
                )
            )
        children.append(model(name, tiles))
    for name, color, z in (("DeskBeacon", "start", -40), ("KeysBeacon", "keys_start", 40)):
        children.append(
            model(name, [prop_block("Pillar", (3, 40, 3), -63, 10, z - 7, COLORS[color], material="Neon", collide=False)])
        )
    return children


# --- Room shell: floor, walls, ceiling, lamps -----------------------------------------------------


def build_room():
    thick = 4
    full = ROOM * 2 + thick * 2
    out = [
        part("Floor", (full, thick, full), (0, FLOOR_Y, 0), COLORS["desk"], material="WoodPlanks"),
        part("Ceiling", (full, thick, full), (0, CEILING_Y + thick, 0), COLORS["ceiling"]),
    ]
    wall_y = FLOOR_Y + WALL_H / 2
    out += [
        prop_block("WallWest", (thick, WALL_H, full), -(ROOM + thick / 2), FLOOR_Y, 0, COLORS["wall"], material="Wood"),
        prop_block("WallEast", (thick, WALL_H, full), ROOM + thick / 2, FLOOR_Y, 0, COLORS["wall"], material="Wood"),
        prop_block("WallNorth", (full, WALL_H, thick), 0, FLOOR_Y, -(ROOM + thick / 2), COLORS["wall"], material="Wood"),
        prop_block("WallSouth", (full, WALL_H, thick), 0, FLOOR_Y, ROOM + thick / 2, COLORS["wall"], material="Wood"),
    ]
    del wall_y
    # Baseboards and a painted stripe along every wall (decor, never collides).
    for name, size, x, z in (
        ("West", (1.2, 6, ROOM * 2), -ROOM + 0.6, 0),
        ("East", (1.2, 6, ROOM * 2), ROOM - 0.6, 0),
        ("North", (ROOM * 2, 6, 1.2), 0, -ROOM + 0.6),
        ("South", (ROOM * 2, 6, 1.2), 0, ROOM - 0.6),
    ):
        out.append(prop_block(f"Baseboard{name}", size, x, FLOOR_Y, z, COLORS["baseboard"], collide=False))
        sx = (size[0], 5, size[2])
        out.append(prop_block(f"Stripe{name}", sx, x, FLOOR_Y + 60, z, COLORS["stripe"], collide=False))
    return out


def build_ceiling_lamps():
    """Nine hanging lamps; each carries a warm PointLight so the closed room is bright."""
    out = []
    n = 0
    for lx in (-140, 0, 140):
        for lz in (-140, 0, 140):
            n += 1
            bulb = prop_block("Bulb", (16, 2, 16), lx, CEILING_Y - 28, lz, COLORS["glow"], material="Neon", collide=False)
            bulb["children"] = [
                {
                    "name": "Glow",
                    "className": "PointLight",
                    "properties": {"Brightness": 1.5, "Range": 200, "Color": [1.0, 0.88, 0.68], "Shadows": False},
                }
            ]
            out.append(
                model(
                    f"CeilingLamp{n}",
                    [
                        prop_block("Cord", (1.2, 20, 1.2), lx, CEILING_Y - 20, lz, COLORS["dark"], collide=False),
                        prop_block("ShadeBottom", (26, 5, 26), lx, CEILING_Y - 25, lz, COLORS["lamp"], collide=False),
                        prop_block("ShadeTop", (16, 5, 16), lx, CEILING_Y - 20, lz, COLORS["lamp"], collide=False),
                        bulb,
                    ],
                )
            )
    return out


# --- Props ------------------------------------------------------------------------------------------


def prop_mug(x, z):
    y = FLOOR_Y
    return (
        model(
            "Mug",
            [
                prop_cylinder("MugBody", 28, 32, x, y, z, COLORS["mug"]),
                prop_cylinder("MugCoffee", 23, 0.6, x, y + 29.6, z, COLORS["coffee"], collide=False),
                prop_block("MugHandleTop", (7, 3, 4), x + 16.5, y + 24, z, COLORS["mug"]),
                prop_block("MugHandleSide", (3, 16, 4), x + 20, y + 11, z, COLORS["mug"]),
                prop_block("MugHandleBottom", (7, 3, 4), x + 16.5, y + 8, z, COLORS["mug"]),
            ],
        ),
        (24, 16),
    )


def prop_notebooks(x, z):
    y = FLOOR_Y
    parts = []
    for i, color in enumerate(("book", "book_alt", "book_green", "book_purple")):
        width = 62 - i * 3
        parts.append(prop_block(f"Notebook{i + 1}", (width, 4, 44), x + i * 1.5, y + i * 4, z, COLORS[color]))
        parts.append(prop_block(f"Pages{i + 1}", (0.4, 3, 40), x + i * 1.5 + width / 2, y + i * 4 + 0.5, z, COLORS["pages"], collide=False))
    return model("Notebooks", parts), (33, 23)


def prop_pads(x, z):
    y = FLOOR_Y
    parts = []
    for i, (color, dx, dz) in enumerate((("note", 0, 0), ("note_alt", 26, 8), ("eraser", -24, 12))):
        parts.append(prop_block(f"Pad{i + 1}", (22, 6, 22), x + dx, y, z + dz, COLORS[color]))
        parts.append(prop_block(f"PadTop{i + 1}", (22, 0.2, 22), x + dx, y + 6, z + dz, COLORS["note"], collide=False))
    return model("StickyPads", parts), (37, 23)


def prop_tape(x, z):
    y = FLOOR_Y
    return (
        model(
            "TapeRoll",
            [
                prop_cylinder("TapeRing", 36, 16, x, y, z, COLORS["tape"], upright=False),
                prop_cylinder("TapeHole", 14, 16.4, x, y + 11, z, COLORS["desk"], collide=False, upright=False),
            ],
        ),
        (9, 19),
    )


def prop_stapler(x, z):
    y = FLOOR_Y
    return (
        model(
            "Stapler",
            [
                prop_block("StaplerBase", (38, 3, 12), x, y, z, COLORS["steel"], material="Metal"),
                prop_block("StaplerBody", (36, 6, 11), x, y + 3, z, COLORS["stapler"]),
                prop_block("StaplerHead", (14, 3, 11), x + 12, y + 9, z, COLORS["dark"]),
            ],
        ),
        (20, 7),
    )


def prop_calculator(x, z):
    y = FLOOR_Y
    parts = [
        prop_block("CalcBody", (36, 5, 50), x, y, z, COLORS["calc"]),
        prop_block("CalcScreen", (30, 0.4, 10), x, y + 5, z - 14, COLORS["screen"], material="Neon", collide=False),
    ]
    palette = ("book", "pencil", "book_alt", "book_green")
    for row in range(4):
        for col in range(4):
            parts.append(prop_block(f"Key{row}{col}", (6, 1, 6), x - 10.5 + col * 7, y + 5, z - 8 + row * 8 + 2, COLORS[palette[(row + col) % 4]], collide=False))
    return model("Calculator", parts), (19, 26)


def prop_case(x, z):
    y = FLOOR_Y
    return (
        model(
            "PencilCase",
            [
                prop_block("CaseBody", (76, 14, 28), x, y, z, COLORS["case"], material="Fabric"),
                prop_block("CaseZip", (76, 0.5, 1.8), x, y + 14, z, COLORS["steel"], material="Metal", collide=False),
                prop_block("CaseTab", (4, 1.2, 4), x + 30, y + 14, z, COLORS["gold"], collide=False),
            ],
        ),
        (39, 15),
    )


def prop_lamp(x, z):
    y = FLOOR_Y
    bulb = prop_block("LampBulb", (14, 2, 14), x, y + 64, z, COLORS["glow"], material="Neon", collide=False)
    bulb["children"] = [
        {
            "name": "LampGlow",
            "className": "PointLight",
            "properties": {"Brightness": 1.2, "Range": 110, "Color": [1.0, 0.86, 0.62], "Shadows": False},
        }
    ]
    return (
        model(
            "ReadingLamp",
            [
                prop_cylinder("LampBase", 36, 3, x, y, z, COLORS["dark"]),
                prop_block("LampArm", (3, 62, 3), x, y + 3, z, COLORS["dark"]),
                prop_block("ShadeBottom", (34, 6, 34), x, y + 65, z, COLORS["lamp"]),
                prop_block("ShadeMiddle", (26, 6, 26), x, y + 71, z, COLORS["lamp"]),
                prop_block("ShadeTop", (16, 6, 16), x, y + 77, z, COLORS["lamp"]),
                bulb,
            ],
        ),
        (19, 19),
    )


def prop_pen(x, z):
    y = FLOOR_Y
    return (
        model(
            "Pen",
            [
                prop_cylinder("PenBarrel", 9, 78, x, y, z, COLORS["cup"], upright=False),
                prop_cylinder("PenGrip", 9.4, 14, x - 36, y, z, COLORS["dark"], upright=False),
                prop_cylinder("PenCap", 10, 18, x + 38, y, z, COLORS["silver"], material="Metal", upright=False),
                prop_block("PenClip", (16, 1.2, 2), x + 42, y + 9.4, z, COLORS["steel"], material="Metal", collide=False),
            ],
        ),
        (48, 6),
    )


def prop_erasers(x, z):
    y = FLOOR_Y
    parts = []
    for i, (color, dx, dz, w) in enumerate((("eraser", 0, 0, 16), ("pages", 20, 6, 14), ("book_alt", 9, 22, 12))):
        parts.append(prop_block(f"Eraser{i + 1}", (w, 9, 11), x + dx, y, z + dz, COLORS[color]))
        parts.append(prop_block(f"Sleeve{i + 1}", (w / 2.5, 9.2, 11.2), x + dx, y, z + dz, COLORS["dark"], collide=False))
    return model("Erasers", parts), (27, 22)


def prop_tacks(x, z):
    y = FLOOR_Y
    colors = ("book", "pencil", "book_green", "book_purple")
    parts = []
    for i in range(4):
        tx = x + (i % 2) * 18
        tz = z + (i // 2) * 18
        parts.append(prop_cylinder(f"TackHead{i + 1}", 12, 3, tx, y, tz, COLORS[colors[i]]))
        parts.append(prop_cylinder(f"TackTop{i + 1}", 6, 4, tx, y + 3, tz, COLORS[colors[i]]))
        parts.append(prop_cylinder(f"TackPin{i + 1}", 1.6, 6, tx, y + 7, tz, COLORS["steel"], material="Metal", collide=False))
    return model("Thumbtacks", parts), (16, 16)


def prop_ruler(x, z):
    y = FLOOR_Y
    parts = [prop_block("Ruler", (140, 1.2, 12), x, y, z, COLORS["ruler"], material="Plastic")]
    for tick in range(0, 141, 20):
        parts.append(prop_block(f"Tick{tick}", (0.6, 0.2, 5 if tick % 40 == 0 else 3), x - 70 + tick, y + 1.2, z - 3, COLORS["ruler_tick"], collide=False))
    return model("Ruler", parts), (72, 7)


def prop_crayons(x, z):
    y = FLOOR_Y
    parts = []
    palette = ("book", "pencil", "book_alt", "book_green", "book_purple", "eraser")
    for i in range(6):
        parts.append(prop_cylinder(f"Crayon{i + 1}", 6, 34, x, y + i * 6.2, z + (i % 2) * 2, COLORS[palette[i]], upright=False))
    return model("Crayons", parts), (18, 5)


def prop_paperclip(x, z):
    y = FLOOR_Y
    return (
        model(
            "Paperclip",
            [
                prop_block("ClipTop", (24, 1.6, 1.6), x, y, z - 5, COLORS["steel"], material="Metal"),
                prop_block("ClipBottom", (16, 1.6, 1.6), x + 3, y, z + 5, COLORS["steel"], material="Metal"),
                prop_block("ClipLeft", (1.6, 1.6, 10), x - 12, y, z, COLORS["steel"], material="Metal"),
                prop_block("ClipRight", (1.6, 1.6, 10), x + 11, y, z, COLORS["steel"], material="Metal"),
                prop_block("ClipInner", (12, 1.6, 1.6), x - 2, y + 1.6, z, COLORS["steel"], material="Metal", collide=False),
            ],
        ),
        (13, 7),
    )


def prop_sharpener(x, z):
    y = FLOOR_Y
    return (
        model(
            "Sharpener",
            [
                prop_block("SharpenerBody", (14, 8, 9), x, y, z, COLORS["key_blue"]),
                prop_block("SharpenerBlade", (4, 0.4, 5), x + 3, y + 8, z, COLORS["steel"], material="Metal", collide=False),
                prop_cylinder("SharpenerHole", 4, 0.4, x - 4, y + 8, z, COLORS["dark"], collide=False),
            ],
        ),
        (8, 6),
    )


def prop_cubes(x, z):
    y = FLOOR_Y
    return (
        model(
            "Cubes",
            [
                prop_block("CubeRed", (8, 8, 8), x - 5, y, z, COLORS["key_red"]),
                prop_block("CubeBlue", (8, 8, 8), x + 5, y, z + 1, COLORS["key_blue"]),
                prop_block("CubeGreen", (8, 8, 8), x, y + 8, z, COLORS["key_green"]),
            ],
        ),
        (10, 6),
    )


def prop_booklets(x, z):
    y = FLOOR_Y
    return (
        model(
            "Booklets",
            [
                prop_block("BookletBottom", (24, 3, 17), x, y, z, COLORS["book_alt"]),
                prop_block("BookletMiddle", (22, 3, 16), x + 1, y + 3, z, COLORS["book"]),
                prop_block("BookletTop", (20, 3, 15), x - 1, y + 6, z, COLORS["book_green"]),
                prop_block("BookletPages", (0.3, 8, 14), x + 12.2, y + 0.5, z, COLORS["pages"], collide=False),
            ],
        ),
        (13, 9),
    )


def prop_coins(x, z):
    y = FLOOR_Y
    parts = []
    for i in range(4):
        parts.append(prop_cylinder(f"Coin{i + 1}", 10, 1.4, x + (i % 2) * 0.8, y + i * 1.4, z, COLORS["gold"], material="Metal"))
    return model("Coins", parts), (6, 6)


PROP_CATALOG = [
    # (factory, most of this kind in the room)
    (prop_ruler, 3),
    (prop_notebooks, 6),
    (prop_pads, 6),
    (prop_case, 5),
    (prop_pen, 5),
    (prop_calculator, 5),
    (prop_erasers, 6),
    (prop_lamp, 4),
    (prop_mug, 5),
    (prop_tape, 5),
    (prop_stapler, 5),
    (prop_crayons, 8),
    (prop_tacks, 12),
    (prop_booklets, 12),
    (prop_paperclip, 14),
    (prop_cubes, 12),
    (prop_sharpener, 10),
    (prop_coins, 12),
]


SMALL_PROPS = {"prop_booklets", "prop_paperclip", "prop_cubes", "prop_sharpener", "prop_coins", "prop_crayons", "prop_tacks"}


def build_scenery(forbidden):
    """Fills the free floor with props (seeded: the same room every time). The floor is scanned in a
    shuffled grid; at every spot the first prop that fits gets placed, so big gaps get notebooks and
    pencil cases and small gaps get thumbtacks. `forbidden` lists the rectangles (tracks, plots, hub)
    the props must stay clear of."""
    rng = random.Random(20261123)
    placed = []
    out = []
    counter = {}
    step = 6
    spots = [(x, z) for x in range(-ROOM + 12, ROOM - 12, step) for z in range(-ROOM + 12, ROOM - 12, step)]

    def try_place(factory, x, z):
        node, (hx, hz) = factory(x, z)
        rect = (x - hx, x + hx, z - hz, z + hz)
        if rect[0] < -ROOM + EDGE or rect[1] > ROOM - EDGE or rect[2] < -ROOM + EDGE or rect[3] > ROOM - EDGE:
            return False
        if any(rects_overlap(rect, f, 11) for f in forbidden):
            return False
        if any(rects_overlap(rect, q, 2) for q in placed):
            return False
        placed.append(rect)
        name = factory.__name__
        counter[name] = counter.get(name, 0) + 1
        node["name"] = f"{node['name']}{counter[name]}"
        out.append(node)
        return True

    # Pass 1: the big props, one kind after the other, each on a fresh shuffle of the floor.
    for factory, limit in PROP_CATALOG:
        if factory.__name__ in SMALL_PROPS:
            continue
        order = spots[:]
        rng.shuffle(order)
        for x, z in order:
            if counter.get(factory.__name__, 0) >= limit:
                break
            try_place(factory, x, z)
    # Pass 2: small props fill every gap that is left.
    order = spots[:]
    rng.shuffle(order)
    small = [(f, n) for f, n in PROP_CATALOG if f.__name__ in SMALL_PROPS]
    for x, z in order:
        rng.shuffle(small)
        for factory, limit in small:
            if counter.get(factory.__name__, 0) < limit and try_place(factory, x, z):
                break
    print("  props placed:", {k.replace("prop_", ""): v for k, v in sorted(counter.items())})
    return out, placed


def build_wall_decor(forbidden):
    """Bookshelf rows along the north and south walls, a pencil rack on the east wall."""
    rng = random.Random(7)
    out = []
    book_palette = ("book", "book_alt", "book_green", "book_purple", "pencil", "eraser", "key_red", "key_blue")
    for wall, z, label in (("North", -ROOM + 11, "N"), ("South", ROOM - 11, "S")):
        books = []
        x = -ROOM + 10
        n = 0
        while x < ROOM - 24:
            w = rng.choice((8, 10, 12, 14))
            h = rng.randint(30, 62)
            rect = (x, x + w, z - 10, z + 10)
            if not any(rects_overlap(rect, f, 6) for f in forbidden):
                n += 1
                color = COLORS[book_palette[(n + rng.randint(0, 3)) % len(book_palette)]]
                books.append(prop_block(f"Book{n}", (w, h, 20), x + w / 2, FLOOR_Y, z, color))
                books.append(prop_block(f"Spine{n}", (w * 0.6, 3, 0.4), x + w / 2, FLOOR_Y + h * 0.6, z + (-10.2 if label == "S" else 10.2), COLORS["pages"], collide=False))
            x += w + 0.5
        out.append(model(f"Bookshelf{wall}", books))
    pencils = []
    for i in range(18):
        z = -ROOM + 16 + i * 21
        rect = (ROOM - 20, ROOM - 4, z - 4, z + 4)
        if any(rects_overlap(rect, f, 6) for f in forbidden):
            continue
        color = COLORS[("pencil", "book", "book_alt", "book_green")[i % 4]]
        h = 70 + (i * 13) % 40
        pencils.append(prop_block(f"RackPencil{i + 1}", (7, h, 7), ROOM - 12, FLOOR_Y, z, color))
        pencils.append(prop_block(f"RackTip{i + 1}", (4.5, 7, 4.5), ROOM - 12, FLOOR_Y + h, z, COLORS["wood"], collide=False))
    out.append(model("PencilRack", pencils))
    return out


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




def track_report(builder, forbidden_label):
    segs = builder.segment_lengths()
    total = sum(segs)
    straight = total / 16.0
    print(f"{forbidden_label}: {len(builder.geo)} pieces, walking length {total:.0f} studs ({straight:.1f} s at 16 st/s)")
    print(f"  segments (studs): {[round(s) for s in segs]}")
    print(f"  segment minimums @55% of walking time, ms (rounded to 500): {[int(round(s / 16 * 0.55 * 1000 / 500) * 500) for s in segs]}")
    print(f"  suggested limits: gold {straight * 1.5:.0f} s, silver {straight * 1.9:.0f} s, minimum {straight * 0.9:.0f} s")


def main():
    desk = build_desk_track()
    keys = build_keys_track()

    # Both tracks must stay inside their half of the room, clear of the west hub.
    for b, (zmin, zmax) in ((desk, (-ROOM + 4, -12)), (keys, (12, ROOM - 4))):
        for x0, x1, z0, z1 in b.rects:
            assert -112 <= x0 and x1 <= ROOM - 4, f"{b.label}: piece out of the track area in x: {x0:.0f}..{x1:.0f}"
            assert zmin <= z0 and z1 <= zmax, f"{b.label}: piece out of its half in z: {z0:.0f}..{z1:.0f}"

    forbidden = list(desk.rects) + list(keys.rects)
    forbidden += [(px - 12, px + 12, pz - 12, pz + 12) for px, pz in PLOT_POSITIONS]
    forbidden += [(-185, -100, -90, 90)]  # hub: spawn, trails, rug centre
    forbidden += [(-ROOM, ROOM, -ROOM, -ROOM + 22), (-ROOM, ROOM, ROOM - 22, ROOM), (ROOM - 24, ROOM, -ROOM, ROOM)]
    props, placed = build_scenery(forbidden)
    decor = build_wall_decor(list(desk.rects) + list(keys.rects) + [(px - 12, px + 12, pz - 12, pz + 12) for px, pz in PLOT_POSITIONS])

    world = {
        "className": "Model",
        "children": [
            folder("Room", build_room() + build_ceiling_lamps()),
            *build_hub(desk, keys),
            desk.model("DeskDash", (-96, -40)),
            keys.model("KeyDash", (-96, 40)),
            folder("Scenery", props + decor),
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

    track_report(desk, "Desk Dash")
    track_report(keys, "Keyboard Dash")
    count = len(json.dumps(world).split('"className"')) - 1
    print(f"room {ROOM * 2} x {ROOM * 2}, {len(props)} props + {len(decor)} wall decor groups, {count} instances in total")


if __name__ == "__main__":
    main()
