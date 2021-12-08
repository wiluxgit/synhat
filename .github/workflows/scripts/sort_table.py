import json
from sys import path

def clockFirst(str):
    if str == "minecraft:clock":
        return "AAA"
    return str

def xsort(file = "__master_models_table.json"):

    inFile = open(file)
    fileData = json.load(inFile)
    hatData = fileData["models"]
    inFile.close

    hatData = [
        sortKeysPretty(x) for x in hatData
    ]
    hatData.sort(
        key=lambda x: (clockFirst(x["item"]), x["data"])
    )

    fileData["models"] = hatData
    jsonStr = sortaReadableJson(fileData)
    open(file,"w+").write(jsonStr)

def sortaReadableJson(jDict):
    jsonStr = json.dumps(jDict).replace("}, {","},\n\t{")
    jsonStr = jsonStr.replace("[{","[\n\t{")
    return jsonStr

def sortKeysPretty(data):
    ret = {}
    ret["item"] = data["item"]
    ret["data"] = data["data"]
    ret["model"] = data["model"]
    ret["displayName"] = data["displayName"]
    for k,v in data.items():
        if not k in ["item","data","model","displayName"]:
            ret[k] = v
    return ret


if __name__ == '__main__':
    xsort()