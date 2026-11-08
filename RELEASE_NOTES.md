# Universal Chat Filter v2.0.0

Initial public release for **World of Warcraft: Forever 1.60.1** (Interface 16001).

## Highlights

- Filter unwanted messages across supported chat channels using a custom blocklist.
- English-language in-game settings window (`/ucf`).
- Paginated blocked-terms list with per-term removal.
- Bulk import of comma-separated or newline-separated words/phrases; duplicate entries are ignored.
- Export the current list as comma-separated text.
- Enable/disable filtering without losing settings.
- Account-wide saved configuration.

## Installation

Download the ZIP asset `Universal_Chat_Filter_WoW_Forever.zip`, extract it, and copy the enclosed `UniversalChatFilter` folder to:

`World of Warcraft/_forever_/Interface/AddOns/`

Open settings in-game with `/ucf`.

**Note:** Lists from the older `ChatBegriffsFilter` addon are not automatically transferred. The filtering is local and does not cover combat logs, chat bubbles, or separately rendered addon interfaces.