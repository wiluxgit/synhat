all models in the pack must be declared in "pack.json"
example of assets file:
```
{
	"models":[
		{"path":"fortress_warrior", "author":"Wilux"},
		{"path":"baugette_blade", "author":"Wilux", "type":"sword"}
	]
}
```
required tags:
 `path` the relative path to the model.json (relative from `./models`)
optional tags:
 `author` the author name/username
 `type` which base item the custom model should be applied to:
	suports aliases: `sword` `axe` `pickaxe` `shovel` `hoe` 
	if none is supplied defaults to `clock` (`minecraft:clock`)
	NOTE: ONLY supports alias or nothing atm.
 `in_hand_path` tridents (and soon spyglasses) have two models, one 
	in the inventory (this is the `path` tag) and another used in steve's hand.
	`in_hand_path` is the path to the model which should be used in this case.
	if not supplied to model that requires it there will likely be glitches.
	NOTE: unimplemented
