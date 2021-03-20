import json
import os
import copy
from checksumdir import dirhash
import datetime
import simplejson

permFilePath = "../../assets/%INTERNAL/perm.json"
permModelJson = json.load(open(permFilePath))
permModels = permModelJson["models"]
cmpTime = str(datetime.datetime.now())
permModelPaths = []
for x in permModels:
    permModelPaths.append(x["path"])

def __init__(args=""):
    packdiff()
    print(permModelJson)    
    writePermModel()

def packdiff():
    packs = getPackDeclrs()

    for (packName,packDeclr) in packs.items():
        safePackDeclr = toSafePackDeclr(packName,packDeclr)
        #TODO not merge if same hash
        mergeWithPermModels(safePackDeclr)

def writePermModel():
    f = open(permFilePath,"w+")
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

        modelDeclr["type"] = mcItem
        modelDeclr["path"] = modelPath
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
        else:
            permModels.append(modelDeclr)

__init__()
