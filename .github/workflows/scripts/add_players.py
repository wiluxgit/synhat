import json
from sort_table import xsort
import sys
import re

def run():
    inPath = "__master_models_table.json"

    trusted = extractUUIDFromRankdump(open("temp/trusted.txt").read(), "T")
    devoted = extractUUIDFromRankdump(open("temp/devoted.txt").read(), "D")
    dumpUUIDs = trusted | devoted

    with open(inPath,"r") as inFile:
        fileData = json.load(inFile)
        plushies = [x for x in fileData["models"] if x["data"]>0 and x["item"] == "minecraft:clock"]

        nextAvailableData = max([x["data"] for x in plushies])+1
        olduuids = [x["uuid"] for x in plushies]

        for puuid,newData in dumpUUIDs.items():
            newRank = newData["rank"]
            newName = newData["name"]

            maybeOldData = [x for x in plushies if x["uuid"] == puuid]
            if len(maybeOldData) == 0:
                print(f"New    {newName} {newRank}")
                newP = {
                    "item": "minecraft:clock",
                    "data": nextAvailableData,
                    "model": f"synhat/player/player/{puuid}",
                    "displayName": f"{newName}",
                    "uuid": f"{puuid}",
                    "playerRank": f"{newRank}"
                }
                fileData["models"].append(newP)
                nextAvailableData += 1
            else:
                oldData = maybeOldData[0]
                oldRank = oldData["playerRank"]
                if oldRank != newRank:
                    print(f"Rankup {newName} {oldRank} -> {newRank}")
                    oldData["playerRank"] = newRank

    outPath = inPath #"temp/new_model_.json"
    with open(outPath, "w+") as f:
        json.dump(fileData, f)

    xsort(file = outPath)


def extractUUIDFromRankdump(str, rank):
    mx = re.split(r"\[.*\]    ", str)
    uuids = {}
    for x in mx:
        match = re.search(r"([0-9a-f\-]{36,}\/.*)", x)
        try:
            mtch = match.group(0)
            [uuid, name] = mtch.split("/")
            uuids[uuid] = {"rank":rank, "name":name}
        except:""
    return uuids

if __name__ == '__main__':
    print("""
Test
""")
    run()