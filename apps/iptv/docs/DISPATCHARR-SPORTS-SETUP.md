> Owner-provided planning handoff from another chat, received 2026-10-29. These steps have not been executed or accepted in this repository. Recheck the installed plugin/version and current upstream documentation before use. The clean-slate phase deletes channels/EPGs: preserve a backup and get explicit approval before those destructive actions. No Dispatcharr changes are part of the TV UI update.

# Dispatcharr Sports Setup with EPG & Sports Editor

Oct 29, 2026 · @Clay Blasingame

## Why the last attempt failed

The plugin scanned 0 channels because its Sports Editor sections are per Dispatcharr channel group. With Override Channel Group set to `NFL`, channels landed in a group named `NFL`, not in the `US| NFL PPV` section that was enabled. For testing, leave Override blank so the channel group name matches the section exactly.

Rename Rules are not required. The matcher already strips provider noise like `NFL | 4k - SNF 8:20pm`, `NCAAF 01:` and leading or trailing times, and it matches network channels such as `NCAAF 02: ESPN2` inside a league group.

## Phase 1: Clean slate

1. **My Plugins:** disable every plugin except EPG & Sports Editor.
2. **EPG & Sports Editor → Actions:** click **Teardown** to remove any virtual EPGs, then **Restart**. The plugin docs say a restart is required after every install or update.
3. **M3U & EPG Manager → EPGs:** delete everything except the Primary XMLTV source.
4. **Channels:** delete all channels.

## Phase 2: Dispatcharr groups

In the M3U account → **Groups**, enable only NFL, NBA and NCAAF, each with **Auto Channel Sync** checked and Fixed numbering (NFL 1400, NBA 1200, NCAAF 1500). Set each group's ⚙️ config as below.

| Field | Value |
| --- | --- |
| Find / Replace / Include | empty |
| Exclude (NFL) | `-\s*$\|^#+` |
| Exclude (NBA) | `(?i)no event streaming\|^#+` |
| Exclude (NCAAF) | `^NCAAF\s*\d+:\s*$\|^#+` |
| EPG Source | default (Auto-match) |
| **Override Channel Group** | **empty** |
| Channel Profiles | jellyfin |
| Compact numbering | on |

Click **Save and Refresh**, then check that the Channels list shows groups named `US| NFL PPV`, `US| NBA PASS PPV ⁸ᴷ` and `US| NCAAF PPV`.

## Phase 3: Plugin settings

- **EPG Sources → Primary:** transformation off.
- **EPG Fill:** leave empty.
- **Sports Editor global settings:** Pregame Window `All day`, Postgame Window `3 hours`, Hide Past-Date Channels After `4 hours`, Local Display Timezone `America/Chicago`, Game Thumbs Base URL left at its default.
- **Group sections:** enable only the three below, with Rename Rules blank and Hide past-date on. Leave every other group off.
- **Sport Templates:** keep the defaults for this first test; customize titles and descriptions once matching works.

| Sports Editor section | Sport Template |
| --- | --- |
| `US\| NFL PPV` | NFL |
| `US\| NBA PASS PPV ⁸ᴷ` | NBA |
| `US\| NCAAF PPV` | NCAA Football |

Click **Save**.

## Phase 4: Run and verify

1. **Actions → Run Sport Templates.**
2. **Show Status.** A known Dispatcharr display bug sometimes hides action output even though the action ran, so Status is the reliable check.
3. Check Channels and the TV Guide. Expect names like `Denver Broncos @ Atlanta Falcons`, matchup logos, and Pregame, Live and Postgame blocks.

- [ ] Status shows scanned above 0 for all three groups
- [ ] Game channels renamed with logos
- [ ] TV Guide shows Pregame, Live and Postgame blocks at Central times

## Notes from the docs

- Don't click Dispatcharr's ⟳ refresh on the "EPG & Sports Editor: …" EPG rows. They have no URL, so it always errors; use the plugin's own Actions buttons instead.
- From now on the plugin runs automatically after every M3U refresh.
- Unmatched channels keep their raw name. Common causes are no game for that matchup in the 10-day window, or a team spelling the matcher doesn't know; a Rename Rule can rewrite it.
- When everything looks right, refresh guide data in Jellyfin.

## Sources

- [EPG & Sports Editor README](https://github.com/jstevenscl/epg-and-sports-editor)
- [Sport Templates Guide](https://github.com/jstevenscl/epg-and-sports-editor/blob/master/docs/SPORT_TEMPLATES.md)
