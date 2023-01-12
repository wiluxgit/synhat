import numpy as np

partname_head = "Head"
partname_body = "Body"
partname_rarm = "RArm"
partname_larm = "LArm"
partname_rleg = "RLeg"
partname_lleg = "LLeg"
partname_ohead = "oHead"
partname_orleg = "oRLeg"
partname_olleg = "oLLeg"
partname_orarm = "oRArm"
partname_olarm = "oLArm"
partname_obody = "oBody"

def run():
#===================================
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
#===================================
#       ^ v (up)
#
#       0---1---2
#       | 2 | 3 |
#   3---4---5---6---7    -> u (left)
#   | 1 | 4 | 0 | 5 |
#   8---9---10--11--12
#===================================
#    0: left 
#    1: right
#    2: top
#    3: bottom
#    4: front
#    5: back
#===================================
#
# order: [head, body, rarm, larm, rleg, lleg, ohead, olleg, orleg, orarm, olarm, obody]
#
    ordfaces = [
        (4,0,3,7), 
        (1,5,6,2), 
        (4,5,1,0), 
        (3,2,6,7), 
        (0,1,2,3),
        (5,4,7,6),
    ]

    pix1 = np.array([
        [1,1,1],
        [0,1,1],
        [0,0,1],
        [1,0,1],
        [1,1,0],
        [0,1,0],
        [0,0,0],
        [1,0,0],
    ]) - np.array([0.5,0.5,0.5])

    center_head = np.array([ 0,28,0])
    center_body = np.array([ 0,18,0])
    center_rarm = np.array([ 6,18,0])
    center_larm = np.array([-6,18,0])
    center_rleg = np.array([ 2,6 ,0])
    center_lleg = np.array([-2,6 ,0])

    head = center_head + mulin(pix1, [8,8,8])
    body = center_body + mulin(pix1, [8,12,4])
    rarm = center_rarm + mulin(pix1, [4,12,4])
    larm = center_larm + mulin(pix1, [4,12,4])
    rleg = center_rleg + mulin(pix1, [4,12,4])
    lleg = center_lleg + mulin(pix1, [4,12,4])

    overlayscale = 0.28125/0.25
    ohead = center_head + mulin(pix1, [8,8,8]) * overlayscale
    olleg = center_lleg + mulin(pix1, [4,12,4]) * overlayscale
    orleg = center_rleg + mulin(pix1, [4,12,4]) * overlayscale
    orarm = center_rarm + mulin(pix1, [4,12,4]) * overlayscale
    olarm = center_larm + mulin(pix1, [4,12,4]) * overlayscale
    obody = center_body + mulin(pix1, [8,12,4]) * overlayscale

    origin_head = (0,0)
    origin_body = (16,16)
    origin_rarm = (32,48)
    origin_larm = (40,16)
    origin_rleg = (16,48)
    origin_lleg = (0,16)

    origin_ohead = (32, 0)
    origin_olleg = (0, 32)
    origin_orleg = (0, 48)
    origin_orarm = (48, 48)
    origin_olarm = (40, 32)
    origin_obody = (16, 32)

    parts = [
        (partname_head, head, origin_head),
        (partname_body, body, origin_body),
        (partname_rarm, rarm, origin_rarm),
        (partname_larm, larm, origin_larm),
        (partname_rleg, rleg, origin_rleg),
        (partname_lleg, lleg, origin_lleg),
        (partname_ohead, ohead, origin_ohead),
        (partname_olleg, olleg, origin_olleg),
        (partname_orleg, orleg, origin_orleg),
        (partname_orarm, orarm, origin_orarm),
        (partname_olarm, olarm, origin_olarm),
        (partname_obody, obody, origin_obody),
    ]
    generateUV2FaceidCode(parts)

    with open("steve.obj", "w+") as f:
        f.write("# Made by Wilux\n")
        f.write("mtllib steve.mtl\n\n")

        _vid, _vtid, _vnid, _fid = (1,1,1,1)

        for (name, cube, texorigin) in parts:
            f.write(f"o {name}\n")
            _vid, _vtid, _vnid, _fid = writeCube(f, ordfaces, 
                cube=cube, texOrg=texorigin, partName=name,
                vid=_vid, vtid=_vtid, vnid=_vnid, fid=_fid
            )

def writeCube(f, ordfaces, cube, texOrg, partName, vid, vtid, vnid, fid):

    file_v = []
    file_vt = []
    file_vn = []
    file_f = []

    cornUvs = corverUvs(texOrg, partName)
    for cuv in cornUvs:
        vtid += 1
        file_vt.append(f"vt {cuv[0]} {cuv[1]}\n")

    for dirid, ordface in enumerate(ordfaces):
        for vidx in ordface: #vertex id
            vcoord = cube[vidx]/32
            file_v.append(f"v {vcoord[0]} {vcoord[1]} {vcoord[2]}\n")
            
            vid += 1

        fnorm = faceNormal(dirid)
        file_vn.append(f"vn {fnorm[0]} {fnorm[1]} {fnorm[2]}\n")
        vnid += 1

        xt = vtid-13
        xn = vnid-1
        xv = vid-4

        c0, c1, c2, c3 = counterClockwiseCornerUVIds(dirid, xt)


        file_f.append(
            f"f {xv}/{c0}/{xn} {xv+1}/{c1}/{xn} {xv+2}/{c2}/{xn}\n"
        )
        fid += 1
        file_f.append(
            f"f {xv}/{c0}/{xn} {xv+2}/{c2}/{xn} {xv+3}/{c3}/{xn}\n"
        )
        fid += 1        

    f.writelines(file_v)
    f.writelines(file_vt)
    f.writelines(file_vn)
    f.write("usemtl m_32a6897e-4c41-36a4-cc6b-d8aec3b361de\n")
    f.writelines(file_f)
    
    return vid, vtid, vnid, fid
            
        #f.write(f"fv {vcoord[0]} {vcoord[1]} {vcoord[2]}\n")
        #f.write(f"fv {vcoord[0]} {vcoord[2]} {vcoord[3]}\n")

def counterClockwiseCornerUVIds(faceid, offset): 
    i = faceid
    if i == 0:
        return (offset + i for i in (6,5,10,11))
    elif i == 1:
        return (offset + i for i in (4,3,8,9))
    elif i == 2:
        return (offset + i for i in (1,0,4,5))
    elif i == 3:
        return (offset + i for i in (6,5,1,2))
    elif i == 4:
        return (offset + i for i in (5,4,9,10))
    elif i == 5:
        return (offset + i for i in (7,6,11,12))

def corverUvs(texOrigin, partname):
    size = cubeSizeInPixels(partname)
    x = size[0]
    y = size[1]
    z = size[2]
    (ou, ov) = texOrigin
    uvpx = [
        (ou + z,             ov),
        (ou + z + x ,        ov),
        (ou + z + x + x ,    ov),
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
    return [(u/64, 1-v/64) for (u,v) in uvpx]

def cubeSizeInPixels(partname):
    if partname in [partname_head, partname_ohead]:
        return np.array([8,8,8])
    elif partname in [partname_body, partname_obody]:
        return np.array([8,12,4])
    elif partname in [
        partname_larm, partname_olarm, partname_lleg, partname_olleg,
        partname_rarm, partname_orarm, partname_rleg, partname_orleg
        ]:
        return np.array([4,12,4])
    raise ValueError(f"{partname} is not a known part")
    
def faceNormal(faceid):
    
    match faceid:
        case 0:
            ret = np.array([1,0,0])
        case 1:
            ret = np.array([-1,0,0])
        case 2:
            ret = np.array([0,1,0])
        case 3:
            ret = np.array([0,-1,0])
        case 4:
            ret = np.array([0,0,1])
        case 5:
            ret = np.array([0,0,-1])
    return ret*0.444

def mulin(arr, scales):
    return np.array([(row * scales) for row in arr])
def debugged(s):
    print(s)
    return s

def generateUV2FaceidCode(cubeAndOriginPairs):
    dump = ""
    for dirid in range(6):
        dump += f"    case {dirid}:\n"
        for cubeId, (partname, cube, origin) in enumerate(cubeAndOriginPairs):
            uvids = counterClockwiseCornerUVIds(dirid, 0)
            uvId2Coord = corverUvs(origin, partname)
            for uvid in uvids:
                uvCoord = uvId2Coord[uvid]
                faceId = cubeId*6 + dirid
                uvu = int(uvCoord[0]*64)
                uvv = int((1-uvCoord[1])*64)
                dump += f"        if ((uvu == {uvu}) && (uvv == {uvv})) return {faceId};\n"
        dump += "        return -1;\n"
    with open("codedump.txt", "w+") as f:
        f.write(dump)
# case 4
#   if (uvx == {uv.x} && uvy == {uv.x}) return {faceid}

run()
