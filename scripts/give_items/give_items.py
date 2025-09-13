import json
import re

def run(path = "../__master_models_table.json"):
    with open(path) as f:
        modelList = json.load(f)["models"]

        allMcItems = {}
        for x in modelList:
            allMcItems[x["item"]] = 0
        allMcItems = allMcItems.keys()

        mcItems2Hat = {}
        for mcItem in allMcItems:
            mcItems2Hat[mcItem] = [x for x in modelList if x["item"] == mcItem]

        chestList = []
        for mcItem, hatList in mcItems2Hat.items():
            hatList = sorted(hatList, key=lambda j: j["displayName"])
            itemList = [makeItem(hd) for hd in hatList]
            chestList.append(makeMegaChest(mcItem, itemList))
        NBT_masterChest = makeMegaChest("MasterChest", chestList)

        nbt = components_to_nbt(NBT_masterChest)
        print(f"give Wilux white_shulker_box{nbt}")

def to_nbt(obj):
    if isinstance(obj, dict):
        return '{' + ','.join(f'{k}:{to_nbt(v)}' for k, v in obj.items()) + '}'
    elif isinstance(obj, list):
        return '[' + ','.join(to_nbt(i) for i in obj) + ']'
    elif isinstance(obj, str):
        escaped = obj.encode('unicode_escape').decode('ascii')
        escaped = escaped.replace("'", "\\'")
        return "'" + escaped + "'"
    else:
        return repr(obj)
def components_to_nbt(obj):
    content = ','.join(
        f'{k}={to_nbt(v)}'
        for k, v
        in obj["components"].items()
    )
    return '[' + content + ']'


def chunk(l, n):
    return [l[i:i + n] for i in range(0, len(l), n)]

def makeMegaChest(categoryStr, itemList):
    if len(itemList) <= 27:
        return makeChest(categoryStr, itemList)

    subChests = [makeChest(categoryStr, ilc) for ilc in chunk(itemList, 27)]
    return makeMegaChest(categoryStr, subChests)

def makeChest(categoryStr, itemList):
    if len(itemList) > 27: raise Exception("Chest can not contain more than 27 items")

    NBT_container = []
    for i,item in enumerate(itemList):
        NBT_container.append({
            "slot": i,
            "item": item,
        })

    chest = {
        "id": stringToShulkerBox(categoryStr),
        "components": {
            "custom_name": f'{{"text":"{categoryStr}"}}',
            "container": NBT_container,
        }
    }
    return chest

def stringToShulkerBox(str):
    x = hash(str)%17
    cols = ["","white_","orange_","magenta_","light_blue_","yellow_","lime_","pink_","gray_","light_gray_","cyan_","purple_","blue_","brown_","green_","red_","black_"]
    return f"{cols[x]}shulker_box"

def makeItem(hd):
    def jsonEscape(s: str) -> str:
        return json.dumps(s)[1:-1]

    mcItem = hd["item"]
    cmData = hd["data"]
    path = hd["model"]
    displayName = hd["displayName"]

    color = "yellow"
    if "playerRank" in hd:
        rankCol = {"T":"dark_aqua", "A":"blue", "H":"aqua", "D":"gold"}
        color = rankCol[hd["playerRank"]]

    NBT_custom_name = f'{{"text":"{jsonEscape(displayName)}","color":"{color}"}}'
    NBT_lore = [f'{{"text":"id:{cmData}","color":"dark_gray"}}']
    if "lore" in hd:
        lore = hd["lore"]
        NBT_lore.insert(0,f'{{"text":"{jsonEscape(lore)}","color":"gray"}}')

    item = {
        "id": mcItem,
        "count":1,
        "components": {
            "custom_model_data": cmData,
            "item_name": NBT_custom_name,
            "lore": NBT_lore,
        }
    }
    return item

if __name__ == '__main__':
    run()