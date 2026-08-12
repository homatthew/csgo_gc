# Personal offline inventory payload

These files are the source of truth for Matthew's local legacy CS:GO inventory:

- `inventory.txt`: curated skins, agents, gloves, nametags, and crafts.
- `config.txt`: ranks, app ID override `4465480`, and local GC behavior.
- `price_sheet.txt` and `unusual_loot_lists.txt`: the schema data paired with
  this inventory.

They intentionally contain no Steam authentication material, API tokens,
passwords, raw Steam inventory snapshot, or machine-specific paths. The
inventory is synthetic/offline data and is safe to publish.

Do not commit `csgo_gc.dll` or the replacement `csgo.exe`. GitHub Actions
builds those from the tracked source and publishes them in the
`continuous` release. `install.ps1` combines that release with this payload.

Current payload SHA-256:

```text
77877db02c87463c0794181f1386a8c09991a20a661d734655f5731f20f87e9e  config.txt
2f03df5cdac781e635720be7120e9e808f58a4c0682991fa11b4a3c38fff8bba  inventory.txt
170fc6b1050e50b0392fdb51a310dc9af6c8e32fc91ee75c23cc863b5a4b3b52  price_sheet.txt
cc742f95ce34cb3b2c4d80212d41646ef8c89ce9c751ca65a887e23dc98aaffa  unusual_loot_lists.txt
```
