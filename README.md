# Pawie Tweaks
A lightweight Quality of Life (QoL) and automation addon for Ascension WoW (3.3.5). 

Pawie Tweaks is designed to eliminate tedious tasks and improve your gameplay experience without impacting your game's performance. It is completely event-driven, meaning it uses virtually zero memory and only runs exactly when needed.

## 📥 Installation
1. Click the green **Code** button at the top right of this page and select **Download ZIP**.
2. Extract the downloaded ZIP file.
3. **Important:** Rename the extracted folder from `PawieTweaks-main` to exactly `PawieTweaks`.
4. Move the `PawieTweaks` folder into your WoW AddOns directory:
   `World of Warcraft/Interface/AddOns/`
5. Start the game and make sure the addon is enabled in your character selection screen.

---

## ⚙️ Togglable Features
You can easily toggle these features on or off via the game's addon menu (`ESC -> Interface -> AddOns -> Pawie Tweaks`) or by using the `/pawie` chat command.

* **Auto-Quest:** Automatically accepts and turns in quests. *(Tip: Hold SHIFT when talking to an NPC to temporarily pause this feature).*
* **Auto-Quest Reward:** Automatically selects the best gray/white quest reward if there are no direct armor upgrades for your class (it picks the item that vendors for the most gold).
* **Chat Class Colors:** Colors player names in the chat based on their class (in SAY, YELL, PARTY, GUILD, etc.).
* **Short Channel Names:** Shortens channel prefixes in the chat to save space (e.g., `[Dungeon Guide]` becomes `[DG]`, `[Battleground]` becomes `[BG]`, and `[1. Ascension]` becomes `[1.]`).
* **Block Duels:** Automatically declines duel requests from players who are not on your friends list or in your guild.
* **Block Guild Invites:** Blocks random guild invites from strangers.
* **Hide Action Bar Gryphons:** Removes the two gryphon statues on the left and right sides of your main action bar.
* **Raid Marks on Default Frames:** Displays raid target icons (Moon, Star, Skull, etc.) centered at the top of the default raid frame portraits.
* **Show Incoming Ress:** Draws a small resurrection angel icon on raid frames when a healer (or someone using *Millhouse's Regeneration Matrix*) is casting a resurrection on a dead player.
* **Auto-Transmog (Soulbound):** Silently scans your bags in the background. If it finds a *Soulbound* item with an appearance you haven't collected yet, it automatically learns it for you. (100% safe for BoE items, as it leaves them completely untouched so you can sell them on the AH!).

---

## 👻 Background QoL (Always active)
These are small scripts that run silently in the background to make the game smoother and less annoying.

* **Smart Auto-BG Chat:** If you enter a Battleground and press `Enter` while your chat is set to `/s` (Say), the addon instantly forces the chat to `/bg` so you don't accidentally talk to yourself.
* **Auto-Buy Quest Items:** If you talk to a vendor and have Auto-Quest enabled, the addon scans the shop for Quest Items (costing up to 30 silver). If you don't already have the item in your bags, it buys exactly 1 automatically.
* **Chat Copy Button:** Adds a small, unobtrusive button to the top right of your chat windows. Clicking it opens a text box where you can easily highlight and copy text from the chat.
* **Clickable Invites:** If someone types words like "inv" or "invite" in /say, /whisper, or /guild, the word is turned into a clickable link. Clicking the link instantly invites them to your group.
* **Change Any Bag:** Allows you to drag and drop a new empty bag over an old, full bag. The addon magically moves all the contents to your other free bag slots and equips the new bag for you.
* **Auto-Confirmations:** Automatically types "DELETE" when trying to destroy blue/epic items. It also automatically clicks "Yes" on BoP (Bind on Pickup) warnings and when rolling Need/Greed.
* **Mute Error Messages:** Filters out annoying red spam text in the middle of the screen (e.g., "Out of range", "Not ready yet", "Inventory is full") and mutes your character's error voice ("I need more mana").
* **Alt-Buy at Vendors:** Holding `Alt` and left-clicking an item at a vendor automatically buys the maximum amount you can fit in your bags (great for filling up on water or ammo).
* **Clean Tooltips:** Hides the ugly default HP bar glued to the bottom of tooltips. It also colors player names by their class and turns guild names yellow when you hover over them.
* **LFD Leave Button Fix:** Fixes the built-in Dungeon Finder minimap eye button so you can actually click it to leave the party when the instance is finished.

---

## 💻 Slash Commands
Type `/pawie` in chat followed by a command to toggle settings:
* `/pawie quest` - Toggles Auto-Quest accept and turn-in.
* `/pawie reward` - Toggles Auto-Pick for white/gray quest rewards.
* `/pawie duel` - Toggles blocking of duel requests.
* `/pawie ginv` - Toggles blocking of guild invites.
* `/pawie colors` - Toggles class colors in chat.
* `/pawie shortchat` - Toggles shortening of chat channels.
* `/pawie marks` - Toggles Raid Marks on default frames.
* `/pawie ress` - Toggles Incoming Resurrection tracking.
* `/pawie tmog` - Toggles auto-learning uncollected Soulbound appearances.
* `/rl` - Reloads the UI.
