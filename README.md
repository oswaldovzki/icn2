# ICN2: Immersive Character Needs 2

**ICN2** is a lightweight survival simulation addon for *World of Warcraft*.  
Designed for roleplayers and immersion enthusiasts, it adds the missing layer of biological needs to your character: **Hunger, Thirst, and Fatigue**.  

ICN2 uses a dynamic **Rate Engine** that reacts to your actions, surroundings, and equipment. Your character’s needs change based on movement, combat, rest, mounts, and more.

---

## ✨ Features

- **Real-time need tracking** for Hunger, Thirst, and Fatigue.
- **Situational modifiers** for swimming, flying, mounted travel, combat, resting, indoors, and instanced content.
- **Sitting detection** through the sit/stand keybind and built-in `/sit` and `/stand` commands.
- **Race/class modifiers** for a more immersive and balanced experience.
- **Well-Fed bonus**: Food or drink can pause hunger decay for a short time.
- **Immersive emotes**: Automatic low-need emotes with configurable chance and cooldown.
- **Custom HUD**: Draggable, scalable, themeable display with optional tooltips.
- **Manual restore controls** from slash commands or the options UI.

---

## 🎮 Choose Your Pace

ICN2 fits your playstyle with adjustable decay presets:

- **Fast**: Accelerated need decay for a survival challenge.
- **Medium**: Balanced default pace.
- **Slow**: Easier decay for casual roleplay.
- **Realistic**: Very slow decay for long play sessions.
- **Custom**: Independently bias Hunger, Thirst, and Fatigue.

---

## 🧠 Simulation Details

- At the medium preset, base decay is roughly **50 Hunger/Thirst points per 30 minutes** and **30 Fatigue points per 30 minutes**.
- Custom mode supports values from **zero passive decay** up to much faster drain.
- Rested areas pause fatigue decay; they do not recover fatigue on their own.
- Fatigue recovers while sitting, eating or drinking, near campfires, or inside housing.
- Rested areas combined with a campfire or housing provide fast recovery.
- Sitting ends automatically when moving, jumping, casting, entering combat, mounting, or standing.
- If one need reaches 0%, the others may decay faster through cross-need effects.
- Needs are stored in race-specific point pools, so each race has its own maximum values.

---

## 🎨 HUD & Themes

- Multiple HUD themes, including **Colorful**, **Minimalist**, **Smooth**, **Blocky**, **Folk**, **Necromancer**, **Dastardly**, and **Vanguard**.
- Color palettes include **Default** and **Colorblind_OkabeIto**.
- Theme-specific textures, colors, opacity, fill direction, overlays, sizing,
  and positioning are supported by the theme engine.
- **Colorful** uses custom bar textures; other themes use translucent solid
  fills so need icons remain visible.
- **Minimalist Vertical** and **Minimalist Horizontal** use icon-sized,
  top-to-bottom depletion overlays with configurable label modes.
- Adjustable opacity, scale, bar length, and label mode for all themes.
- Lock HUD position to prevent accidental movement.

---

## 📜 Commands

- `/icn2` or `/icn2 show` → Open the options panel.
- `/icn2 status` → Show current Hunger/Thirst/Fatigue in chat.
- `/icn2 details` → Show active modifiers, recovery sources, and net rates.
- `/icn2 hud` → Toggle the HUD display.
- `/icn2 lock` → Toggle HUD lock.
- `/icn2 reset` → Reset all needs to full.
- `/icn2 eat` → Restore 50 Hunger.
- `/icn2 drink` → Restore 50 Thirst.
- `/icn2 rest` → Restore 40 Fatigue.
- `/icn2 starve` → Set Hunger to 0.
- `/icn2 dehydrate` → Set Thirst to 0.
- `/icn2 exhaust` → Set Fatigue to 0.

---

## 🛠️ Optional Settings

- Freeze needs while offline to disable offline decay.
- Enable or disable automatic emotes.
- Adjust emote chance and minimum interval.
- Hide the HUD when all needs are full with Immersive Mode.
- Use custom decay bias sliders for each need.

---

## 📥 Installation

1. Download ICN2 from [CurseForge](https://www.curseforge.com/wow/addons/immersive-character-needs-2).
2. Extract the folder into your `World of Warcraft/_retail_/Interface/AddOns` directory.
3. Restart WoW and enable **Immersive Character Needs 2** in the AddOns menu.

---

## ⚔️ Compatibility & Classic Flavors

- Tested with WoW version **12.1.0** (Retail).
- Uses saved variable `ICN2DB`.

**A Note on Classic (Era, Season of Discovery, Cataclysm):**  
I exclusively play and develop for the modern Retail client, which means I do not have the time or resources to officially support, test, or maintain ICN2 for Classic versions of the game. 

However, the open-source community is absolutely welcome to adapt it! If you are a developer interested in porting ICN2 to a Classic environment, please feel free to fork the project, adapt the API, and maintain a Classic-specific branch. 

**Source Code & GitHub Repository:**  
[https://github.com/Anduin-Webworks/ICN2](https://github.com/Anduin-Webworks/ICN2)

---

## 🚧 Known Issues

- Certain legacy Drink items do not apply the “Drink” aura and may fail to restore thirst.
  **Workaround**: Manually replenish thirst via the ICN2 settings menu or `/icn2 drink`.

---

## 🙌 Credits

Developed by **Oswaldovzki** @ Anduin Webworks.  
Special thanks to the WoW addon community for feedback and testing.

---

## 📄 License

Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International.
