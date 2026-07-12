# ICN2: Immersive Character Needs 2

**ICN2** is a lightweight survival simulation addon for *World of Warcraft*.  
Designed for roleplayers and immersion enthusiasts, it adds the missing layer of biological needs to your character: **Hunger, Thirst, and Fatigue**.  

ICN2 uses a dynamic **Rate Engine** that reacts to your actions, surroundings, and equipment. Your character’s needs change based on movement, combat, rest, mounts, and more.

---

## ✨ Features

- **Real-time need tracking** for Hunger, Thirst, and Fatigue.
- **Situational modifiers** for swimming, flying, mounted travel, combat, resting, indoors, and instanced content.
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
- Fatigue recovers faster while resting, sitting, near campfires, or inside housing.
- If one need reaches 0%, the others may decay faster through cross-need effects.
- Needs are stored in race-specific point pools, so each race has its own maximum values.

---

## 🎨 HUD & Themes

- Multiple HUD themes, including **Colorful**, **Minimalist**, **Smooth**, **Blocky**, **Folk**, **Necromancer**, and **Dastardly**.
- Color palettes include **Default** and **Colorblind_OkabeIto**.
- Adjustable opacity, scale, bar length, and label mode.
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

## ⚔️ Compatibility

- Tested with WoW version **12.1.0** (Retail).
- Classic compatibility not guaranteed.
- Uses saved variable `ICN2DB`.

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

MIT License.
