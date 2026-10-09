# iPad acceptance checks

Run on the iPad mini 2 with iOS 10.3.3.

## Install

- Install `dist/Solitaire-2.0.0.ipa` (or the `.deb`). Confirm the app opens without a signing error. For the `.deb`, `dpkg -l com.local.solitaire` should show 2.0.0.
- Confirm the home screen shows the new app icon. If the old one appears, run `uicache` as mobile or respring. Check the icon in Spotlight and Settings too.

## Orientation

- Launch in each of the four orientations. The launch image should be black with no letterboxing, and the board should come up in the matching orientation.
- Rotate through all four orientations mid-game. The board must not re-deal, moves and timer keep going, and Undo still works.
- Start dragging a card or stack and rotate. Confirm no card remains floating and the next touch works. Repeat with a card selected (tap-to-select) and confirm the selection clears.
- In portrait, confirm seven columns fit, long face-up runs spread further than in landscape, and corner indices stay readable.

## Controls bar

- Confirm the bar is at the bottom in every orientation: time and moves on the left, Undo, New game, and Settings icons on the right.
- Each icon is easy to hit (44pt or larger). Undo is dimmed until the first move and after undoing everything.
- With VoiceOver on, the buttons read "Undo", "New game", and "Settings".
- New game still asks for confirmation. Cancel leaves the board unchanged; accepting resets moves and Undo and increments games played.
- Win a game and confirm the victory text sits above the bar, not over it.

## Card art

- With no art in `Resources/Cards/`, cards look like v1 (rank and suit text faces, slate lattice back).
- With a partial set, cards with art show it, the rest fall back, and nothing crashes. With a full 53-card set, every card uses the art.
- Flip several cards right after launch and confirm there is no hitch on first flip.
- Corner indices are readable on long and compressed stacks in both orientations.

## Settings

- Settings shows only Statistics (games played, wins, current win streak). There is no Card back or Draw mode section, and every row is visible without scrolling in both orientations.

## Unchanged from v1

- Draw all 24 stock cards, recycle, and check the same draw order returns. Undo a draw and a recycle.
- Drag one card and a multi-card stack to legal and illegal destinations. Invalid drops return without incrementing moves.
- Tap a waste card, a tableau top card, and a card partway down a face-up run. Each moves to its foundation if it can, otherwise onto a tableau card, otherwise a king to an empty column. A card with no move shakes and the move count doesn't change. A lone king at the bottom of a column doesn't hop to another empty column. Covered waste and foundation cards cannot be moved.
- While dragging, the outline sits on the card a stack would land on, not over the top of the column.
- The top row reads foundations left, waste and stock right, with space above it. Empty foundations are plain outlines. The purple gradient fills the screen, including behind the controls bar, in both orientations.
- Move a tableau stack that exposes a face-down card. Confirm it flips, then undo and confirm it becomes face-down again.
- Background the app for a minute. The game timer does not advance, and relaunching restores the board.
- Enable Reduce Motion. Move and victory animations are suppressed.
- Play for at least ten minutes in both orientations. Check responsiveness, memory stability, and whether drag motion holds 60 FPS on the A7.
