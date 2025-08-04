import json
import sys
from sort_table import xsort

def insertNew():
    if len(sys.argv) != 2:
        raise Exception("Argument Exception, 1 argv must be provided")

    path = sys.argv[1]
    hatDataPath = "__master_models_table.json"

    with open(path,"r", encoding='utf8') as f:
        fileData = json.load(open(hatDataPath, encoding='utf8'))
        hatData = fileData["models"]

        alreadyRegistered = {}
        for hd in hatData:
            mcItem = hd["item"]
            modelPath = hd["model"]
            if not mcItem in alreadyRegistered:
                alreadyRegistered[mcItem] = []
            alreadyRegistered[mcItem].append(modelPath)

        newData = json.load(f)["models"]
        for nd in newData:
            modelPath = nd["model"]
            mcItem = nd["item"]
            try:
                if modelPath in alreadyRegistered[mcItem]:
                    print(f"SKIP (already defined): {mcItem}[]={modelPath}")
                    continue
            except Exception: ""

            if "displayName" not in nd:
                nd["displayName"] = makeDisplayName(modelPath)

            nd["data"] = getNextAvailableCMData(hatData, mcItem)
            hatData.append(nd)

            print(f"REGISTER: {mcItem}[{nd['data']}]={modelPath}")

    with open(hatDataPath, "w+") as f:
        json.dump(fileData, f)

    xsort(file = hatDataPath)

def getNextAvailableCMData(hatData, mcItem):
    matchingItemData = [hat for hat in hatData if hat["item"] == mcItem]

    if mcItem == "minecraft:clock":
        mx = max(matchingItemData, key=lambda x: -getCMDataIfCorrectItem(x, mcItem), default={"data":0})["data"]
        return mx-1
    else:
        mx = max(matchingItemData, key=lambda x: getCMDataIfCorrectItem(x, mcItem), default={"data":0})["data"]
        return mx+1

def getCMDataIfCorrectItem(hatProperties, matchItem):
    assert hatProperties["item"] == matchItem
    return int(hatProperties["data"])

def makeDisplayName(modelPath):
    s = modelPath.split("/")[-1]
    return " ".join([x.title() for x in s.split("_")])

if __name__ == '__main__':
    insertNew()