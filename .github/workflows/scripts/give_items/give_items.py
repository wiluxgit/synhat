import json
import re

def run(path = "../__master_models_table.json"):
    with open(path) as f:
        hatList = json.load(f)["models"]

        allMcItems = {}
        for x in hatList:
            allMcItems[x["item"]] = 0
        allMcItems = allMcItems.keys()

        mcItems2Hat = {}
        for mcItem in allMcItems:
            mcItems2Hat[mcItem] = [x for x in hatList if x["item"] == mcItem]

        #mcItems2Hat["minecraft:netherite_hoe"]

        chestList = []
        for mcItem,hatList in mcItems2Hat.items():
            itemList = [makeItem(hd) for hd in hatList]
            chestList.append(makeMegaChest(mcItem, itemList))
        masterChest = makeMegaChest("MasterChest", chestList)

        #chestMeta = nbt.from_json(masterChest)
        jsonDict = masterChest["tag"]

        #print(json.dumps(jsonDict,indent=2))

        nbt = jsonDict2NBTText(jsonDict)
        print(f"give Wilux chest{nbt}")

def jsonDict2NBTText(jsonDict):
    jsonStr = json.dumps(jsonDict, separators=(',', ':'))
    rtxt = re.sub(r'"(\w+)"\s*:', lambda n:re.sub(r'"','', n.group()), jsonStr)
    rtxt = re.sub(r'(?<=[^\\])"',r"'",rtxt)
    txt = rtxt.encode("ascii").decode("unicode-escape",'backslashreplace')
    return txt

def chunk(l, n):
    return [l[i:i + n] for i in range(0, len(l), n)]

def makeMegaChest(categoryStr, itemList):
    if len(itemList) <= 27:
        return makeChest(categoryStr, itemList)

    subChests = [makeChest(categoryStr, ilc) for ilc in chunk(itemList, 27)]
    return makeMegaChest(categoryStr, subChests)

def makeChest(categoryStr, itemList):
    if len(itemList) > 27: raise Exception("Chest can not contain more than 27 items")

    mcItemBox = stringToShulkerBox(categoryStr)

    for i,item in enumerate(itemList):
        item["Slot"] = i

    chest = {"id":mcItemBox, "Count":1, "tag":{
        "display":{"Name":f'{{"text":"{categoryStr}"}}'},
        "BlockEntityTag":{"Items":itemList}
    }}
    return chest

def stringToShulkerBox(str):
    x = hash(str)%17
    cols = ["","white_","orange_","magenta_","light_blue_","yellow_","lime_","pink_","gray_","light_gray_","cyan_","purple_","blue_","brown_","green_","red_","black_"]
    return f"minecraft:{cols[x]}shulker_box"

def makeItem(hd):
    mcItem = hd["item"]
    cmData = hd["data"]
    path = hd["model"]
    displayName = hd["displayName"]
    displayName = re.sub(r"'",r"\'",displayName)

    color = "yellow"
    if "playerRank" in hd:
        rankCol = {"T":"dark_aqua", "A":"blue", "H":"light_blue", "D":"gold"}
        color = rankCol[hd["playerRank"]]

    disp = {
        "Name":f'{{"text":"{displayName}","italic":false,"color":"{color}"}}',
        "Lore":[f'{{"text":"id:{cmData}","italic":false,"color":"dark_gray"}}']
    }
    if "lore" in hd:
        lore = hd["lore"]
        lore = re.sub(r"'",r"\'",lore)
        disp["Lore"].insert(0,f'{{"text":"\\\\"{lore}\\\\"","color":"gray"}}')

    item = {
        "id":mcItem,
        "Count":1,
        "tag":{
            "display":disp,
            "CustomModelData":cmData
        }
    }
    return item

if __name__ == '__main__':
    run()