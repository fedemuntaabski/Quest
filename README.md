# QUEST - Project Status Report
**Last Updated:** April 22, 2026  
**Engine:** Godot 4.6  
**Rendering:** GL Compatibility

---

## 📋 Project Overview
**QUEST** is a 2D grid-based RPG/Adventure game developed in Godot. The project features character movement, turn-based combat mechanics, grid-based collision detection, and a UI system.

### Window Configuration
- **Resolution:** 1920x1080 (Full HD)
- **Physics Engine (2D):** GodotPhysics2D
- **Physics Engine (3D):** Jolt Physics
- **Rendering Driver:** DirectX 12 (Windows)

---

## 🎮 Core Systems

### 1. **Input Map Configuration** ✅
Located in `project.godot` - Input section

**WASD Movement Actions:**
```
move_up    → W Key (keycode 87)
move_down  → S Key (keycode 83)
move_left  → A Key (keycode 65)
move_right → D Key (keycode 68)
```

**Other Input Actions:**
- `click` → Mouse Left Button

### 2. **Character Movement System** ✅
**Script:** `scripts/PlayerMovement.gd`
- **Grid Size:** 2.0 units
- **Movement Speed:** 10.0 (interpolation speed)
- **Type:** Orthogonal grid-based movement (no diagonals)
- **Features:**
  - WASD input handling
  - Smooth interpolation to grid cells
  - Grid snapping functionality
  - MapManager collision detection integration
  - Direction normalization for board-game feel

### 3. **Character Stats System** ✅
**Script:** `scripts/CharacterStats.gd`
- **Core Stats:**
  - HP (Health Points)
  - Strength
  - Magic
  - Dexterity
- **Dice System:** 1d6 with bonuses
  - Roll 1: -2 (Terrible)
  - Roll 2-3: -1 (Poor)
  - Roll 4-5: 0 (Average)
  - Roll 6: +2 (Critical Success)

### 4. **Game Manager (Autoload)** ✅
**Script:** `scripts/GlobalData.gd`
- Persistent game state management
- Character stat definitions
- Dice rolling mechanics

### 5. **Turn Manager (Autoload)** ✅
**Script:** `scripts/TurnManager.gd`
- Turn-based combat system initialization

### 6. **Other Systems**
- **TorchLight:** Dynamic lighting system (`scripts/TorchLight.gd`)
- **HUD Controller:** User interface (`scripts/HUDController.gd`)
- **Card Container:** Card/skill management (`scripts/CardContainer.gd`)
- **Map Manager:** Level and grid management (`scripts/MapManager.gd`)

---

## 🎬 Scene Hierarchy

### Main Scene: `scenes/Main2D.tscn` (UID: uid://u03qppfja2kb)
```
Main2d (Node2D)
├── CanvasModulate (Ambient lighting)
├── MapManager (Grid/Level management)
│   └── Player (CharacterBody2D)
│       ├── Sprite2D (Visual representation)
│       ├── CollisionShape2D (Capsule physics)
│       ├── Camera2D (Main viewport camera)
│       ├── PointLight2D (Torch/lighting)
│       └── Stats (Character statistics)
└── HUD (User interface)
```

### Camera Configuration ✅
**Scene:** `scenes/Player.tscn`
- **Position:** (0, 0)
- **Anchor Mode:** 0 (Drag Center)
- **Status:** Current (enabled)
- **Zoom:** 1.5x

### Position Alignment ✅
All root nodes positioned at **(0, 0)**:
- MapManager: (0, 0)
- Player: (0, 0) relative to MapManager

---

## 🎨 Visual Configuration

### Player Character
- **Type:** CharacterBody2D
- **Class:** Bounty Hunter
- **Era:** 14th Century
- **Sprite Color:** Brown (0.5, 0.3, 0.2)
- **Sprite Scale:** 1x height, 1.8x depth
- **Collision Shape:** Capsule (radius: 0.5, height: 1.8)

### Lighting
- **Environment Color:** Dark Blue-Gray (0.2, 0.2, 0.3)
- **Torch Light:**
  - Position: (0.3, 0.6) relative to player
  - Energy: 1.5
  - Texture Scale: 1.5

---

## 📁 Project Structure

```
Quest/
├── project.godot              # Main configuration file
├── README.md                  # This file
├── icon.svg                   # Project icon
├── background.png             # Background asset
│
├── assets/
│   └── ui/                    # UI assets
│
├── scenes/                    # All .tscn scene files
│   ├── MainMenu.tscn         # Main menu scene
│   ├── Main2D.tscn           # Main game scene
│   ├── Player.tscn           # Player character scene
│   ├── Enemy.tscn            # Enemy template
│   ├── HUD.tscn              # User interface
│   ├── MapManager.tscn       # Level/grid manager
│   ├── CardContainer.tscn    # Card system UI
│   ├── SkillCard.tscn        # Individual skill card
│   ├── WorldEnvironment.tscn # World/environment setup
│   ├── cartas.tscn           # Cards scene
│   └── map_elements/         # Map element scenes
│
└── scripts/                   # All .gd GDScript files
    ├── PlayerMovement.gd      # Player movement logic
    ├── CharacterStats.gd      # Stat system
    ├── GameEnvironment.gd     # Environment setup
    ├── GlobalData.gd          # Autoload game manager
    ├── HUDController.gd       # UI controller
    ├── MapManager.gd          # Level/grid management
    ├── TorchLight.gd          # Lighting system
    ├── TurnManager.gd         # Autoload turn system
    ├── CardContainer.gd       # Card container logic
    └── SkillCard.gd           # Skill card logic
```

---

## ✨ Features Implemented

- ✅ WASD movement input mapping
- ✅ Grid-based character movement
- ✅ Orthogonal movement (no diagonals)
- ✅ Camera2D setup and positioning
- ✅ Player character with lighting
- ✅ Character stat system (HP, Strength, Magic, Dexterity)
- ✅ Dice rolling mechanics
- ✅ Turn-based system foundation
- ✅ HUD/UI system
- ✅ Map grid management
- ✅ Card/skill system framework
- ✅ Dynamic lighting with torch
- ✅ Main menu scene with Start/Exit flow
- ✅ Prototype player/enemy icon-based visuals
- ✅ Basic dungeon floor tile source (2x2 white tile)

---

## 🔧 Recent Updates (v1.1)

### Configuration Fixes (Latest)
1. **Input Map:** Added WASD movement actions to `project.godot`
2. **Camera:** Configured Camera2D in Player.tscn
   - Position: (0, 0)
   - Anchor mode: Drag Center (mode 0)
   - Current: Enabled
3. **Scene Alignment:** Main2D.tscn scene nodes positioned at (0, 0)
4. **Main Menu:** Added `scenes/MainMenu.tscn` with title + Start/Exit buttons and connected signals
5. **Startup Scene:** `run/main_scene` now points to `res://scenes/MainMenu.tscn`
6. **Prototype Visuals:**
  - Player sprite uses `icon.svg` with brown modulate
  - Enemy sprite uses `icon.svg` with red modulate
  - MapManager TileMapLayer now has a TileSet using a 2x2 white tile (`assets/ui/white_2x2.svg`)

---

## 🚀 How to Build & Run

### Prerequisites
- **Godot 4.6** (GL Compatibility version)
- **Windows** (configured for DirectX 12)

### Launch Options

**Editor Mode:**
```bash
godot --path . --editor
```

**Play Game:**
```bash
godot --path .
```

---

## 📝 Notes

### Known Systems
- Game is using **GodotPhysics2D** for physics calculations
- **Jolt Physics** configured for 3D (if needed in future)
- **Autoload Singletons:**
  - `GameManager` → GlobalData.gd
  - `TurnManager` → TurnManager.gd
  - `Mousebrain` → UI/interaction system (UID: uid://ck5te6pmwxnp4)

### Dependencies
- No external plugins required
- Pure Godot 4.6 implementation
- Uses built-in 2D physics and rendering

---

## 🎯 Next Steps / TODO

- [ ] Implement enemy AI pathfinding
- [ ] Create turn-based combat system
- [ ] Develop skill card mechanics
- [ ] Build map editor tools
- [ ] Implement save/load system
- [ ] Create menus (main, pause, inventory)
- [ ] Add sound/music system
- [ ] Balance gameplay mechanics

---

**Project Repository:** Quest  
**Location:** `e:\Quest\`  
**Status:** In Active Development
