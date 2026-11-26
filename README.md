# Founders: Barter & Block

An open-source hex-grid resource trading and strategy board game.

## Overview

In **Founders: Barter & Block**, players gather resources from a modular hex board, barter with opponents, expand roads and settlements, and strategically block rival routes to reach victory first.

## Play

### Linux (x86_64)

Download `founders-barter-and-block-v0.1.0-linux-x86_64.zip` from the [latest release](https://github.com/sramteare/founders-barter-and-block/releases/latest), unzip it, and run:

```
chmod +x founders-barter-and-block.x86_64
./founders-barter-and-block.x86_64
```

### From source (any desktop platform)

Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/), then either open the project folder in the Godot editor and press Play, or run it from a terminal:

```
godot4 --path /path/to/founders-barter-and-block
```

Your Godot binary may be named `godot` or `Godot_v4.3-stable_...` instead of `godot4`.

## Develop

### Run the tests

```
tests/run_fast.sh
```

This runs the whole suite headless in four parallel shards (about a minute and a half). It uses `godot4` from your `PATH`; set `GODOT=/path/to/godot` to use another binary. To run only some sections:

```
godot4 --headless --path . --script tests/run_tests.gd -- --match=<text>
```

### Build the Linux executable

Install the Godot 4.3 export templates (in the editor: Editor > Manage Export Templates), then:

```
mkdir -p builds
godot4 --headless --path . --export-release "Linux" builds/founders-barter-and-block.x86_64
```

The result is a single file with the game data embedded. `builds/` is ignored by git.

## Platforms

- **Linux:** available now.
- **Windows, macOS, Web, Android, iOS:** planned.

## License & Branding

- **Source Code:** Licensed under the [MIT License](LICENSE).
- **Name & Branding:** The name *Founders: Barter & Block* and any official logos/artwork are reserved for the official project. If you fork and publish this project to app stores or public sites, please use a different name and branding.
