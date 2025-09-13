import json
from sort_table import sortaReadableJson
from datetime import datetime

def make_mc_files_old():
    file = "__master_models_table.json"

    inFile = open(file)
    fileData = json.load(inFile)
    hatData = fileData["models"]

    item2Model = {}

    for declr in hatData:
        nameSpacedItem = declr["item"]
        item = nameSpacedItem.split(":")[-1]
        data = declr["data"]
        path = declr["model"]

        if not item in item2Model:
            try:
                with open(getMcModelPath(item)) as f:
                    modelJson = json.load(f)
                    # keep vanilla overrides
                    if "overrides" not in modelJson:
                        modelJson["overrides"] = []

                    modelJson["overrides"] = [x for x in modelJson["overrides"] if cmdata_is_zero(x)]
                    #print(modelJson["overrides"])
                    item2Model[item] = modelJson
            except FileNotFoundError:
                print(f"Can not add {cropBegining(path,25)}:{data} since {item}.json does not exist")
                continue

        newPredicate = {"custom_model_data":data}
        if "extra_predicate" in declr:
            newPredicate.update(declr["extra_predicate"])

        item2Model[item]["overrides"].append(
            {"predicate":newPredicate,"model":path}
        )

    for k,v in item2Model.items():
        v["overrides"].sort(
            key=lambda x: get_cmdata(x)
        )
        jsonDump = sortaReadableJson(v)
        with open(getMcModelPath(k),"w+") as f:
            f.write(jsonDump)
        print(k)

    print("done", datetime.now().strftime("%H:%M:%S"))

def make_mc_files_21_4():
    file = "__master_models_table.json"

    fileData = json.load(open(file))
    hatData = fileData["models"]
    itemName2itemModel = {}
    for declr in hatData:
        nameSpacedItem = declr["item"]
        itemName = nameSpacedItem.split(":")[-1]
        data = declr["data"]
        path = declr["model"]
        if not itemName in itemName2itemModel:
            vanillaPath = f"C:/Users/wilux/AppData/Roaming/ModrinthApp/profiles/synergy/resourcepacks/_1.21.8/items/{itemName}.json"
            mc = json.load(open(vanillaPath))
            itemName2itemModel[itemName] = {
                "model": {
                    "type": "range_dispatch",
                    "property": "custom_model_data",
                    "index": 0,
                    "entries": [],
                    "fallback": mc["model"],
                }
            }
        itemName2itemModel[itemName]["model"]["entries"].append({
            "threshold": data,
            "model": {
                "type": "model",
                "model": path
            }
        })

    for k,v in itemName2itemModel.items():
        v["model"]["entries"].sort(
            key=lambda x: x["threshold"]
        )
        jsonDump = sortaReadableJson(v)
        with open(getMcItemModelPath(k),"w+") as f:
            f.write(jsonDump)
        print(k)


def getMcModelPath(item):
    return f"../assets/minecraft/models/item/{item}.json"
def getMcItemModelPath(item):
    return f"../assets/minecraft/items/{item}.json"

def get_cmdata(override):
    if "predicate" in override:
        if "custom_model_data" in override["predicate"]:
            return override["predicate"]["custom_model_data"]
    return 0

def cropBegining(str, max=15):
    if len(str) <= max:
        return str
    else:
        return ".."+str[-max:]

def cmdata_is_zero(override):
    return get_cmdata(override) == 0

if __name__ == '__main__':
    print("========================")
    make_mc_files_old()
    print("========================")
    make_mc_files_21_4()