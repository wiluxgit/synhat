import json
from sort_table import sortaReadableJson
from datetime import datetime

def make_mc_files():
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
                print(f"Can not add {cropBegining(path)}:{data} since {item}.json does not exist")
                continue

        item2Model[item]["overrides"].append(
            {"predicate":{"custom_model_data":data},"model":path}
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
    

def getMcModelPath(item):
    return f"../../../assets/minecraft/models/item/{item}.json"

def get_cmdata(override):
    if "predicate" in override:
        if "custom_model_data" in override["predicate"]:
            return override["predicate"]["custom_model_data"]
    return 0

def cropBegining(str, max=15):
    if len(str) <= max:
        return str
    else:
        return ".."+str[-15:]

def cmdata_is_zero(override):
    return get_cmdata(override) == 0

if __name__ == '__main__':
    make_mc_files()