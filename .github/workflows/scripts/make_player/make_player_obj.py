from enum import Enum
from pathlib import Path
import subprocess
from typing import Generator, TextIO
import numpy as np
from numpy.typing import NDArray
from dataclasses import dataclass
import itertools

class FaceDirection(Enum):
    TOP = 0
    BOTTOM = 1
    RIGHT = 2
    FRONT = 3
    LEFT = 4
    BACK = 5

""" DIRECTION_2_VERTEXORDER uses the following corner numbering
#     ^ Up (+Y)    Towards Face (+Z)
#                 /
#     5------4
#    /|     /|
#   1------0 |    -> Right (+X)
#   | |    | |
#   | 6----|-7
#   |/     |/
#   2------3
#
"""
DIRECTION_2_VERTEXORDER = {
    FaceDirection.TOP:    (4,5,1,0),
    FaceDirection.BOTTOM: (3,2,6,7),
    FaceDirection.RIGHT:  (1,5,6,2),
    FaceDirection.FRONT:  (0,1,2,3),
    FaceDirection.LEFT:   (4,0,3,7),
    FaceDirection.BACK:   (5,4,7,6),
}

@dataclass
class BodyPart:
    # some name
    name: str
    # TOP LEFT of the UV square
    origin_uv: tuple[int,int]
    # width,height,depth (x,y,z)
    axis_sizes: tuple[int,int,int]
    # 3d CENTER of the cuboid
    origin_3d_center: tuple[int,int,int]
    #
    scale_3d: float

@dataclass
class ObjCounters:
    v: int
    vt: int
    vn: int
    fid: int

OVERLAY_SCALE = 1.125

# ORDER MATTERS!!!
#            id  name     uv TL     size      3d center  3d scale
PARTS_STEVE = [
    BodyPart("Head",  ( 0, 0),  (8, 8,8), ( 0,28,0), 1),
    BodyPart("Body",  (16,16),  (8,12,4), ( 0,18,0), 1),
    BodyPart("LArm",  (40,16),  (4,12,4), (-6,18,0), 1),
    BodyPart("RArm",  (32,48),  (4,12,4), ( 6,18,0), 1),
    BodyPart("LLeg",  ( 0,16),  (4,12,4), (-2, 6,0), 1),
    BodyPart("RLeg",  (16,48),  (4,12,4), ( 2, 6,0), 1),
    BodyPart("oHead", (32, 0),  (8, 8,8), ( 0,28,0), OVERLAY_SCALE),
    BodyPart("oRLeg", ( 0, 48), (4,12,4), ( 2, 6,0), OVERLAY_SCALE),
    BodyPart("oLLeg", ( 0, 32), (4,12,4), (-2, 6,0), OVERLAY_SCALE),
    BodyPart("oRArm", (48, 48), (4,12,4), ( 6,18,0), OVERLAY_SCALE),
    BodyPart("oLArm", (40, 32), (4,12,4), (-6,18,0), OVERLAY_SCALE),
    BodyPart("oBody", (16, 32), (8,12,4), ( 0,18,0), OVERLAY_SCALE),
]
PARTS_ALEX = [
    BodyPart("Head",  ( 0, 0),  (8, 8,8), ( 0,28,0), 1),
    BodyPart("Body",  (16,16),  (8,12,4), ( 0,18,0), 1),
    BodyPart("LArm",  (40,16),  (3,12,4), (-6,18,0), 1),
    BodyPart("RArm",  (32,48),  (3,12,4), ( 6,18,0), 1),
    BodyPart("LLeg",  ( 0,16),  (4,12,4), (-2, 6,0), 1),
    BodyPart("RLeg",  (16,48),  (4,12,4), ( 2, 6,0), 1),
    BodyPart("oHead", (32, 0),  (8, 8,8), ( 0,28,0), OVERLAY_SCALE),
    BodyPart("oRLeg", ( 0, 48), (4,12,4), ( 2, 6,0), OVERLAY_SCALE),
    BodyPart("oLLeg", ( 0, 32), (4,12,4), (-2, 6,0), OVERLAY_SCALE),
    BodyPart("oRArm", (48, 48), (3,12,4), ( 6,18,0), OVERLAY_SCALE),
    BodyPart("oLArm", (40, 32), (3,12,4), (-6,18,0), OVERLAY_SCALE),
    BodyPart("oBody", (16, 32), (8,12,4), ( 0,18,0), OVERLAY_SCALE),
]

def run():
    parts = PARTS_STEVE

    generateCssGrid(parts)
    generateSodiumVertIdFixer()

    # Handrolling some .obj file because we need very specific vertex ordering
    with open("C:/Users/wilux/AppData/Roaming/.minecraft/resourcepacks/synhat-dev/web_editor/assets/steve.obj", "w+") as f:
        f.write("# Made by Wilux\n")
        f.write("mtllib steve.mtl\n\n")

        counters = ObjCounters(1,1,1,1)
        for part in parts:
            #f.write(f"o {name}\n")
            writeCube(f, part, counters)

def generateCssGrid(parts: list[BodyPart]):
    pixelgrid = [[f".   " for _ in range(64)] for _ in range(64)]
    for i in range(6):
        dirId = FaceDirection(i)
        for cubeId, part in enumerate(parts):
            uvids = faceDir_counterClockwiseCornerUVIds(dirId, 0)
            uvId2Coord = body_cornerUvs(part)
            a = [uvId2Coord[uvid] for uvid in uvids]
            us, vs = zip(*a)

            umin, vmin = (min(us), min(vs))
            umax, vmax = (max(us), max(vs))

            faceId = cubeId*6 + i

            for u in range(umin, umax):
                for v in range(vmin, vmax):
                    pixelgrid[v][u] = f"fi{faceId:>02}"

    with open("cssgridcode.txt", "w+") as f:
        for line in pixelgrid:
            f.write(f'\"{" ".join(line)}\"\n')

import perfect_hash
def generateSodiumVertIdFixer():
    """ Unfortunately using sodium mirrors the vertex ids, this code generates GLSL
        code that peeks the UV to figure out if its the left or right face being rendered
    """
    @dataclass(frozen=True, order=True)
    class Key:
        vertId: int # not part of the hash, for sorting
        u: int # [0,64]
        v: int # [0,64]
        def hashKey(self):
            # Designed to be input to perfect_hash
            # perfect_hash is designed around strings but glsl only has ints
            # buuut, since we know the uv is only uint16_t unsafely interpret the number as a string
            return (self.u + (self.v << 8)).to_bytes(2, byteorder="big").decode('latin1')

    DIRS = [
        FaceDirection.RIGHT,
        FaceDirection.LEFT,
    ]

    keySet: set[Key] = set()
    parts = PARTS_STEVE + PARTS_ALEX
    for part in parts:
        uvs = body_cornerUvs(part)
        for dir in DIRS:
            cids = faceDir_counterClockwiseCornerUVIds(dir, 0)
            for u,v in (uvs[c] for c in cids):
                k = Key(u=u, v=v)
                keySet.add(k)
    keyList = sorted(keySet)

    # generate a perfect hash function
    TEMPLATE =  """
G = [$G]
S1 = [$S1]
S2 = [$S2]

def perfectHash(u: int, v: int):
    return (
        G[(S1[0]*u + S1[1]*v) % $NG] +
        G[(S2[0]*u + S2[1]*v) % $NG]
    ) % $NG
"""
    strList = [k.hashKey() for k in keyList]
    ph = perfect_hash.generate_code(strList, Hash=perfect_hash.IntSaltHash, template=TEMPLATE)
    print(ph)

    for k in keyList:
        foo = perfectHash(k.v, k.u)
        print(foo)

G = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 228, 0, 0, 0, 0, 0, 0, 132, 0, 0, 0, 0, 0, 106, 180,
    0, 114, 18, 49, 0, 0, 0, 0, 0, 156, 194, 0, 0, 32, 0, 31, 0, 0, 15,
    192, 0, 36, 0, 0, 111, 0, 0, 0, 0, 50, 12, 54, 0, 0, 10, 0, 0, 54, 0,
    71, 19, 84, 0, 38, 17, 0, 0, 0, 0, 70, 232, 104, 55, 199, 0, 0, 0, 0,
    225, 53, 33, 14, 0, 0, 0, 0, 79, 84, 149, 153, 220, 0, 104, 0, 0, 31,
    0, 62, 151, 0, 0, 0, 0, 0, 7, 37, 92, 0, 68, 0, 0, 50, 0, 93, 27, 36,
    0, 0, 98, 0, 37, 49, 0, 27, 45, 31, 5, 107, 0, 0, 40, 19, 169, 0, 227,
    24, 66, 69, 0, 30, 210, 0, 25, 65, 0, 44, 96, 78, 0, 0, 0, 0, 0, 40,
    111, 60, 172, 64, 0, 0, 202, 115, 220, 232, 0, 20, 0, 0, 0, 0, 86, 58,
    39, 0, 0, 110, 0, 0, 91, 35, 41, 2, 71, 0, 0, 0, 0, 75, 1, 96, 16, 22,
    0, 88, 0, 0, 82, 0, 160, 41, 211, 0, 66, 37, 0, 0, 118, 9, 3, 59, 102,
    0, 85, 57, 42, 0]
S1 = [107, 23]
S2 = [57, 40]

def perfectHash(u: int, v: int):
    return (
        G[(S1[0]*u + S1[1]*v) % 235] +
        G[(S2[0]*u + S2[1]*v) % 235]
    ) % 235

def writeCube(f: TextIO, part: BodyPart, counters: ObjCounters):
    file_v = []
    file_vt = []
    file_vn = []
    file_f = []

    for u, v in body_cornerUvsNormalized(part):
        file_vt.append(f"vt {u} {v}\n")
        counters.vt += 1

    for dir, relativeVertexIds in DIRECTION_2_VERTEXORDER.items():
        for vidx in relativeVertexIds:
            vcoord = body_toCubeCoords(part)[vidx]/32
            file_v.append(f"v {vcoord[0]} {vcoord[1]} {vcoord[2]}\n")
            counters.v += 1

        fnorm = faceDir_normal(dir)
        file_vn.append(f"vn {fnorm[0]} {fnorm[1]} {fnorm[2]}\n")
        counters.vn += 1

        # Bind UV and normals to vt:s UV
        xt = counters.vt-UV_ORDER_COUNT # get the index for the first vt for this shape
        xn = counters.vn-1              # get the index for the first vn for this face
        xv = counters.v-4               # get the index for the first v for this face

        c0, c1, c2, c3 = faceDir_counterClockwiseCornerUVIds(dir, xt)
        file_f.append(
            f"f {xv}/{c0}/{xn} {xv+1}/{c1}/{xn} {xv+2}/{c2}/{xn}\n"
        )
        counters.fid += 1
        file_f.append(
            f"f {xv}/{c0}/{xn} {xv+2}/{c2}/{xn} {xv+3}/{c3}/{xn}\n"
        )
        counters.fid += 1

    f.writelines(file_v)
    f.writelines(file_vt)
    f.writelines(file_vn)
    f.write("usemtl m_32a6897e-4c41-36a4-cc6b-d8aec3b361de\n")
    f.writelines(file_f)
    #f.write(f"fv {vcoord[0]} {vcoord[1]} {vcoord[2]}\n")
    #f.write(f"fv {vcoord[0]} {vcoord[2]} {vcoord[3]}\n")

def faceDir_normal(self: FaceDirection) -> NDArray[np.floating]:
    match self:
        case FaceDirection.TOP:
            ret = np.array([0,1,0]) # top
        case FaceDirection.BOTTOM:
            ret = np.array([0,-1,0]) # bottom
        case FaceDirection.RIGHT:
            ret = np.array([-1,0,0]) # right
        case FaceDirection.FRONT:
            ret = np.array([0,0,1]) # front
        case FaceDirection.LEFT:
            ret = np.array([1,0,0]) # left
        case FaceDirection.BACK:
            ret = np.array([0,0,-1]) # back
    return ret*0.555

"""

#       ^ v (up)
#
#           x    x
#         1---0 2---3
# z       | 0 | | 1 |
#         2---3 1---0
#   1---0 1---0 1---0 1---0
# y | 2 | | 3 | | 4 | | 5 |
#   2---3 2---3 2---3 2---3
#     z     x     z     x
"""
UV_ORDER_COUNT = 6 * 4
def faceDir_counterClockwiseVertId(self: FaceDirection, offset) -> Generator[int, None, None]:
    """ The starting point of the indexing must be corner 0 see gl_VertexID.png """
    match self:
        case FaceDirection.TOP:
            return (offset + 4*0 + i for i in (1, 0, 3, 4))
        case FaceDirection.BOTTOM:
            return (offset + 4*1 + i for i in (5, 4, 1, 2))
        case FaceDirection.RIGHT:
            return (offset + 4*2 + i for i in (7, 6, 11, 12))
        case FaceDirection.FRONT:
            return (offset + 4*3 +i for i in (8, 7, 12, 13))
        case FaceDirection.LEFT:
            return (offset + 4*4 +i for i in (9, 8, 13, 14))
        case FaceDirection.BACK:
            return (offset + 4*5 +i for i in (10, 9, 14, 15))

def body_vertUvs(self: BodyPart) -> list[tuple[int,int]]:
    """ Returns an iterator for the UV as [u,v] tuples in units of pixels from the top left
        Sorted in UV ordering """
    x = self.axis_sizes[0]
    y = self.axis_sizes[1]
    z = self.axis_sizes[2]
    (ou, ov) = self.origin_uv
    uvpx = [
        # TOP/BOTTOM
        (ou + z,             ov),
        (ou + z + x ,        ov),
        (ou + z + x + x ,    ov),
        (ou + z,             ov + z),
        (ou + z + x ,        ov + z),
        (ou + z + x + x ,    ov + z),
        # RIGHT/FRONT/LEFT/BACK
        (ou,                 ov + z),
        (ou + z,             ov + z),
        (ou + z + x,         ov + z),
        (ou + z + x + z,     ov + z),
        (ou + z + x + z + x, ov + z),
        (ou,                 ov + z + y),
        (ou + z,             ov + z + y),
        (ou + z + x,         ov + z + y),
        (ou + z + x + z,     ov + z + y),
        (ou + z + x + z + x, ov + z + y),
    ]
    return uvpx
def body_cornerUvsNormalized(self: BodyPart) -> list[tuple[float,float]]:
    return [(u/64, 1-v/64) for (u,v) in body_cornerUvs(self)]

def mulin(arr, scales):
    return np.array([(row * scales) for row in arr])

PIX1 = np.array([
    [1,1,1],
    [0,1,1],
    [0,0,1],
    [1,0,1],
    [1,1,0],
    [0,1,0],
    [0,0,0],
    [1,0,0],
]) - np.array([0.5,0.5,0.5])

def body_toCubeCoords(self: BodyPart):
    """ returns a list of [X,Y,Z] in the order as the image above DIRECTION_2_VERTEXORDER """
    return np.asarray(self.origin_3d_center) + mulin(PIX1, self.axis_sizes) * self.scale_3d

run()
