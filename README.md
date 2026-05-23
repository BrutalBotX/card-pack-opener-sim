# Card Pack Opener Simulator

## Readme right now is just AI generated for now, there can be errors, I'll update is as soon as I can if there are any error. Hell this whole project is vibe coded too. Project is in developement with a ton of bugs

A data-driven card collection and simulation engine built with Godot. This project focuses on managing card databases, rendering 3D assets, and simulating pack-opening mechanics.
📦 Data Source

This project utilizes the [pokemon-tcg-pocket-database](https://github.com/flibustier/pokemon-tcg-pocket-database) repository for external datasets. Card images are sourced directly from their asset subdirectories.
📂 Project Structure

To ensure the engine correctly parses the database, please arrange your directory structure as follows:

```
res://
├── assets/
│   └── cards/          # Card images (webp/png)
├── data/
│   └── json/
│       ├── cards.json  # Master card database
│       └── sets.json   # Set definitions
└── user/
    └── inventory.json  # User-owned collection 
```

## 📝 Data Schema

The project relies on specific JSON structures for initialization.

### cards.json
```JSON

{
  "id": "string",
  "name": "string",
  "rarity": "string",
  "set": "string",
  "images": { "large": "url" }
}

```


### sets.json
```JSON

{
  "id": "string",
  "name": "string",
  "releaseDate": "YYYY-MM-DD"
}

```


🐛 Known Issues

Current status: Active Development## FAQ


- Binder Persistence: Inventory state is currently failing to load/render consistently from inventory.json.

- 3D Asset Cropping: Assets within the binder sub-viewport require camera frustum adjustments.

- Interaction Logic: Mouse-over triggers for 3D card tilt are causing jittering and require recalibration.

- UI Standardization: Parallax background integration and button styling are pending global consistency checks.

Note: This project is intended for educational purposes and personal portfolio use.
