# CatCatcher

A small 3D game made in Godot.

Core game idea: catch various cat's by drawing a circle around them. Currently, the game is in early-development phase.

**Play in the browser:** https://LucyferYX.github.io/CatCatcher/

## Controls

| Mode | Controls |
|---|---|
| Menu | Mouse |
| Explore the meadow | **WASD** walk, **Shift** run, **Space** jump, **mouse** look around |
| Anywhere in game | **Esc** pause menu (resume / back to the main menu) |

Walk up to the hut and the door opens by itself.

In the browser, click inside the game once to start the music and to lock the mouse.

## Features

- First-person walking around and inside the witch's hut, with collisions
- Door that opens when the player comes close
- Wandering cats in different colours
- Multiple low-poly nature props (grass, flowers, grass patches) scattered around the field
- Start menu and pause menu

## Running the project

1. Install [Godot 4.7](https://godotengine.org/) (standard version).
2. Open `Godot/project.godot`.
3. Press **F5**.

The project uses the **Compatibility** renderer, so it also runs in the browser and on older laptops. The web build in `docs/` is the single-threaded Web export.

## Project structure

```
README.md  info
docs/      web build (served by GitHub Pages)
Godot/     Godot project: scenes, scripts, assets, UI theme
```

## Credits

- 3D models (witch's hut, nature props): modelled in Blender for this project
- Music: created with [Suno](https://suno.com) (non-commercial use)
- Font: [Fredoka](https://fonts.google.com/specimen/Fredoka), SIL Open Font License 1.1
- Engine: [Godot Engine](https://godotengine.org), MIT License
