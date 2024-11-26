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

        for puuid,newData in dumpUUIDs.items():
            newRank = newData["rank"]

            maybeOldData = [x for x in plushies if x["uuid"] == puuid]
            if len(maybeOldData) == 0:
                print(f"New    {puuid} {newRank}")
                newP = {
                    "item": "minecraft:clock",
                    "data": nextAvailableData,
                    "model": f"synhat/player/player/{puuid}",
                    "displayName": f"",
                    "uuid": f"{puuid}",
                    "playerRank": f"{newRank}"
                }
                fileData["models"].append(newP)
                nextAvailableData += 1
            else:
                oldData = maybeOldData[0]
                oldRank = oldData["playerRank"]
                if oldRank != newRank:
                    print(f"Rankup {puuid} {oldRank} -> {newRank}")
                    oldData["playerRank"] = newRank

    outPath = inPath #"temp/new_model_.json"
    with open(outPath, "w+") as f:
        json.dump(fileData, f)

    xsort(file = outPath)


def extractUUIDFromRankdump(str, rank):
    uuids = {}
    for match in re.finditer(r"([0-9a-f\-]{36,})", str):
        try:
            mtch = match.group(0)
            uuid = mtch
            uuids[uuid] = {"rank":rank}
        except:""
    return uuids

if __name__ == '__main__':
    print("""
Test
""")
    run()