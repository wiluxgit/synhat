import json
import os
import copy
from checksumdir import dirhash
import datetime
import simplejson

permModelPath = "../../assets/%PERM/models.json"
permPacksPath = "../../assets/%PERM/packs.json"

wipModelPath = "../../assets/%WIP/models.json"
wipPacksPath = "../../assets/%WIP/packs.json"

permModelJson = json.load(open(permModelPath))
permModels = permModelJson["models"]
cmpTime = str(datetime.datetime.now())

permModelPaths = []
for x in permModels:
    permModelPaths.append(x["path"])

def packdiff():
    packs = getPackDeclrs()
    permpacks = json.load(open(permPacksPath))

    permpackPaths = []
    for permpackDeclr in permpacks["packs"]:
        permpackPaths.append(permpackDeclr["path"])

    for (packName,packDeclr) in packs.items():
        safePackDeclr = toSafePackDeclr(packName,packDeclr)
        mergeWithPermModels(safePackDeclr)

    print(permModelJson)
    writePermModel(overwrite=False)

def writePermModel(overwrite):
    if overwrite:
        f = open(permModelPath,"w+")
    else:
        f = open(wipModelPath,"w+")
    f.write(simplejson.dumps(
        permModelJson, indent=4, sort_keys=True
    ))


def getPackDeclrs():
    packDeclrs = {}
    for f in os.listdir("../../assets"):
        if("%" in f):
            continue
        packDeclr = json.load(open(f"../../assets/{f}/pack.json"))
        packDeclrs[f] = packDeclr
    return packDeclrs
        

def md5fromPackName(packname):
    packDir = f"../../assets/{packname}"
    return (md5hashFolder(packDir))

def md5hashFolder(path):
    if not os.path.exists(path):
        raise Exception(f"{path} does not exist")
    return(dirhash(path, "md5"))

def toSafePackDeclr(packName,packDeclr):
    packDeclr = copy.deepcopy(packDeclr)

    packHash = md5fromPackName(packName)

    for modelDeclr in packDeclr["models"]:
        modelPath = modelDeclr["path"]
        try:
            mcItem = modelDeclr["type"]
        except Exception:
            mcItem = "clock"
        finally:
            if mcItem in ["sword","axe","pickaxe","shovel","hoe"]:
                mcItem = "netherite_"+mcItem
        
        nameSpacedPath = f"{packName}/{modelPath}"

        modelDeclr["type"] = mcItem
        modelDeclr["path"] = nameSpacedPath
        modelDeclr["pack"] = packName
        modelDeclr["packHash"] = packHash
        modelDeclr["compileTime"] = cmpTime

    return(packDeclr)

def mergeWithPermModels(packDeclr):
    #TODO? only update permodel if model/texture changed

    for modelDeclr in packDeclr["models"]:
        path = modelDeclr["path"]
        if path in permModelPaths:
            for i,model in enumerate(permModels):
                if model["path"] == path:
                    permModels[i] = modelDeclr
                    print("hello")
        else:
            permModels.append(modelDeclr)

packdiff()
