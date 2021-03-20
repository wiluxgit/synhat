import json
import os
import shutil
import datetime
import simplejson
from distutils.dir_util import copy_tree
from pathlib import Path

packOutDir = "../../pack_output"
packInDir = "../../assets"
declrPath = "../../assets/%INTERNAL/perm.json"

#TODO better find directory
def __init__():
    defaultItemModelDir="assets/mc"

    setUpBaseRP("assets",6)

    cmNext = {}
    itemModelJson = {}
    packNames = set()

    declr = json.load(open(declrPath))
    for i,model in enumerate(declr["models"]):
        mcItem = model["type"]
        path = model["path"]
        pack = model["pack"]

        packNames.add(pack)
        
        if "is_player" in model:
            raise Exception(f"{path} not implemented")

        if not mcItem in cmNext: # REALLY UGLY
            cmNext[mcItem] = 1
        if mcItem == "clock":
            cmNext[mcItem] = -1
        freeIndex = cmNext[mcItem]
        cmNext[mcItem] = nextCmdKey(freeIndex)

        outPath = f"synhat/{pack}/{path}"

        if not mcItem in itemModelJson:  
            itemModelJson[mcItem] = makeMcJson(mcItem, defaultItemModelDir)
        js = itemModelJson[mcItem]

        override = {
            "predicate":{"custom_model_data":freeIndex},
            "model":outPath
        }
        js["overrides"].append(override)

        cloneAssetToOut(path, pack)

    print(packNames)

    #get pack pngs to the output
    copyTextureAssets(list(packNames))

    #make mcitem jsons
    for (k,v) in itemModelJson.items():
        f = json.dump(v, open(f"{packOutDir}/assets/models/item/{k}.json","w+"))
        print(f"generated {k}.json")

#TODO make parent models work
def cloneAssetToOut(path, pack):
    destFile = Path(f"{packOutDir}/assets/models/synhat/{pack}/{path}.json")
    destDir = destFile.parent
    Path(destDir).mkdir(parents=True, exist_ok=True)

    shutil.copy(
        f"{packInDir}/{pack}/models/{path}.json",
        destFile
    )

    js = json.load(open(destFile))
    for (k,v) in js["textures"].items():
        js["textures"][k] = f"synhat/{pack}/{v}"
    js["credit"] = "Synhat Auto Generated"

    f = open(destFile,"w")
    f.write(simplejson.dumps(
        js, indent=4, sort_keys=False
    ))

def copyTextureAssets(packList):
    for packName in packList:
        destPath = f"{packOutDir}/assets/textures/synhat/{packName}"
        srcPath = f"{packInDir}/{packName}/textures"
        
        Path(f"{destPath}").mkdir(parents=True, exist_ok=True)

        copy_tree(srcPath, destPath)
    return -1

def setUpBaseRP(baseAssetsDir, packFormat):
    #shutil.rmt ree(packOutDir)
    Path(f"{packOutDir}").mkdir(parents=True, exist_ok=True)
    Path(f"{packOutDir}/assets/models/item").mkdir(parents=True, exist_ok=True)
    Path(f"{packOutDir}/assets/models/synhat").mkdir(parents=True, exist_ok=True)
    Path(f"{packOutDir}/assets/textures").mkdir(parents=True, exist_ok=True)

    shutil.copy(f"{baseAssetsDir}/pack.png", packOutDir)
    shutil.copy(f"{baseAssetsDir}/pack.mcmeta", packOutDir)
    mcmeta = {"pack":{"pack_format":packFormat,
     "description":f"Synhat Infinity ({datetime.date.today()})"}
    }
    f = json.dump(mcmeta, open(f"{packOutDir}/pack.mcmeta","w+"))

def nextCmdKey(i):
    if i<0:
        return (i-1)
    elif i>0:
        return (i+1)
    else:
        raise Exception("cant be 0")


def makeMcJson(mcName, defaultItemModelDir):
    sourcePath = f"{defaultItemModelDir}/{mcName}.json"
    js = json.load(open(os.path.abspath(sourcePath)))

    if not "overrides" in js:
        js["overrides"] = [{
            "predicate": {"custom_model_data":0 }, 
            "model": f"item/{mcName}" 
        }] #add override to itself

    #if overrides already exist only apply them for cmdata 0
    for override in js["overrides"]:
        override["predicate"]["custom_model_data"] = 0

    return js

__init__()
