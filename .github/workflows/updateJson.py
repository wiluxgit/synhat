import json
import sys

version = sys.argv[1]
path = "../../pack.mcmeta"

with open(path, "r") as f:
    jf = json.load(f)
    jf["pack"]["description"][-1]["text"] = f"(v{version})"

with open(path, "w") as f:
    json.dump(jf, f, indent=2)