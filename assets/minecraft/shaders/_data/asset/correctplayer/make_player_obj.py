import numpy as np

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

    with open("me2.obj", "w+") as f:
        f.write("# Made by Wilux\n")
        f.write("mtllib steve.mtl\n\n")

        _vid, _vtid, _vnid, _fid = (1,1,1,1)

        f.write("o Head\n")
        _vid, _vtid, _vnid, _fid = writeCube(f, ordfaces, cube=head, texOrg=(0,0), 
            vid=_vid, vtid=_vtid, vnid=_vnid, fid=_fid
        )        
        f.write("o Body\n")
        _vid, _vtid, _vnid, _fid = writeCube(f, ordfaces, cube=body, texOrg=(16,16), 
            vid=_vid, vtid=_vtid, vnid=_vnid, fid=_fid
        )      
        f.write("o RArm\n")
        _vid, _vtid, _vnid, _fid = writeCube(f, ordfaces, cube=rarm, texOrg=(32,48), 
            vid=_vid, vtid=_vtid, vnid=_vnid, fid=_fid
        ) 
        f.write("o LArm\n")
        _vid, _vtid, _vnid, _fid = writeCube(f, ordfaces, cube=larm, texOrg=(40,16), 
            vid=_vid, vtid=_vtid, vnid=_vnid, fid=_fid
        )
        f.write("o RLeg\n")
        _vid, _vtid, _vnid, _fid = writeCube(f, ordfaces, cube=rleg, texOrg=(16,48), 
            vid=_vid, vtid=_vtid, vnid=_vnid, fid=_fid
        )
        f.write("o LLeg\n")
        _vid, _vtid, _vnid, _fid = writeCube(f, ordfaces, cube=lleg, texOrg=(0,16), 
            vid=_vid, vtid=_vtid, vnid=_vnid, fid=_fid
        )

def writeCube(f, ordfaces, cube, texOrg, vid, vtid, vnid, fid):

    file_v = []
    file_vt = []
    file_vn = []
    file_f = []

    cornUvs = corverUvs(texOrg, cube)
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

        c0, c1, c2, c3 = counterClockwiseCornerIds(dirid, xt)


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

def counterClockwiseCornerIds(faceid, offset): 
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

def corverUvs(texOrigin, cube):
    size = cubeSize(cube)
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

def cubeSize(cube):
    return abs(cube[0]-cube[6])
    
def faceNormal(faceid):
    i = faceid
    if i == 0:
        return [1,0,0]
    elif i == 1:
        return [-1,0,0]
    elif i == 2:
        return [0,1,0]
    elif i == 3:
        return [0,-1,0]
    elif i == 4:
        return [0,0,1]
    elif i == 5:
        return [0,0,-1]




def mulin(arr, scales):
    return np.array([(row * scales) for row in arr])
def debugged(s):
    print(s)
    return s

run()