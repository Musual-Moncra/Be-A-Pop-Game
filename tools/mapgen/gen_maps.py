"""Be A Poop map generator v2: Lobby + Zone1 Kitchen, Zone2 Mall, Zone3 Park, Zone4 Hotel.
Writes src/workspace/*.model.json and prints RunConfig.NpcPatrols Luau + MapConfig spawns."""
import json
import math
import random
import sys

ROOT = sys.argv[1]
random.seed(7)
FT = 1.0
I3 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
UPRIGHT = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]
PATROLS = {}


def rot_y(deg):
    r = math.radians(deg)
    c, s = round(math.cos(r), 6), round(math.sin(r), 6)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_x(deg):
    r = math.radians(deg)
    c, s = round(math.cos(r), 6), round(math.sin(r), 6)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_z(deg):
    r = math.radians(deg)
    c, s = round(math.cos(r), 6), round(math.sin(r), 6)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def C(h):
    h = h.lstrip("#")
    return [round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4)]


def part(name, size, pos, color, mat="SmoothPlastic", rot=I3, shape=None, collide=True,
         cls="Part", children=None, attrs=None, **extra):
    props = {
        "Anchored": True, "CanCollide": collide,
        "Size": [round(v, 3) for v in size],
        "CFrame": {"CFrame": {"position": [round(v, 3) for v in pos], "orientation": rot}},
        "Color": C(color) if isinstance(color, str) else color,
        "Material": mat, "TopSurface": "Smooth", "BottomSurface": "Smooth",
    }
    if shape:
        props["Shape"] = shape
    if not collide:
        props.setdefault("CanQuery", False)
        props.setdefault("CanTouch", False)
    props.update(extra)
    node = {"name": name, "className": cls, "properties": props}
    if children:
        node["children"] = children
    if attrs:
        node["attributes"] = attrs
    return node


def deco(name, size, pos, color, mat="SmoothPlastic", **kw):
    return part(name, size, pos, color, mat, collide=False, CastShadow=kw.pop("CastShadow", True), **kw)


def box(name, size, x, z, color, y=FT, **kw):
    return part(name, size, [x, y + size[1] / 2, z], color, **kw)


def cyl(name, d, h, x, y, z, color, **kw):
    return part(name, [h, d, d], [x, y + h / 2, z], color, rot=UPRIGHT, shape="Cylinder", **kw)


def ball(name, d, x, y, z, color, **kw):
    return part(name, [d, d, d], [x, y, z], color, shape="Ball", **kw)


def wedge(name, size, pos, color, rot=I3, **kw):
    return part(name, size, pos, color, rot=rot, cls="WedgePart", **kw)


def model(name, children, otype=None, anim=None):
    node = {"name": name, "className": "Model", "children": children}
    attrs = {}
    if otype:
        attrs["ObjectType"] = otype
    if anim:
        attrs["AnimKind"] = anim
        attrs["AnimPhase"] = round(random.random() * 6.28, 3)
    if attrs:
        node["attributes"] = attrs
    return node


def anim(node, kind):
    node.setdefault("attributes", {})
    node["attributes"]["AnimKind"] = kind
    node["attributes"]["AnimPhase"] = round(random.random() * 6.28, 3)
    return node


def folder(name, children):
    return {"name": name, "className": "Folder", "children": children}


def sign(text, face, color, stroke="#3a2210", ppS=40):
    label = {"name": "Label", "className": "TextLabel", "properties": {
        "Size": {"UDim2": [[1, 0], [1, 0]]}, "BackgroundTransparency": 1, "Text": text,
        "TextScaled": True, "TextColor3": C(color),
        "FontFace": {"Font": {"family": "rbxasset://fonts/families/FredokaOne.json", "weight": "Bold", "style": "Normal"}}},
        "children": [{"name": "Stroke", "className": "UIStroke", "properties": {"Color": C(stroke), "Thickness": 4}}]}
    return {"name": "SurfaceGui", "className": "SurfaceGui", "properties": {
        "Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": ppS, "LightInfluence": 0}, "children": [label]}


def light(color, rng=40, brightness=1.2):
    return {"name": "Light", "className": "PointLight",
            "properties": {"Color": C(color), "Range": rng, "Brightness": brightness, "Shadows": False}}


def floor_tiles(cx, cz, size, tile, ca, cb, mat="SmoothPlastic", pattern="checker"):
    n = int(size // tile)
    sx, sz = cx - size / 2 + tile / 2, cz - size / 2 + tile / 2
    out = []
    for i in range(n):
        for j in range(n):
            col = ca if ((i + j) % 2 == 0 if pattern == "checker" else (i % 4 == 0 or j % 4 == 0)) else cb
            out.append(part(f"Tile_{i}_{j}", [tile, 2, tile], [sx + i * tile, FT - 1, sz + j * tile], col, mat))
    return model("Floor", out)


def room(cx, cz, size, height, wall, trim, ceiling, ceiling_on=True, wall_mat="SmoothPlastic", stripe=None):
    half, t = size / 2, 4
    y = FT + height / 2
    span = size + t * 2
    out = [
        part("WallNorth", [span, height, t], [cx, y, cz - half - t / 2], wall, wall_mat),
        part("WallSouth", [span, height, t], [cx, y, cz + half + t / 2], wall, wall_mat),
        part("WallEast", [t, height, size], [cx + half + t / 2, y, cz], wall, wall_mat),
        part("WallWest", [t, height, size], [cx - half - t / 2, y, cz], wall, wall_mat),
    ]
    th = 2
    for nm, sz, ps in (("N", [size, th, 0.6], [cx, FT + th / 2, cz - half + 0.3]),
                       ("S", [size, th, 0.6], [cx, FT + th / 2, cz + half - 0.3]),
                       ("E", [0.6, th, size], [cx + half - 0.3, FT + th / 2, cz]),
                       ("W", [0.6, th, size], [cx - half + 0.3, FT + th / 2, cz])):
        out.append(part("Trim" + nm, sz, ps, trim))
    if stripe:
        sy = FT + height * 0.55
        for nm, sz, ps in (("N", [size, 3, 0.6], [cx, sy, cz - half + 0.3]),
                           ("S", [size, 3, 0.6], [cx, sy, cz + half - 0.3]),
                           ("E", [0.6, 3, size], [cx + half - 0.3, sy, cz]),
                           ("W", [0.6, 3, size], [cx - half + 0.3, sy, cz])):
            out.append(part("Stripe" + nm, sz, ps, stripe))
    if ceiling_on:
        out.append(part("Ceiling", [span, 2, span], [cx, FT + height + 1, cz], ceiling, CastShadow=False))
    return model("Walls", out)


def play_area(cx, cz, size, height):
    return part("PlayArea", [size - 10, height, size - 10], [cx, FT + height / 2, cz], "#ffffff",
                collide=False, Transparency=1, CastShadow=False)


def human(name, x, z, shirt, pants="#3c3c50", skin="#ffcc9e", hat=None, hat_h=1.2, scale=1.0, extra=None):
    s, y = scale, FT
    kids = [
        part("HumanoidRootPart", [2.4 * s, 6 * s, 2.4 * s], [x, y + 3 * s, z], "#ffffff", collide=False, Transparency=1),
        box("Legs", [2 * s, 1.6 * s, 1.3 * s], x, z, pants, y=y),
        box("Torso", [2.6 * s, 2.8 * s, 1.6 * s], x, z, shirt, y=y + 1.6 * s),
        ball("Head", 2.4 * s, x, y + 5.6 * s, z, skin),
        ball("EyeL", 0.4 * s, x - 0.45 * s, y + 5.8 * s, z - 1.1 * s, "#222230", collide=False),
        ball("EyeR", 0.4 * s, x + 0.45 * s, y + 5.8 * s, z - 1.1 * s, "#222230", collide=False),
    ]
    if hat:
        kids.append(box("Hat", [2.2 * s, hat_h * s, 2.2 * s], x, z, hat, y=y + 6.6 * s))
    if extra:
        kids += extra
    return model(name, kids)


def critter(name, x, z, body, ear, scale=1.0):
    s, y = scale, FT
    return model(name, [
        part("HumanoidRootPart", [2.4 * s, 3 * s, 4 * s], [x, y + 1.5 * s, z], "#ffffff", collide=False, Transparency=1),
        box("Body", [2.2 * s, 1.8 * s, 3.6 * s], x, z, body, y=y + 0.8 * s),
        ball("Head", 2 * s, x, y + 2.8 * s, z - 1.8 * s, body),
        box("EarL", [0.5 * s, 0.9 * s, 0.4 * s], x - 0.6 * s, z - 1.8 * s, ear, y=y + 3.5 * s),
        box("EarR", [0.5 * s, 0.9 * s, 0.4 * s], x + 0.6 * s, z - 1.8 * s, ear, y=y + 3.5 * s),
        box("Tail", [0.4 * s, 0.4 * s, 1.6 * s], x, z + 2.4 * s, ear, y=y + 1.8 * s),
        ball("EyeL", 0.35 * s, x - 0.45 * s, y + 3 * s, z - 2.7 * s, "#222230", collide=False),
        ball("EyeR", 0.35 * s, x + 0.45 * s, y + 3 * s, z - 2.7 * s, "#222230", collide=False),
    ])


def patrol(zone, name, a, b, speed):
    PATROLS.setdefault(zone, []).append((name, a, b, speed))


def plant(name, x, z, s=1.0, pot="#e0784a", leaf="#58c06a"):
    return model(name, [
        cyl("Pot", 4 * s, 3.4 * s, x, FT, z, pot),
        cyl("Rim", 4.6 * s, 0.6 * s, x, FT + 3.4 * s, z, pot),
        anim(model("Leaves", [
            ball("LeafA", 6 * s, x, FT + 6.4 * s, z, leaf),
            ball("LeafB", 4.4 * s, x + 1.4 * s, FT + 8.6 * s, z - 0.8 * s, "#76d67e"),
            ball("LeafC", 3.6 * s, x - 1.6 * s, FT + 8 * s, z + 1 * s, "#4aae5c"),
        ]), "Sway"),
    ], "Plant")


def ceiling_fan(name, x, y, z, color="#ffffff"):
    blades = [deco(f"Blade{i}", [9, 0.3, 1.6], [x, y, z], color, rot=rot_y(i * 90)) for i in range(2)]
    blades += [deco("Hub", [2, 1, 2], [x, y, z], "#f0c040")]
    return folder(name, [deco("Rod", [0.5, 4, 0.5], [x, y + 2.2, z], "#d0d0d8"), anim(model("Blades", blades), "Spin")])


def lamp(name, x, y, z, color="#fff2b0"):
    return model(name, [
        deco("Cord", [0.3, 3, 0.3], [x, y + 1.5, z], "#505060"),
        deco("Shade", [3, 1.6, 3], [x, y - 0.6, z], color, "Neon", children=[light(color, 36, 0.8)]),
    ])


def table_set(name, x, z, top="#f6a8b8", leg="#ffffff", chair="#7cc8f0", w=8, d=6, seats=4, otype="Table"):
    h = 4.2
    kids = [box("Top", [w, 0.8, d], x, z, top, y=FT + h)]
    for dx in (-w / 2 + 0.7, w / 2 - 0.7):
        for dz in (-d / 2 + 0.7, d / 2 - 0.7):
            kids.append(box("Leg", [0.7, h, 0.7], x + dx, z + dz, leg))
    spots = [(0, -d / 2 - 2.2), (0, d / 2 + 2.2), (-w / 2 - 2.2, 0), (w / 2 + 2.2, 0)][:seats]
    for i, (dx, dz) in enumerate(spots):
        cx, cz = x + dx, z + dz
        kids.append(model(f"Chair{i}", [
            box("Seat", [3, 0.6, 3], cx, cz, chair, y=FT + 2.4),
            box("Base", [2.2, 2.4, 2.2], cx, cz, leg),
            box("Back", [3 if dx == 0 else 0.6, 3.4, 0.6 if dx == 0 else 3],
                cx + (0 if dx == 0 else (1.2 if dx > 0 else -1.2)), cz + (1.2 if dz > 0 else -1.2) if dx == 0 else cz,
                chair, y=FT + 3),
        ]))
    return model(name, kids, otype)


def bench(name, x, z, rot=0, wood="#d98c4a", metal="#4a5060"):
    r = rot_y(rot)
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))

    def at(dx, dz):
        return x + dx * ca + dz * sa, z - dx * sa + dz * ca

    kids = []
    for nm, size, dx, dy, dz in (("Seat", [10, 0.8, 3], 0, 2.6, 0), ("Back", [10, 3, 0.6], 0, 4.6, 1.3),
                                 ("LegL", [0.8, 2.6, 3], -4.2, 1.3, 0), ("LegR", [0.8, 2.6, 3], 4.2, 1.3, 0)):
        px, pz = at(dx, dz)
        kids.append(part(nm, size, [px, FT + dy, pz], wood if nm in ("Seat", "Back") else metal, rot=r))
    return model(name, kids, "Bench")


def tree(name, x, z, s=1.0, leaf="#5cc85a"):
    return model(name, [
        cyl("Trunk", 3 * s, 10 * s, x, FT, z, "#9a6234"),
        anim(model("Crown", [
            ball("CrownA", 13 * s, x, FT + 14 * s, z, leaf),
            ball("CrownB", 9 * s, x + 4 * s, FT + 17 * s, z + 1 * s, "#74d870"),
            ball("CrownC", 8 * s, x - 4 * s, FT + 16 * s, z - 2 * s, "#48b04e"),
        ]), "Sway"),
    ], "Tree")


def fountain(name, x, z, s=1.0, stone="#e8e4f0", water="#6cd0ff"):
    return model(name, [
        cyl("Basin", 22 * s, 3 * s, x, FT, z, stone),
        cyl("Water", 19 * s, 0.4, x, FT + 2.7 * s, z, water, mat="Glass", Transparency=0.25, collide=False),
        cyl("Column", 4 * s, 7 * s, x, FT + 3 * s, z, stone),
        cyl("Bowl", 10 * s, 1.6 * s, x, FT + 10 * s, z, stone),
        anim(cyl("Jet", 2 * s, 5 * s, x, FT + 11.6 * s, z, water, mat="Glass", Transparency=0.3, collide=False), "Jet"),
        anim(ball("Splash", 4 * s, x, FT + 17 * s, z, water, mat="Glass", Transparency=0.35, collide=False), "Bob"),
    ], "Fountain")


def balloon(name, x, y, z, color):
    return anim(model(name, [
        ball("Balloon", 3.4, x, y + 6, z, color, collide=False),
        deco("String", [0.15, 6, 0.15], [x, y + 2.6, z], "#ffffff"),
    ]), "Bob")


# ---------------------------------------------------------------- LOBBY
def build_lobby():
    cx, cz, size, h = 0, 0, 120, 30
    kids = [floor_tiles(cx, cz, size, 10, "#ffe9a8", "#fff7dc"),
            room(cx, cz, size, h, "#8fd3f5", "#ffffff", "#e8f6ff", stripe="#ffd25a")]
    kids.append(part("SpawnLocation", [10, 1, 10], [0, 1.1, -10], "#ffd25a", cls="SpawnLocation",
                     collide=False, Duration=0, Neutral=True, CanQuery=True, CanTouch=True))
    kids.append(deco("PortalTrail", [6, 0.1, 22], [0, FT + 0.06, 8], "#7a4a22"))
    pz = 32
    green, cap = "#56ba5c", "#3c963c"
    kids.append(model("PortalArch", [
        cyl("PipeLeft", 5, 15, -8, FT, pz, green), cyl("PipeRight", 5, 15, 8, FT, pz, green),
        part("PipeTop", [21, 5, 5], [0, FT + 16.5, pz], green, shape="Cylinder"),
        part("CapL", [2.4, 6.4, 6.4], [-11, FT + 16.5, pz], cap, shape="Cylinder"),
        part("CapR", [2.4, 6.4, 6.4], [11, FT + 16.5, pz], cap, shape="Cylinder"),
        anim(part("PlaySign", [18, 5, 0.8], [0, FT + 22, pz - 1], "#ffd25a", children=[sign("PLAY!", "Front", "#ffffff")]), "Bob"),
    ]))
    kids.append(anim(part("Portal", [11, 14, 1], [0, FT + 7, pz], "#9933e6", "Neon", collide=False, Transparency=0.2,
                          CanTouch=True, children=[light("#c070ff", 30, 2)]), "Pulse"))
    tx, tz = -42, -40
    kids.append(model("Decor", [
        model("GiantToilet", [
            cyl("Base", 8, 5, tx, FT, tz, "#ffffff"), cyl("Bowl", 15, 4, tx, FT + 5, tz, "#ffffff"),
            cyl("Water", 11, 0.3, tx, FT + 8.8, tz, "#78c8f0", mat="Glass", Transparency=0.2, collide=False),
            cyl("Seat", 15.6, 0.8, tx, FT + 9, tz, "#ffd25a"),
            box("Tank", [16, 12, 5], tx, tz - 10, "#ffffff", y=FT + 5), box("Lid", [16.6, 1, 5.6], tx, tz - 10, "#ffd25a", y=FT + 17),
        ]),
        model("ToiletPaper", [cyl(f"Roll{i}", 8, 10, 40 + dx, FT + dy, -40 + dz, "#ffffff") for i, (dx, dy, dz) in
                              enumerate(((0, 0, 0), (9, 0, 4), (4, 10, 2)))]),
        anim(model("RubberDuck", [
            ball("Body", 8, 30, FT + 4, 22, "#ffd23a"), ball("Head", 5.4, 30, FT + 9, 19, "#ffd23a"),
            box("Beak", [2.6, 1, 2.2], 30, 16.4, "#ff8c28", y=FT + 8.2),
            ball("EyeL", 0.8, 28.8, FT + 9.8, 16.8, "#222230", collide=False),
            ball("EyeR", 0.8, 31.2, FT + 9.8, 16.8, "#222230", collide=False)]), "Wobble"),
        *[balloon(f"Balloon{i}", x, FT + 10, z, c) for i, (x, z, c) in enumerate(
            ((-14, 30, "#ff6b8a"), (14, 30, "#5ad1ff"), (-50, 0, "#ffd25a"), (50, 0, "#8ce06a")))],
        plant("PlantA", -52, 50), plant("PlantB", 52, 50), plant("PlantC", -52, -52), plant("PlantD", 52, -52),
    ]))

    def stand(name, x, z, label, color, station, rot=0):
        return model(name, [
            box("Counter", [16, 5, 6], x, z, "#d98c4a"), box("Top", [17, 0.8, 7], x, z, color, y=FT + 5),
            box("PostL", [1, 12, 1], x - 7.5, z + 2.5, "#a0602e"), box("PostR", [1, 12, 1], x + 7.5, z + 2.5, "#a0602e"),
            box("Awning", [18, 1.2, 8], x, z, color, y=FT + 13),
            box("Sign", [16, 4, 0.8], x, z + 3, "#ffffff", y=FT + 8.6,
                children=[sign(label, "Front", color), sign(label, "Back", color)]),
            part("Prompt", [16, 8, 10], [x, FT + 4, z - 6], "#ffffff", collide=False, Transparency=1,
                 attrs={"LobbyStation": station}),
        ])
    kids.append(stand("UpgradeStand", -40, 8, "UPGRADES", "#ff9a3c", "Upgrades"))
    kids.append(stand("EggStand", 40, 8, "PET EGGS", "#5ad1ff", "Eggs"))
    kids.append(stand("CrateStand", -40, -14, "SKINS", "#c070ff", "Crates"))
    kids.append(stand("DailyStand", 40, -14, "DAILY GIFT", "#ff6b8a", "Daily"))
    kids.append(model("RebirthStatue", [
        cyl("Plinth", 12, 4, 0, FT, -46, "#e8e4f0"),
        anim(model("GoldenPoop", [ball("Tier1", 9, 0, FT + 8, -46, "#ffcc33", mat="Foil"),
                                  ball("Tier2", 6.6, 0, FT + 13, -46, "#ffcc33", mat="Foil"),
                                  ball("Tier3", 4, 0, FT + 16.6, -46, "#ffcc33", mat="Foil")]), "Spin"),
        part("Prompt", [14, 10, 14], [0, FT + 5, -46], "#ffffff", collide=False, Transparency=1,
             attrs={"LobbyStation": "Rebirth"}),
    ]))
    def board(name, z, title, color):
        return model(name, [
            box("Frame", [1.2, 22, 26], 58.6, z, color),
            box("Header", [1.4, 3, 26], 58.4, z, color, y=FT + 22, children=[sign(title, "Left", "#ffffff")]),
            box("Board", [0.5, 18, 24], 57.8, z, "#28384f", y=FT + 2, children=[sign("", "Left", "#ffffff")]),
        ])
    kids.append(board("LeaderboardBoard", -34, "ALL TIME", "#c070ff"))
    kids.append(board("LeaderboardDaily", -4, "TODAY", "#ff9a3c"))
    kids.append(board("LeaderboardWeekly", 26, "THIS WEEK", "#5ad1ff"))
    kids.append(folder("Lights", [lamp(f"Lamp{i}", x, FT + h - 4, z) for i, (x, z) in
                                  enumerate(((-30, -30), (30, -30), (-30, 30), (30, 30)))]))
    return model("Lobby", kids)


# ---------------------------------------------------------------- ZONE 1 KITCHEN
def build_zone1():
    cx, cz, size, h = 500, 0, 160, 26
    half = size / 2
    kids = [floor_tiles(cx, cz, size, 10, "#7fd8d0", "#ffffff"),
            room(cx, cz, size, h, "#fff1c9", "#ff8c5a", "#fffaf0", stripe="#7fd8d0")]
    props = []
    cab, top = "#5fc4c0", "#f4f4f8"
    wz = cz - half + 4
    props.append(model("CounterNorth", [box("Cabinets", [110, 5, 8], cx - 15, wz, cab),
                                        box("Top", [112, 0.8, 9], cx - 15, wz, top, y=FT + 5),
                                        box("Backsplash", [110, 8, 0.6], cx - 15, wz - 4.2, "#ffb3a0", y=FT + 5.8),
                                        box("WallCabinets", [110, 7, 5], cx - 15, wz - 1.5, cab, y=FT + 15)], "Counter"))
    props.append(model("Stove", [box("Body", [14, 5.8, 9], cx + 50, wz, "#e8e8f0"),
                                 *[cyl(f"Burner{i}", 3.4, 0.4, cx + 46 + (i % 2) * 8, FT + 5.8, wz - 2 + (i // 2) * 4, "#303038")
                                   for i in range(4)],
                                 box("Hood", [16, 4, 9], cx + 50, wz, "#c8ccd8", y=FT + 16),
                                 box("Oven", [10, 3.6, 0.4], cx + 50, wz + 4.6, "#404050", y=FT + 0.8)], "Stove"))
    props.append(model("Pot", [cyl("Pot", 5, 4, cx + 46, FT + 6.2, wz - 2, "#ff5a5a"),
                               anim(ball("Steam", 3, cx + 46, FT + 12, wz - 2, "#ffffff", collide=False, Transparency=0.4), "Bob")],
                       "Pot"))
    props.append(model("Fridge", [box("Body", [12, 22, 10], cx + 70, cz + 40, "#f0f4ff"),
                                  box("Door", [0.6, 10, 9], cx + 64.2, cz + 40, "#dfe6ff", y=FT + 11.5),
                                  box("Handle", [0.6, 5, 0.8], cx + 63.6, cz + 36, "#9aa0b0", y=FT + 13),
                                  box("Magnet", [0.4, 2, 2], cx + 63.8, cz + 42, "#ff6b8a", y=FT + 15)], "Fridge"))
    props.append(model("Island", [box("Base", [36, 5, 14], cx, cz + 5, "#ff9a7a"),
                                  box("Top", [38, 0.8, 16], cx, cz + 5, top, y=FT + 5),
                                  box("Cake", [6, 3, 6], cx - 10, cz + 5, "#ffb6d0", y=FT + 5.8),
                                  ball("Cherry", 1.2, cx - 10, FT + 9.4, cz + 5, "#ff3a4a"),
                                  box("Bread", [7, 2.4, 3.6], cx + 8, cz + 5, "#e8a85a", y=FT + 5.8),
                                  box("Board", [8, 0.5, 5], cx + 2, cz + 9, "#d98c4a", y=FT + 5.8)], "Island"))
    for i, (x, z) in enumerate(((-55, 30), (-25, 50), (30, 50))):
        props.append(table_set(f"Table{i}", cx + x, cz + z))
    for i, (x, z) in enumerate(((-74, 0), (-74, 25))):
        shelf = [box("Back", [1, 18, 16], cx + x - 2, cz + z, "#a0602e"),
                 box("SideA", [5, 18, 1], cx + x, cz + z - 7.5, "#d98c4a"), box("SideB", [5, 18, 1], cx + x, cz + z + 7.5, "#d98c4a")]
        shelf += [box(f"Board{k}", [5, 0.8, 16], cx + x, cz + z, "#d98c4a", y=FT + k * 6) for k in range(4)]
        shelf += [box(f"Jar{k}", [3, 3.4, 3], cx + x + 0.4, cz + z - 5 + (k % 3) * 5,
                      ["#ff6b6b", "#ffd25a", "#6bd06b"][(k + k // 3) % 3], y=FT + 0.8 + (k // 3) * 6) for k in range(9)]
        props.append(model(f"Shelf{i}", shelf, "Shelf"))
    for i, (x, z) in enumerate(((60, -10), (-40, -30), (70, 66))):
        props.append(model(f"Trash{i}", [cyl("Can", 5, 6, cx + x, FT, cz + z, "#7c8a96"),
                                         cyl("Lid", 5.6, 0.8, cx + x, FT + 6, cz + z, "#5c6a76")], "Trash"))
    props.append(model("Sink", [box("Basin", [12, 1, 7], cx - 35, wz, "#c8d8e8", y=FT + 5.2),
                                box("Tap", [0.8, 4, 0.8], cx - 35, wz - 3, "#b0b8c8", y=FT + 5.8),
                                anim(deco("Drip", [0.6, 0.6, 0.6], [cx - 35, FT + 8, wz - 1.6], "#78c8ff", "Glass"), "Bob")], "Sink"))
    for i, (x, z) in enumerate(((-55, -30), (55, 25), (-10, 66))):
        crate = [box(f"Box{k}", [5, 5, 5], cx + x + (k % 2) * 5.4, cz + z, ["#d98c4a", "#e8a85a"][k % 2], y=FT + (k // 2) * 5)
                 for k in range(3)]
        crate += [ball(f"Fruit{k}", 1.8, cx + x + (k % 2) * 5.4, FT + 5.8 + (k // 2) * 5, cz + z - 1 + k,
                       ["#ff4a4a", "#ffd23a", "#7ad84a"][k % 3]) for k in range(2)]
        props.append(model(f"Crates{i}", crate, "Crate"))
    props.append(model("Microwave", [box("Body", [8, 5, 6], cx - 60, wz, "#f0f0f6", y=FT + 5.8),
                                     box("Door", [5, 3.6, 0.4], cx - 61, wz + 3.1, "#404050", y=FT + 6.5),
                                     anim(deco("Glow", [4.4, 3, 0.2], [cx - 61, FT + 8, wz + 3.4], "#ffd25a", "Neon"), "Pulse")],
                       "Microwave"))
    props.append(model("Toaster", [box("Body", [5, 4, 3.4], cx + 10, wz, "#ff6b6b", y=FT + 5.8),
                                   anim(box("Toast", [3, 2.4, 0.8], cx + 10, wz, "#e8a85a", y=FT + 9, collide=False,
                                            CanQuery=False, CanTouch=False), "Jet")], "Toaster"))
    props.append(model("DogBed", [cyl("Rug", 26, 0.3, cx + 45, FT, cz + 66, "#ff9ad5", collide=True),
                                  cyl("Bed", 12, 2.4, cx + 45, FT + 0.3, cz + 66, "#5ad1ff"),
                                  cyl("Cushion", 9, 1, cx + 45, FT + 2.7, cz + 66, "#ffffff"),
                                  cyl("Bowl", 4, 1.4, cx + 56, FT + 0.3, cz + 60, "#ff6b6b")], "DogBed"))
    props.append(model("Clock", [part("Face", [1, 10, 10], [cx, FT + 20, cz + 79.4], "#ffffff", rot=rot_y(90), shape="Cylinder"),
                                 deco("Hand", [0.6, 4, 0.4], [cx, FT + 21.6, cz + 78.6], "#202028")], "Clock"))
    props.append(plant("PlantA", cx + 72, cz - 60))
    props.append(plant("PlantB", cx - 70, cz + 66))
    props.append(model("Sign", [part("Board", [30, 6, 1], [cx, FT + 20, cz + half - 0.8], "#ffd25a",
                                     children=[sign("ZONE 1 - KITCHEN", "Back", "#ffffff")])]))
    lights = [ceiling_fan(f"Fan{i}", cx + x, FT + h - 5, cz + z) for i, (x, z) in enumerate(((-35, -10), (35, -10), (0, 45)))]
    lights += [lamp(f"Lamp{i}", cx + x, FT + h - 3, cz + z) for i, (x, z) in enumerate(((-10, 5), (10, 5)))]
    props.append(folder("Animated", lights))
    npcs = [human("NPC_Chef1", cx - 20, cz - 20, "#ffffff", hat="#ffffff", hat_h=2.4),
            human("NPC_Chef2", cx + 25, cz - 20, "#ffffff", hat="#ffffff", hat_h=2.4),
            critter("NPC_Cat", cx - 40, cz + 10, "#ffa64a", "#d9772a"),
            critter("NPC_Dog", cx + 40, cz + 25, "#f0d8b0", "#a06a3a", 1.2)]
    patrol("Zone1", "NPC_Chef1", (cx - 20, cz - 22), (cx - 20, cz + 30), 8)
    patrol("Zone1", "NPC_Chef2", (cx + 25, cz - 22), (cx + 25, cz + 32), 9)
    patrol("Zone1", "NPC_Cat", (cx - 60, cz - 15), (cx - 25, cz - 15), 12)
    patrol("Zone1", "NPC_Dog", (cx + 15, cz + 66), (cx + 60, cz + 66), 11)
    return model("Zone1", [*kids, model("Props", props), folder("NPCs", npcs), play_area(cx, cz, size, h)])


# ---------------------------------------------------------------- ZONE 2 MALL
def storefront(name, x, z, face, color, label, w=40, depth=10, h=22):
    out = []
    zf = z + (depth / 2 if face == "S" else -depth / 2)
    out.append(box("Frame", [w, h, depth], x, z, color))
    out.append(box("Window", [w - 8, h - 9, 0.6], x, zf + (0.4 if face == "S" else -0.4), "#bfe8ff", y=FT + 2,
                   mat="Glass", Transparency=0.15))
    out.append(box("Sign", [w - 6, 5, 1], x, zf + (0.8 if face == "S" else -0.8), "#2a2040", y=FT + h - 6.5,
                   children=[sign(label, "Back" if face == "S" else "Front", "#ffffff", stroke=color)]))
    out.append(anim(box("SignGlow", [w - 4, 0.6, 1.2], x, zf + (0.8 if face == "S" else -0.8), color, y=FT + h - 7.4,
                        mat="Neon", collide=False, CanQuery=False, CanTouch=False), "Pulse"))
    out.append(box("Awning", [w, 1, 5], x, zf + (2.5 if face == "S" else -2.5), "#ffffff", y=FT + h - 9))
    return model(name, out, "Storefront")


def mannequin(name, x, z, outfit):
    return model(name, [cyl("Stand", 3, 0.5, x, FT, z, "#c8ccd8"), box("Pole", [0.4, 2.6, 0.4], x, z, "#c8ccd8", y=FT + 0.5),
                        box("Body", [2.8, 4, 1.6], x, z, outfit, y=FT + 3), ball("Head", 2, x, FT + 8.2, z, "#f4f4f8")],
                 "Mannequin")


def rack(name, x, z, colors):
    kids = [box("Bar", [10, 0.5, 0.5], x, z, "#b0b8c8", y=FT + 7), box("PostL", [0.5, 7, 0.5], x - 4.8, z, "#b0b8c8"),
            box("PostR", [0.5, 7, 0.5], x + 4.8, z, "#b0b8c8"), box("Foot", [11, 0.6, 3], x, z, "#b0b8c8")]
    kids += [box(f"Shirt{i}", [1.2, 4, 3], x - 3.6 + i * 1.8, z, c, y=FT + 2.8) for i, c in enumerate(colors)]
    return model(name, kids, "ClothesRack")


def build_zone2():
    cx, cz, size, h = 1000, 0, 240, 36
    half = size / 2
    kids = [floor_tiles(cx, cz, size, 12, "#ffe0ec", "#ffffff", pattern="grid"),
            room(cx, cz, size, h, "#c7b8ff", "#ffffff", "#f6f2ff", stripe="#ff8fb8")]
    props = []
    shops = [("ShopToys", "TOYS", "#ff6b6b"), ("ShopShoes", "SHOES", "#5ad1ff"), ("ShopCandy", "CANDY", "#ff9ad5"),
             ("ShopGames", "GAMES", "#8ce06a"), ("ShopBooks", "BOOKS", "#ffb43c"), ("ShopPets", "PETS", "#a07cff")]
    for i, (nm, lb, col) in enumerate(shops[:3]):
        props.append(storefront(nm, cx - 75 + i * 75, cz - half + 5, "S", col, lb))
    for i, (nm, lb, col) in enumerate(shops[3:]):
        props.append(storefront(nm, cx - 75 + i * 75, cz + half - 5, "N", col, lb))
    props.append(fountain("Fountain", cx, cz, 1.4, water="#ff9ad5"))
    for i, (x, z, c) in enumerate(((-40, -40, "#ff6b6b"), (40, -40, "#5ad1ff"), (-40, 40, "#8ce06a"), (40, 40, "#ffd25a"),
                                   (-90, 0, "#c070ff"), (90, 0, "#ff9a3c"))):
        props.append(mannequin(f"Mannequin{i}", cx + x, cz + z, c))
    for i, (x, z) in enumerate(((-70, -55), (70, -55), (-70, 55), (70, 55))):
        props.append(rack(f"Rack{i}", cx + x, cz + z, ["#ff6b6b", "#ffd25a", "#5ad1ff", "#8ce06a", "#ff9ad5"]))
    for i, (x, z, r) in enumerate(((-30, 0, 90), (30, 0, 90), (0, -30, 0), (0, 30, 0))):
        props.append(bench(f"Bench{i}", cx + x * 1.4, cz + z * 1.4, r, wood="#ff8fb8"))
    props.append(model("Kiosk", [cyl("Base", 14, 5, cx + 80, FT, cz - 30, "#ffd25a"),
                                 cyl("Top", 15, 0.8, cx + 80, FT + 5, cz - 30, "#ffffff"),
                                 box("Pole", [1, 12, 1], cx + 80, cz - 30, "#ffffff", y=FT + 5.8),
                                 anim(cyl("Umbrella", 18, 1.2, cx + 80, FT + 17.8, cz - 30, "#ff6b6b"), "Spin")], "Kiosk"))
    esc = []
    ex, ez = cx - 95, cz + 30
    for i in range(10):
        esc.append(box(f"Step{i}", [12, 1.2 + i * 1.6, 3], ex, ez - 14 + i * 3, "#c8ccd8"))
    esc.append(box("Landing", [24, 17, 20], ex + 6, ez + 25, "#c7b8ff"))
    esc.append(box("RailL", [0.6, 3, 32], ex - 6.3, ez + 1, "#5ad1ff", y=FT + 10, mat="Glass", Transparency=0.3))
    props.append(model("Escalator", esc, "Escalator"))
    for i in range(8):
        a = i / 8 * math.tau
        props.append(balloon(f"Balloon{i}", cx + math.cos(a) * 26, FT + 14, cz + math.sin(a) * 26,
                             ["#ff6b6b", "#ffd25a", "#5ad1ff", "#8ce06a"][i % 4]))
    props += [plant(f"Plant{i}", cx + x, cz + z, 1.2) for i, (x, z) in enumerate(((-108, -60), (108, -60), (-108, 60), (108, 60)))]
    for i, (x, z) in enumerate(((40, 80), (55, 95), (70, 80), (85, 95))):
        props.append(table_set(f"FoodTable{i}", cx + x - 10, cz + z - 8, top="#ffd25a", chair="#ff6b6b", w=7, d=7))
    for i, c in enumerate(("#ff6b6b", "#5ad1ff", "#8ce06a")):
        vx, vz = cx - 112, cz - 90 + i * 9
        props.append(model(f"Vending{i}", [box("Body", [7, 14, 8], vx, vz, c),
                                           box("Glass", [0.4, 8, 6], vx + 3.6, vz, "#bfe8ff", y=FT + 4.5, mat="Glass", Transparency=0.2),
                                           anim(deco("Glow", [0.3, 1.6, 6], [vx + 3.8, FT + 13, vz], "#ffffff", "Neon"), "Pulse")],
                           "VendingMachine"))
    props.append(model("TeddyDisplay", [cyl("Pedestal", 16, 3, cx - 40, FT, cz - 85, "#ff9ad5"),
                                        anim(model("Teddy", [ball("Body", 9, cx - 40, FT + 8, cz - 85, "#c88a4a"),
                                                             ball("Head", 7, cx - 40, FT + 14.5, cz - 85, "#c88a4a"),
                                                             ball("EarL", 2.6, cx - 42.8, FT + 17.4, cz - 85, "#a06a3a"),
                                                             ball("EarR", 2.6, cx - 37.2, FT + 17.4, cz - 85, "#a06a3a"),
                                                             ball("Snout", 3, cx - 40, FT + 13.6, cz - 88, "#f0d8b0")]), "SpinSlow")],
                       "Display"))
    props.append(model("SneakerDisplay", [cyl("Pedestal", 14, 3, cx + 40, FT, cz - 85, "#5ad1ff"),
                                          anim(model("Sneaker", [box("Sole", [5, 1.4, 11], cx + 40, cz - 85, "#ffffff", y=FT + 4),
                                                                 box("Upper", [5, 4, 8], cx + 40, cz - 84, "#ff6b6b", y=FT + 5.4),
                                                                 box("Lace", [5.2, 0.6, 3], cx + 40, cz - 87, "#ffffff", y=FT + 8)]),
                                               "SpinSlow")], "Display"))
    for i, (x, z) in enumerate(((-20, 60), (20, -62), (75, 20))):
        props.append(model(f"Cart{i}", [box("Basket", [5, 4, 8], cx + x, cz + z, "#b0b8c8", y=FT + 2.4),
                                        box("Handle", [5, 0.5, 0.5], cx + x, cz + z + 4.4, "#ff6b6b", y=FT + 6.6),
                                        box("Bag", [3, 3, 3], cx + x, cz + z - 1, "#ffd25a", y=FT + 6.4)], "ShoppingCart"))
    props.append(model("Sign", [part("Board", [40, 7, 1], [cx, FT + 28, cz + half - 0.8], "#ff8fb8",
                                     children=[sign("ZONE 2 - SHOPPING MALL", "Back", "#ffffff")])]))
    props.append(folder("Animated", [lamp(f"Lamp{i}", cx + x, FT + h - 3, cz + z, "#ffe0f0")
                                     for i, (x, z) in enumerate(((-60, -30), (60, -30), (-60, 30), (60, 30), (0, -70), (0, 70)))]))
    npcs = [human("NPC_Shopper1", cx - 50, cz - 70, "#ff6b8a", hat="#ffd25a", hat_h=0.6),
            human("NPC_Shopper2", cx + 50, cz + 70, "#5ad1ff"),
            human("NPC_Guard1", cx - 100, cz, "#3a4a8a", hat="#2a3260", scale=1.15),
            human("NPC_Guard2", cx + 100, cz, "#3a4a8a", hat="#2a3260", scale=1.15),
            human("NPC_Kid", cx, cz - 45, "#8ce06a", scale=0.75)]
    patrol("Zone2", "NPC_Shopper1", (cx - 90, cz - 70), (cx + 90, cz - 70), 9)
    patrol("Zone2", "NPC_Shopper2", (cx - 90, cz + 72), (cx + 90, cz + 72), 9)
    patrol("Zone2", "NPC_Guard1", (cx - 100, cz - 80), (cx - 100, cz + 10), 7)
    patrol("Zone2", "NPC_Guard2", (cx + 100, cz - 80), (cx + 100, cz + 80), 7)
    patrol("Zone2", "NPC_Kid", (cx - 60, cz - 45), (cx + 60, cz - 45), 13)
    return model("Zone2", [*kids, model("Props", props), folder("NPCs", npcs), play_area(cx, cz, size, h)])


# ---------------------------------------------------------------- ZONE 3 PARK
def build_zone3():
    cx, cz, size, h = 1600, 0, 300, 24
    half = size / 2
    grass = model("Floor", [part("Grass", [size, 2, size], [cx, FT - 1, cz], "#7ed957", "Grass"),
                            part("PathX", [size, 0.2, 18], [cx, FT + 0.1, cz], "#f2d7a0", "Sand"),
                            part("PathZ", [18, 0.2, size], [cx, FT + 0.1, cz], "#f2d7a0", "Sand"),
                            part("Pond", [50, 0.3, 36], [cx + 85, FT + 0.15, cz - 85], "#5ac8ff", "Glass", Transparency=0.15)])
    hedge = room(cx, cz, size, h, "#4cae4c", "#3a8e3a", "#ffffff", ceiling_on=False, wall_mat="LeafyGrass")
    props = [fountain("Fountain", cx, cz, 1.6)]
    for i in range(16):
        a = i / 16 * math.tau + 0.2
        r = 95 + (i % 3) * 18
        x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
        if abs(x - (cx + 85)) < 32 and abs(z - (cz - 85)) < 26:
            continue
        props.append(tree(f"Tree{i}", x, z, 0.9 + (i % 3) * 0.15, ["#5cc85a", "#7ad84a", "#4cb86a"][i % 3]))
    for i, (x, z, r) in enumerate(((-30, -18, 0), (30, -18, 0), (-30, 18, 180), (30, 18, 180), (-18, -60, 90), (18, 60, 270))):
        props.append(bench(f"Bench{i}", cx + x, cz + z, r))
    ix, iz = cx - 60, cz + 40
    props.append(model("IceCreamCart", [
        box("Cart", [14, 6, 7], ix, iz, "#ffffff", y=FT + 2), cyl("WheelL", 4, 1, ix - 5, FT, iz + 3.8, "#404050"),
        box("Stripe", [14.2, 1.4, 7.2], ix, iz, "#ff9ad5", y=FT + 5),
        anim(model("Cone", [part("Cone", [2.6, 4, 2.6], [ix, FT + 10, iz], "#e8a85a", cls="WedgePart"),
                            ball("Scoop", 3.6, ix, FT + 13, iz, "#ffb6d0")]), "Spin"),
        box("Pole", [0.6, 10, 0.6], ix + 6, iz, "#ffffff", y=FT + 8),
        cyl("Umbrella", 14, 1, ix + 6, FT + 18, iz, "#5ad1ff")], "IceCreamCart"))
    sx, sz = cx + 60, cz + 55
    props.append(model("Slide", [
        box("Tower", [10, 14, 10], sx, sz, "#ffd25a"), box("Roof", [12, 1.4, 12], sx, sz, "#ff6b6b", y=FT + 22),
        box("PostA", [1, 8, 1], sx - 5, sz - 5, "#ff6b6b", y=FT + 14), box("PostB", [1, 8, 1], sx + 5, sz + 5, "#ff6b6b", y=FT + 14),
        wedge("Chute", [8, 14, 24], [sx, FT + 7, sz - 17], "#5ad1ff", rot=rot_y(0)),
        box("Ladder", [6, 14, 1], sx, sz + 5.5, "#8ce06a")], "Slide"))
    wx, wz = cx + 60, cz + 100
    props.append(model("SwingSet", [
        box("Beam", [26, 1.2, 1.2], wx, wz, "#ff6b6b", y=FT + 14), box("LegL", [1.2, 14, 1.2], wx - 12.5, wz, "#ff6b6b"),
        box("LegR", [1.2, 14, 1.2], wx + 12.5, wz, "#ff6b6b"),
        anim(model("SwingA", [deco("Rope", [0.3, 10, 0.3], [wx - 5, FT + 9, wz], "#ffffff"),
                              box("Seat", [4, 0.6, 2], wx - 5, wz, "#ffd25a", y=FT + 3.6)]), "Swing"),
        anim(model("SwingB", [deco("Rope", [0.3, 10, 0.3], [wx + 5, FT + 9, wz], "#ffffff"),
                              box("Seat", [4, 0.6, 2], wx + 5, wz, "#5ad1ff", y=FT + 3.6)]), "Swing")], "Swing"))
    kx, kz = cx - 70, cz - 60
    horses = [box(f"Horse{i}", [2, 4, 5], kx + math.cos(i / 6 * math.tau) * 10, kz + math.sin(i / 6 * math.tau) * 10,
                  ["#ff6b6b", "#ffd25a", "#5ad1ff", "#8ce06a", "#ff9ad5", "#c070ff"][i], y=FT + 3, collide=False,
                  CanQuery=False, CanTouch=False) for i in range(6)]
    props.append(model("Carousel", [cyl("Platform", 26, 2, kx, FT, kz, "#ffffff"),
                                    box("Pole", [2, 16, 2], kx, kz, "#ffd25a", y=FT + 2),
                                    anim(model("Spinner", [cyl("Roof", 28, 2, kx, FT + 18, kz, "#ff6b6b", collide=False,
                                                               CanQuery=False, CanTouch=False), *horses]), "SpinSlow")], "Carousel"))
    props.append(model("Statue", [box("Plinth", [10, 6, 10], cx - 100, cz + 100, "#e8e4f0"),
                                  ball("Body", 8, cx - 100, FT + 10, cz + 100, "#b0b8c8", mat="Marble"),
                                  ball("Head", 5, cx - 100, FT + 16, cz + 100, "#b0b8c8", mat="Marble")], "Statue"))
    for i, (x, z) in enumerate(((-40, -40), (40, -40), (-40, 40), (40, 40))):
        flowers = [ball(f"F{k}", 2, cx + x - 6 + (k % 4) * 4, FT + 2.2, cz + z - 3 + (k // 4) * 4,
                        ["#ff6b8a", "#ffd25a", "#c070ff", "#ffffff"][k % 4]) for k in range(8)]
        props.append(model(f"Flowerbed{i}", [box("Bed", [18, 1.6, 10], cx + x, cz + z, "#9a6234"), *flowers], "Flowerbed"))
    lamps = []
    for i, (x, z) in enumerate(((-15, -40), (15, 40), (-60, -12), (60, 12), (-120, 12), (120, -12))):
        lamps.append(model(f"LampPost{i}", [box("Post", [1, 14, 1], cx + x, cz + z, "#3a4050"),
                                            anim(ball("Bulb", 3, cx + x, FT + 15, cz + z, "#fff2b0", mat="Neon",
                                                      collide=False, CanQuery=False, CanTouch=False), "Pulse")]))
    props.append(folder("Animated", lamps + [balloon(f"Balloon{i}", cx - 60 + i * 3, FT + 12, cz + 46, c)
                                             for i, c in enumerate(("#ff6b6b", "#ffd25a", "#5ad1ff"))]))
    props.append(model("Sign", [part("Board", [40, 7, 1], [cx, FT + 18, cz + half - 0.8], "#ffd25a",
                                     children=[sign("ZONE 3 - PARK", "Back", "#ffffff")])]))
    npcs = [human("NPC_Staff1", cx - 30, cz - 9, "#ff9a3c", hat="#ff9a3c", hat_h=0.6),
            human("NPC_Staff2", cx + 30, cz + 9, "#8ce06a", hat="#ff9a3c", hat_h=0.6),
            human("NPC_IceCream", cx - 60, cz + 50, "#ffffff", hat="#ff9ad5", hat_h=1.6),
            human("NPC_Jogger", cx, cz - 120, "#ff6b8a"),
            critter("NPC_Dog", cx + 20, cz + 80, "#c88a4a", "#7a4a22", 1.3),
            human("NPC_Kid", cx + 9, cz - 30, "#5ad1ff", scale=0.75)]
    patrol("Zone3", "NPC_Staff1", (cx - 130, cz - 9), (cx - 25, cz - 9), 9)
    patrol("Zone3", "NPC_Staff2", (cx + 25, cz + 9), (cx + 130, cz + 9), 9)
    patrol("Zone3", "NPC_IceCream", (cx - 80, cz + 52), (cx - 40, cz + 52), 6)
    patrol("Zone3", "NPC_Jogger", (cx - 130, cz - 125), (cx + 130, cz - 125), 15)
    patrol("Zone3", "NPC_Dog", (cx + 9, cz + 30), (cx + 9, cz + 130), 13)
    patrol("Zone3", "NPC_Kid", (cx - 9, cz - 30), (cx - 9, cz - 130), 11)
    return model("Zone3", [grass, hedge, model("Props", props), folder("NPCs", npcs), play_area(cx, cz, size, h)])


# ---------------------------------------------------------------- ZONE 4 HOTEL
def build_zone4():
    cx, cz, size, h = 2400, 0, 340, 40
    half = size / 2
    kids = [floor_tiles(cx, cz, size, 17, "#f6e7c8", "#fffaf0", mat="Marble"),
            room(cx, cz, size, h, "#ffd9b8", "#c89a3a", "#fff6e6", stripe="#c84a5a")]
    props = [model("RedCarpet", [part("Carpet", [24, 0.3, size - 20], [cx, FT + 0.15, cz], "#d8404c", "Fabric"),
                                 part("EdgeL", [1, 0.35, size - 20], [cx - 12.5, FT + 0.17, cz], "#ffcc33", "Fabric"),
                                 part("EdgeR", [1, 0.35, size - 20], [cx + 12.5, FT + 0.17, cz], "#ffcc33", "Fabric")], "Carpet")]
    rx, rz = cx, cz - half + 30
    props.append(model("Reception", [box("Desk", [60, 7, 10], rx, rz, "#a0602e"), box("Top", [62, 1, 11], rx, rz, "#ffcc33", y=FT + 7),
                                     box("Bell", [1.6, 1.2, 1.6], rx + 10, rz, "#ffcc33", y=FT + 8),
                                     box("KeyWall", [50, 16, 1], rx, rz - 10, "#7a4a22", y=FT + 6,
                                         children=[sign("GRAND POOP HOTEL", "Back", "#ffcc33")])], "Reception"))
    for i, (x, z) in enumerate(((-60, -60), (60, -60), (-60, 60), (60, 60))):
        props.append(model(f"Pillar{i}", [cyl("Base", 10, 2, cx + x, FT, cz + z, "#ffcc33"),
                                          cyl("Shaft", 7, h - 4, cx + x, FT + 2, cz + z, "#fffaf0", mat="Marble"),
                                          cyl("Capital", 10, 2, cx + x, FT + h - 2, cz + z, "#ffcc33")], "Pillar"))
    for i, (x, z) in enumerate(((-120, -100), (-120, -40), (-120, 20))):
        props.append(model(f"Bed{i}", [box("Frame", [22, 3, 14], cx + x, cz + z, "#a0602e"),
                                       box("Mattress", [21, 2.6, 13], cx + x, cz + z, "#ffffff", y=FT + 3),
                                       box("Blanket", [14, 0.6, 13.4], cx + x + 3, cz + z, "#5a8aff", y=FT + 5.5),
                                       box("Pillow", [4, 1.4, 9], cx + x - 8, cz + z, "#fff6e6", y=FT + 5.6),
                                       box("Headboard", [1.4, 9, 14], cx + x - 11, cz + z, "#7a4a22")], "Bed"))
    for i, (x, z) in enumerate(((-45, 100), (45, 100), (100, -20))):
        props.append(model(f"Sofa{i}", [box("Seat", [18, 3.4, 8], cx + x, cz + z, "#c84a5a"),
                                        box("Back", [18, 5, 2], cx + x, cz + z + 3.5, "#c84a5a", y=FT + 3.4),
                                        box("ArmL", [2, 5, 8], cx + x - 9, cz + z, "#a83a4a"),
                                        box("ArmR", [2, 5, 8], cx + x + 9, cz + z, "#a83a4a")], "Sofa"))
    for i, (x, z) in enumerate(((40, -100), (-30, 40), (120, 80))):
        lx, lz = cx + x, cz + z
        props.append(model(f"LuggageCart{i}", [box("Base", [10, 1, 6], lx, lz, "#ffcc33", y=FT + 1.4),
                                               box("ArchL", [0.6, 10, 0.6], lx - 4.7, lz, "#ffcc33", y=FT + 2.4),
                                               box("ArchR", [0.6, 10, 0.6], lx + 4.7, lz, "#ffcc33", y=FT + 2.4),
                                               box("ArchTop", [10, 0.6, 0.6], lx, lz, "#ffcc33", y=FT + 12.2),
                                               box("Suitcase1", [4, 5, 2.6], lx - 2.2, lz, "#ff6b6b", y=FT + 2.4),
                                               box("Suitcase2", [3.6, 4, 2.6], lx + 2.2, lz, "#5ad1ff", y=FT + 2.4),
                                               box("Bag", [3, 2.6, 2.6], lx, lz, "#8ce06a", y=FT + 7.4)], "LuggageCart"))
    props.append(model("Piano", [box("Body", [14, 5, 9], cx + 110, cz + 100, "#202028", y=FT + 3),
                                 box("Keys", [12, 0.5, 2], cx + 110, cz + 95, "#ffffff", y=FT + 7.4),
                                 box("Lid", [14, 0.4, 9], cx + 110, cz + 102, "#202028", y=FT + 10, rot=rot_x(-25)),
                                 box("Leg", [1, 3, 1], cx + 105, cz + 100, "#202028")], "Piano"))
    props.append(fountain("Fountain", cx, cz + 20, 1.5, stone="#fffaf0", water="#6cd0ff"))
    for i in range(6):
        props.append(table_set(f"DiningTable{i}", cx + 95 + (i % 2) * 34, cz - 125 + (i // 2) * 30,
                               top="#ffffff", leg="#ffcc33", chair="#c84a5a", w=10, d=8))
    for i, (x, z) in enumerate(((-120, 80), (-120, 140))):
        props.append(model(f"Bed{i + 3}", [box("Frame", [22, 3, 14], cx + x, cz + z, "#a0602e"),
                                           box("Mattress", [21, 2.6, 13], cx + x, cz + z, "#ffffff", y=FT + 3),
                                           box("Blanket", [14, 0.6, 13.4], cx + x + 3, cz + z, "#ff9ad5", y=FT + 5.5),
                                           box("Pillow", [4, 1.4, 9], cx + x - 8, cz + z, "#fff6e6", y=FT + 5.6),
                                           box("Headboard", [1.4, 9, 14], cx + x - 11, cz + z, "#7a4a22")], "Bed"))
    for i, (x, z) in enumerate(((-70, 110), (60, -150), (140, 150))):
        props.append(model(f"Rug{i}", [cyl("Rug", 26, 0.3, cx + x, FT, cz + z, ["#5a8aff", "#8ce06a", "#c070ff"][i]),
                                       cyl("CoffeeTable", 8, 3, cx + x, FT + 0.3, cz + z, "#a0602e"),
                                       box("Vase", [1.6, 2.4, 1.6], cx + x, cz + z, "#ff6b6b", y=FT + 3.3)], "Table"))
    props += [plant(f"Plant{i}", cx + x, cz + z, 1.3, pot="#ffcc33") for i, (x, z) in
              enumerate(((-150, -150), (150, -150), (-150, 150), (150, 150), (-20, -130), (20, -130)))]
    props.append(model("Elevators", [box(f"Door{i}", [16, 22, 1.2], cx + 168, cz - 60 + i * 40, "#ffcc33", rot=rot_y(90))
                                     for i in range(3)], "Elevator"))
    chand = []
    for i, (x, z) in enumerate(((0, -60), (0, 60), (-80, 0), (80, 0))):
        px, pz, py = cx + x, cz + z, FT + h - 6
        crystals = [deco(f"Crystal{k}", [1.2, 3, 1.2], [px + math.cos(k / 8 * math.tau) * 5, py - 1, pz + math.sin(k / 8 * math.tau) * 5],
                         "#ffffff", "Glass", Transparency=0.2) for k in range(8)]
        chand.append(folder(f"Chandelier{i}", [deco("Chain", [0.4, 5, 0.4], [px, py + 3.5, pz], "#ffcc33"),
                                                anim(model("Ring", [deco("Hoop", [12, 1, 12], [px, py, pz], "#ffcc33"),
                                                                    deco("Core", [3, 3, 3], [px, py, pz], "#fff2b0", "Neon",
                                                                         children=[light("#fff2b0", 50, 1)]), *crystals]),
                                                     "SpinSlow")]))
    props.append(folder("Animated", chand))
    props.append(model("Sign", [part("Board", [44, 7, 1], [cx, FT + 30, cz + half - 0.8], "#c84a5a",
                                     children=[sign("ZONE 4 - HOTEL", "Back", "#ffcc33")])]))
    npcs = [human("NPC_Butler1", cx - 20, cz - 60, "#202028", hat=None),
            human("NPC_Butler2", cx + 20, cz + 60, "#202028", hat=None),
            human("NPC_Bellhop", cx - 40, cz, "#c84a5a", hat="#c84a5a", hat_h=1.4),
            human("NPC_Guest1", cx + 80, cz + 40, "#5a8aff"),
            human("NPC_Guest2", cx - 90, cz + 120, "#ffd25a", hat="#ff9ad5", hat_h=0.6),
            human("NPC_Maid", cx + 130, cz - 120, "#ffffff", hat="#ffffff", hat_h=0.6)]
    patrol("Zone4", "NPC_Butler1", (cx - 20, cz - 120), (cx - 20, cz + 140), 9)
    patrol("Zone4", "NPC_Butler2", (cx + 20, cz - 120), (cx + 20, cz + 140), 9)
    patrol("Zone4", "NPC_Bellhop", (cx - 150, cz), (cx - 30, cz), 11)
    patrol("Zone4", "NPC_Guest1", (cx + 30, cz + 40), (cx + 150, cz + 40), 7)
    patrol("Zone4", "NPC_Guest2", (cx - 150, cz + 120), (cx - 30, cz + 120), 8)
    patrol("Zone4", "NPC_Maid", (cx + 60, cz - 120), (cx + 150, cz - 120), 10)
    return model("Zone4", [*kids, model("Props", props), folder("NPCs", npcs), play_area(cx, cz, size, h)])


maps = {"Lobby": build_lobby(), "Zone1": build_zone1(), "Zone2": build_zone2(), "Zone3": build_zone3(), "Zone4": build_zone4()}
for name, data in maps.items():
    data.pop("name")
    with open(f"{ROOT}/src/workspace/{name}.model.json", "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
        fh.write("\n")


def count(n):
    return 1 + sum(count(c) for c in n.get("children", []))


def types(n, acc):
    t = n.get("attributes", {}).get("ObjectType")
    if t:
        acc.add(t)
    for c in n.get("children", []):
        types(c, acc)
    return acc


print({k: count(v) for k, v in maps.items()})
print(sorted(types({"children": list(maps.values())}, set())))
print("RunConfig.NpcPatrols = {")
for zone, items in PATROLS.items():
    print(f'\t["{zone}"] = {{')
    for nm, a, b, sp in items:
        print(f'\t\t{{ name = "{nm}", startPos = Vector3.new({a[0]:g}, 3.5, {a[1]:g}), endPos = Vector3.new({b[0]:g}, 3.5, {b[1]:g}), speed = {sp} }},')
    print("\t},")
print("}")
