# Universal Chat Filter

An English-language chat filtering addon for **World of Warcraft: Forever**. Maintain a personal list of words and phrases, and hide matching chat messages across supported chat channels.

**Current version:** 2.0.0  
**Target client:** WoW Forever 1.60.1 · Interface 16001

## Features

- Filter messages across common public, custom, group, raid, guild, whisper, community, system, loot and currency channels.
- Block entire chat messages containing any of your terms.
- Case-insensitive substring matching (for example, `boost` also matches `boosting`).
- Browse blocked terms in a scrollable in-game interface and remove them individually.
- Add single terms or paste many terms separated by commas or new lines.
- Bulk import skips duplicate terms; bulk export produces a comma-separated list.
- Temporarily disable filtering without deleting your list.
- Save filter settings automatically, account-wide.
- No external libraries or dependencies.

## Installation

1. Download `Universal_Chat_Filter_WoW_Forever.zip` from [the Releases page](https://github.com/braunglasrakete/wow-forever-universal-chat-filter/releases).
2. Extract the ZIP.
3. Copy the **`UniversalChatFilter`** directory into your game installation:

   ```text
   World of Warcraft/_forever_/Interface/AddOns/
   ```

4. If you have an older addon called `ChatBegriffsFilter`, disable or uninstall it to avoid running both filters.
5. Start WoW (or type `/reload`), and enter **`/ucf`** to open the window.

Correct folder structure:

```text
AddOns/
└── UniversalChatFilter/
    ├── UniversalChatFilter.toc
    ├── UniversalChatFilter.lua
    └── README.txt
```

## Use the interface

- **Blocked Terms** displays your saved list, with mouse-wheel scrolling and buttons to remove entries.
- **Add a Term** accepts one word or phrase at a time.
- **Bulk Import / Export** accepts terms separated by commas or newlines, for example:

  ```text
  boost, gold seller, carry service, WTS raid
  ```

  Click **Import Terms**. The import adds new entries to your existing list and ignores duplicates.
- Click **Export List** and press **Ctrl+C** to copy your current list for backup or sharing.
- **Clear Input** empties only the text field; **Clear All** deletes all saved entries and requires confirmation.
- **FILTER: ON/OFF** toggles filtering without erasing your terms.

## Chat commands

| Command | Description |
| --- | --- |
| `/ucf` | Open/close the interface |
| `/chatfilter` | Alternative interface command |
| `/ucf add boost` | Block a term |
| `/ucf add cheap gold` | Block a multi-word phrase |
| `/ucf remove boost` | Remove a blocked term |
| `/ucf list` | Print the blocked list in chat |
| `/ucf on` | Enable filtering |
| `/ucf off` | Disable filtering |
| `/ucf clear` | Immediately delete **all** blocked terms, without confirmation |
| `/ucf help` | Show command help |

The legacy `/cbf` command is also accepted as an alias.

## Behavior and limitations

The addon hides **entire chat messages** containing a blocked term; it does not replace individual words. Matching is case-insensitive and checks for substrings, so short blocked terms can also match inside unrelated words.

Filtering is local to your WoW client; it does not mute or report other players. Combat logs, chat bubbles, and text drawn by other addon interfaces are not filtered. Some protected/secret chat messages may pass through in modern client builds to avoid Lua errors.

## Upgrading from ChatBegriffsFilter

Universal Chat Filter stores its settings under different SavedVariables. Your old list will **not** migrate automatically. Copy or export the old terms before disabling the old addon, then import them into the new interface.

## Source and license

The addon consists of plain Lua and a `.toc` manifest; no additional libraries are required. Licensed under [GNU GPL v3.0](LICENSE).