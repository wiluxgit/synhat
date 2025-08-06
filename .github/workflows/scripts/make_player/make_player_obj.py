from enum import Enum
from typing import Generator, Self, TextIO
import numpy as np
from numpy.typing import NDArray
import matplotlib.pyplot as plt
from dataclasses import dataclass

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
PARTS_STEVE = [
#            name     uv TL     size      3d center  3d scale
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

    # Handrolling some .obj file because we need very specific vertex ordering
    with open("C:/Users/wilux/AppData/Roaming/.minecraft/resourcepacks/synhat-dev/web_editor/assets/steve.obj", "w+") as f:
        f.write("# Made by Wilux\n")
        f.write("mtllib steve.mtl\n\n")

        counters = ObjCounters(1,1,1,1)

        for part in parts:
            #f.write(f"o {name}\n")
            writeCube(f, part, counters)

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
UV ordering is an arbitrary ordering by me, it does not correspond to any minecraft property
#       ^ v (up)
#
#           x   x
#         0---1---2
#         |   |   |
# z       | 0 | 1 |
#         |   |   |
#         3---4---5
#   6-----7---8-----9---10    -> u (left)
# y |  2  | 3 |  4  | 5 |
#   11----12--13----14--15
#      z    x    z    x
"""
UV_ORDER_COUNT = 16
def faceDir_counterClockwiseCornerUVIds(self: FaceDirection, offset) -> Generator[int, None, None]:
    """ The starting point of the indexing must be corner 0 see gl_VertexID.png """
    match self:
        case FaceDirection.TOP:
            return (offset + i for i in (1, 0, 3, 4))
        case FaceDirection.BOTTOM:
            return (offset + i for i in (5, 4, 1, 2))
        case FaceDirection.RIGHT:
            return (offset + i for i in (7, 6, 11, 12))
        case FaceDirection.FRONT:
            return (offset + i for i in (8, 7, 12, 13))
        case FaceDirection.LEFT:
            return (offset + i for i in (9, 8, 13, 14))
        case FaceDirection.BACK:
            return (offset + i for i in (10, 9, 14, 15))

def body_cornerUvs(self: BodyPart) -> list[tuple[int,int]]:
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
