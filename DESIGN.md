# DESIGN.md — PassMgr Design System

> Google Stitch format. Drop this file in the project root — any AI agent reading it will understand exactly how PassMgr's UI should look and behave.

---

## 1. Visual Theme & Atmosphere

PassMgr feels like a **trustworthy personal tool** — warm but serious, calm but alert. The design signals security without the cold sterility of most security apps. Think: a well-organized leather notebook, not a government dashboard.

**Mood:** Private. Personal. Reliable. Unhurried.
**Density:** Comfortable — one thing at a time, generous white space, no cramped lists.
**Philosophy:**
- Secrets deserve visual dignity. Passwords render in monospace. Nothing is shown by default.
- Warnings are amber, not red — "pay attention" not "panic."
- Destructive actions (delete, erase) are red and always behind a confirmation.
- No gradients, no illustrations, no decorative icons. Structure through spacing and hairline borders.
- Follow system dark/light theme. Never force a mode.

---

## 2. Color Palette & Roles

### Light theme (primary)

| Token | Hex | Role |
|---|---|---|
| `paper` | `#F5F1EA` | App background — warm off-white, not clinical white |
| `ink` | `#0F1419` | Primary text — near-black |
| `inkSoft` | `#4A5159` | Secondary text, labels, descriptions |
| `inkMute` | `#8A8F97` | Placeholder text, muted metadata, dividers |
| `card` | `#FFFFFF` | Card and input backgrounds |
| `border` | `#E4DED2` | Hairline borders on cards and inputs |
| `borderSoft` | `#EFEAE0` | Very subtle dividers between rows |
| `emerald` | `#1E5F4E` | Primary accent — buttons, FAB, active toggles, focus rings |
| `emeraldSoft` | `#E8F0EC` | Emerald tint for avatars and background highlights |
| `emeraldDark` | `#174A3D` | Pressed state for emerald buttons |
| `amber` | `#B45309` | Warnings — edit history notice, import no-date notice |
| `amberSoft` | `#FBF1E2` | Amber tint backgrounds |
| `danger` | `#B91C1C` | Delete actions, error states, destructive buttons |
| `dangerSoft` | `#FBEAEA` | Danger tint for icon backgrounds |
| `overlay` | `rgba(15,20,25,0.5)` | Modal/dialog backdrop |

### Usage rules
- Never use `danger` for primary calls to action. Red = destructive only.
- `amber` for "this will change something you should know about" — not errors, not deletes.
- `emerald` is the only accent color. Do not introduce blue, purple, or other hues.
- Background is always `paper`, never white. Cards on top of paper use `card` (white).

---

## 3. Typography Rules

### Font families
- **UI text:** Inter (system fallback: `-apple-system`, `system-ui`, `sans-serif`)
- **Passwords and secrets:** IBM Plex Mono (fallback: `ui-monospace`, `monospace`)

Passwords, history items, generated passwords, and any revealed secret always render in IBM Plex Mono. Everything else uses Inter.

### Type hierarchy

| Role | Font | Size | Weight | Color |
|---|---|---|---|---|
| Screen title (AppBar) | Inter | 20px | 600 | `ink` |
| Section title | Inter | 17px | 600 | `ink` |
| Card title / Entry name | Inter | 14px | 600 | `ink` |
| Body / Field value | Inter | 14px | 400 | `ink` |
| Secondary / Username | Inter | 12–13px | 400 | `inkSoft` |
| Caption / Timestamp | Inter | 11–12px | 400 | `inkMute` |
| Field label (uppercase) | Inter | 11px | 500 | `inkMute` |
| Password / Secret | IBM Plex Mono | 14px | 400–500 | `ink` |
| Generated password | IBM Plex Mono | 14–15px | 500 | `ink` |
| Small meta / Tags | Inter | 10–11px | 500 | varies |

### Rules
- Field labels above inputs: uppercase, 0.08em letter-spacing, 11px, `inkMute`.
- Section group titles: uppercase, 0.08em letter-spacing, 11px, `inkMute`.
- Never use font weight below 400 or above 700.
- Letter-spacing: only on uppercase labels and badges (0.04–0.1em range).

---

## 4. Component Stylings

### Buttons

**Primary (emerald fill)**
- Height: 48px, border-radius: 12px, full-width in forms
- Background: `emerald`, text: white, font: Inter 14px 600
- Pressed: `emeraldDark`
- Disabled: 40% opacity

**Secondary (outlined)**
- Height: 48px, border-radius: 12px
- Background: `card`, border: 1px `border`, text: `ink`
- Used for "Edit", "Cancel", "Skip"

**Ghost**
- No background, no border, text: `inkSoft`
- Used for minor actions in footers

**Danger (outlined)**
- Background: transparent, border: 1px `#E5C7C7`, text: `danger`
- Used for "Delete" alongside "Edit" in action bars

**Action bar pair (detail screen)**
- Two buttons side by side, equal flex, height: 44px, font-size: 13px

**Small action button (copy, reveal)**
- 28×28px, border-radius: 8px, no border, `inkSoft` icon
- Hover/press: `rgba(0,0,0,0.05)` fill

### Input fields

- Height: 48px (single line), border-radius: 12px
- Background: `card`, border: 1px `border`
- Font: Inter 14px, color: `ink`, placeholder: `inkMute`
- Focus: border-color changes to `emerald`
- Password field: IBM Plex Mono, eye icon on right (28px touch target)
- Textarea: 80px height, padding 12px 14px, no resize

### Cards

- Background: `card`, border: 1px `border`, border-radius: 14px
- No box-shadow (hairline border only)
- Padding: 14px
- Hover: border-color → `inkMute`

### Entry list item

- Card with 40×40 avatar (border-radius: 12px, `emeraldSoft` bg, `emerald` letter)
- Amber avatar for G/F sites (visually distinct)
- Gray avatar for government/ID entries
- Entry name: 14px 600 `ink`, username: 12px `inkSoft`
- Chevron right: `inkMute`

### Entry avatar (large, detail screen)

- 64×64px, border-radius: 18px, font: 22px 600

### FAB (floating action button)

- 56×56px, border-radius: 16px, `emerald` background
- Box-shadow: `0 8px 20px rgba(30,95,78,0.35)` — only shadow in the whole app
- Position: absolute, bottom: 38px, right: 20px
- Icon: plus, white, 28px

### Toggle switch

- 40×22px, border-radius: 11px
- On: `emerald` background, knob right
- Off: `#D5D0C7` background, knob left
- Knob: 18×18px white circle, 2px from edge, subtle shadow

### Settings row

- Height: ~52px (padding 14px 16px), border-bottom: 1px `borderSoft`
- Icon tile: 32×32px, border-radius: 10px, `emeraldSoft` bg, `emerald` icon
- Amber tile: `amberSoft` bg, `amber` icon
- Gray tile: `#F0EEEA` bg, `inkSoft` icon
- Danger tile: `dangerSoft` bg, `danger` icon
- Last row in group: no border-bottom

### Progress bar

- Height: 4px, border-radius: 2px
- Track: `borderSoft`, fill: `emerald`

### Badge / chip

- Current password badge: `emerald` bg, white text, 10px font, 2px 8px padding, border-radius: 10px, "CURRENT" text
- Count badge: `emeraldSoft` bg, `emerald` text

### Search bar

- Height: 44px, border-radius: 12px, `card` bg, 1px `border`
- Search icon: `inkMute`, 20px
- Input: placeholder `inkMute`, text `ink`

### Generator card

- Background: `emeraldSoft`, border: 1px `#C8DAD3`, border-radius: 12px
- Generated password display: white bg, border-radius: 8px, IBM Plex Mono 14px
- Slider: 4px track, `#C8DAD3` background, `emerald` fill, 16px white thumb with `emerald` border
- Checkbox: 16×16px, `emerald` bg when checked, `#C8DAD3` border when unchecked

### Warning banner (amber)

- Background: `amberSoft`, border: 1px `#F2DDB3`, border-radius: 10px
- Padding: 10px 12px, font: 11–12px, color: `amber`
- Info icon: `amber`, 16px, flex-shrink 0

### Dialog / modal overlay

- Full-screen backdrop: `overlay`
- Dialog card: `card`, border-radius: 16px, padding 24px
- Max-width: 320px, centered

### Toast / snackbar

- Floating above nav bar, `ink` background, white text, border-radius: 10px
- Padding: 12px 16px, font: 13px
- Auto-dismiss: 3–4 seconds

---

## 5. Layout Principles

### Spacing scale (4px base)
`4 / 8 / 10 / 12 / 14 / 16 / 20 / 24 / 28 / 32 / 36 / 40px`

### Screen layout
- Horizontal padding: 20px (content sits at 20px from each edge)
- AppBar padding: 16–20px horizontal, 12–16px vertical
- Content top padding: 0 (AppBar provides separation)
- Content bottom padding: 20px (plus FAB clearance of ~96px on vault screen)
- Card gap (between list items): 10px
- Section group gap: 14px

### Single column always
- No multi-column layouts. One column, top-to-bottom reading order.
- Exception: side-by-side action buttons (Edit / Delete) and settings row (icon + label + control).

### Touch targets
- Minimum: 44×44px. FAB: 56px. Icon buttons: 36px with 12px border-radius.
- Copy/reveal buttons: 28px rendered, but provide 44px tap area via GestureDetector padding.

### White space philosophy
- Generous internal card padding (12–14px). Nothing cramped.
- Group related things (username + password in same card concept for an entry).
- Use spacing to signal grouping, not lines (except hairline borders on cards and settings rows).

---

## 6. Depth & Elevation

PassMgr uses **zero box-shadows** except for two specific elements:

| Element | Shadow |
|---|---|
| FAB | `0 8px 20px rgba(30,95,78,0.35)` — the only elevated element |
| Lock screen logo | `0 8px 20px rgba(30,95,78,0.25)` — subtle, matches brand color |
| Dialogs | `0 20px 60px rgba(0,0,0,0.15)` — enough to float above overlay |

All other surfaces: hairline `1px border` with `border` color. No elevation system. No layers.

Surface hierarchy: `paper` (background) → `card` (elevated content) → dialog (floating).

---

## 7. Do's and Don'ts

### Do
- Show passwords in IBM Plex Mono. Always.
- Use amber for "editing will change your history" — not red.
- Use `emerald` for the single primary action on each screen.
- Confirm every destructive action (delete, erase all) with a dialog.
- Clear clipboard automatically (20s). Show countdown in toast.
- Show recovery hint on lock screen to help users remember their password.
- Auto-lock on background with configurable timer.
- Show "CURRENT" badge on latest history item.
- Use monospace font in the generator preview.
- Keep avatars consistent: first letter of site name, emerald/amber/gray based on type.

### Don't
- Don't show passwords by default — always masked with dots.
- Don't use red for anything except delete/error/destructive actions.
- Don't use gradients, illustrations, or decorative imagery.
- Don't put more than one primary (emerald) button on a screen.
- Don't use shadows on cards — only the FAB and the lock logo get shadows.
- Don't use tabs, bottom navigation, or side drawers — this is a single-flow app.
- Don't show the recovery hint in plain text on the settings row — show it only on the lock screen.
- Don't let clipboard persist beyond 20 seconds.
- Don't allow screenshots (FLAG_SECURE is on by default, toggle only to disable).
- Don't skip the confirm dialog before delete.

---

## 8. Responsive Behavior

PassMgr targets **Android phones only**, portrait orientation.

- Design target: 360–412px wide, 720–900px tall (standard Android phones)
- No tablet or landscape optimization needed
- Touch targets: minimum 44px
- Scroll: single-column `ListView`, content scrolls under fixed AppBar
- No breakpoints. No responsive grid.
- Keyboard avoidance: forms use `resizeToAvoidBottomInset: true` (Flutter default)
- Safe area: respect Android status bar (28px) and gesture nav bar (18px pill)

---

## 9. Agent Prompt Guide

When generating Flutter code, HTML mockups, or UI descriptions for PassMgr, use these exact references:

### Color references (use these names in code/prompts)
```
background: #F5F1EA (paper)
card: #FFFFFF
border: #E4DED2
text-primary: #0F1419 (ink)
text-secondary: #4A5159 (inkSoft)
text-muted: #8A8F97 (inkMute)
accent: #1E5F4E (emerald)
accent-soft: #E8F0EC (emeraldSoft)
accent-pressed: #174A3D (emeraldDark)
warning: #B45309 (amber)
warning-soft: #FBF1E2 (amberSoft)
danger: #B91C1C
danger-soft: #FBEAEA
```

### Flutter ThemeData summary
```dart
// Primary swatch: emerald #1E5F4E
// Background: Color(0xFFF5F1EA)
// Card: Colors.white
// TextTheme: Inter
// MonoFont: IBM Plex Mono (for password fields)
// Border radius: 12px inputs, 14px cards, 16px FAB, 10px small elements
// No shadows on cards. Only FAB has elevation.
```

### Ready-to-use prompts for AI agents
- "Build a password list item using the PassMgr design system: paper background, white card, 1px #E4DED2 border, 14px radius, 40px emerald-soft avatar with first letter in Inter 600, entry name in Inter 600 14px ink, username in Inter 400 12px inkSoft, chevron right in inkMute."
- "Build a password field: 48px height, 12px radius, white bg, 1px #E4DED2 border, IBM Plex Mono 14px, eye icon right, focus border color #1E5F4E."
- "Build a settings row: 52px height, 32px emerald-soft icon tile with 10px radius, Inter 14px 500 ink label, Inter 11px inkSoft description, toggle or chevron right."
- "Use amber (#B45309) on amberSoft (#FBF1E2) background for any warning banner. Never use red for warnings."
- "The FAB is 56px, 16px radius, #1E5F4E fill, white plus icon, shadow 0 8px 20px rgba(30,95,78,0.35), positioned bottom 38px right 20px."
