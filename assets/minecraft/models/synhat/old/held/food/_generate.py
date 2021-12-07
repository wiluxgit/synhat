import os

x = os.listdir(os.path.join(__file__,"../../../../textures/tool/food"))
for f in [f for f in x if ".png" in f]:
    file = open(f[:-4]+".json","w")
    file.write(f"""{{
  "parent": "minecraft:item/generated",
  "textures": {{
    "layer0": "tool/food/{f[:-4]}"
  }}
}}""")


