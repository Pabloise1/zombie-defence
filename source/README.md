# Game scripts (recovered from the v0.6.2 build)

This repo only held the exported web build, so these GDScript files were
recovered from `index.pck` (it shipped compiled script tokens). Code and names are
exact; the original comments and blank-line layout were not in the build, so
they're gone. Every script compiles in Godot 4.7.2.

`CHANGES.patch` is everything changed since v0.6.2. If you keep working in
your own Godot project, port these changes into it. Otherwise your next export
will overwrite them.

## Rebuild the web build without the Godot editor

Godot runs text `.gd` scripts at runtime, so you can edit the files here and
repack them straight into the existing pack:

```sh
python3 source/tools/repack.py index.pck source new.pck && mv new.pck index.pck
```

After that, update `"index.pck":<size>` in `index.html` and bump `CACHE_VERSION`
in `index.service.worker.js`, so installed copies download the new pack.

## Tools

- `tools/pck.py`: list and extract files from a `.pck`.
- `tools/gdc.py`: turn a compiled `.gdc` (Godot 4.3+ token format) back into source.
- `tools/repack.py`: put text scripts back into a `.pck`.
- `tools/loadall.gd`: compile-check every script against a pack (run with Godot `--headless -s`, `LIST=` a file of `res://` paths).
- `tools/audit.gd`: plays waves headless with the real economy and prints ammo, crates, income and repairs per wave (`LAYOUT=square|mixed`).
- `tools/civtest.gd`: scenario checks for fetcher rescues, safe houses and room block gun slots (`TEST=rescue|shelter|block`; shelter needs `-- --map=suburb`).
- `tools/soak.gd`: long headless run that prints object, node and memory counts per wave, to catch leaks.

Example: `LAYOUT=square ./Godot_v4.7.2-stable_linux.x86_64 --headless --main-pack index.pck -s source/tools/audit.gd`
