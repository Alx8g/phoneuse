---
name: Phone Use
description: The phoneuse.tech site, a warm paper page in the app icon's palette (berry plum, amber, coral, cream) with soft clay renders multiplied onto the ground.
colors:
  plum: "#9a3c69"
  plum-hi: "#7b354e"
  plum-deep: "#712a4d"
  amber: "#fda55e"
  amber-tint: "#ffe4cc"
  coral-tint: "#fde0dc"
  coral-ink: "#a8433f"
  plum-tint: "#f6e0ea"
  bg: "#fff7f0"
  cream: "#feead9"
  line: "#f0d9c8"
  ink: "#3a1a2e"
  ink-2: "#6b4558"
  ink-3: "#80586a"
  white: "#ffffff"
  error: "#b3261e"
typography:
  display:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "clamp(44px, 5.6vw, 76px)"
    fontWeight: 600
    lineHeight: 1.02
    letterSpacing: "-0.04em"
  display-page:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "clamp(40px, 6vw, 60px)"
    fontWeight: 600
    letterSpacing: "-0.04em"
  headline:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "clamp(32px, 4vw, 48px)"
    fontWeight: 600
    lineHeight: 1.08
    letterSpacing: "-0.025em"
  title:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "20px"
    fontWeight: 600
    letterSpacing: "-0.025em"
  title-small:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    letterSpacing: "-0.015em"
  lead:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "clamp(19px, 1.7vw, 21px)"
    fontWeight: 400
    lineHeight: 1.55
  body:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.55
  tile-text:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
  small:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.55
  label:
    fontFamily: "Geist, system-ui, -apple-system, sans-serif"
    fontSize: "16px"
    fontWeight: 500
    lineHeight: 1
rounded:
  focus: "6px"
  icon: "8px"
  tile: "24px"
  panel: "32px"
  pill: "999px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "24px"
  xl: "36px"
  gutter: "clamp(20px, 5vw, 64px)"
  section: "clamp(80px, 11vw, 140px)"
components:
  button-primary:
    backgroundColor: "{colors.plum}"
    textColor: "{colors.white}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "0 24px"
    height: "48px"
  button-primary-hover:
    backgroundColor: "{colors.plum-hi}"
    textColor: "{colors.white}"
  button-quiet:
    backgroundColor: "{colors.cream}"
    textColor: "{colors.plum-deep}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "0 24px"
    height: "48px"
  button-quiet-hover:
    backgroundColor: "#fbdcc4"
    textColor: "{colors.plum-deep}"
  button-small:
    backgroundColor: "{colors.plum}"
    textColor: "{colors.white}"
    rounded: "{rounded.pill}"
    padding: "0 18px"
    height: "38px"
  status-tag:
    backgroundColor: "{colors.coral-tint}"
    textColor: "{colors.coral-ink}"
    rounded: "{rounded.pill}"
    padding: "4px 12px"
  use-case-tile:
    backgroundColor: "{colors.cream}"
    textColor: "{colors.ink}"
    rounded: "{rounded.tile}"
    padding: "22px 22px 24px"
  use-case-tile-amber:
    backgroundColor: "{colors.amber-tint}"
  use-case-tile-coral:
    backgroundColor: "{colors.coral-tint}"
  use-case-tile-plum:
    backgroundColor: "{colors.plum-tint}"
  input-email:
    backgroundColor: "{colors.white}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "0 18px"
    height: "48px"
  download-tile:
    backgroundColor: "{colors.cream}"
    textColor: "{colors.ink}"
    rounded: "{rounded.tile}"
    padding: "28px 20px"
  control-panel:
    backgroundColor: "{colors.plum}"
    rounded: "{rounded.panel}"
    padding: "clamp(32px, 6vw, 72px) clamp(20px, 4vw, 48px)"
  activity-card:
    backgroundColor: "rgba(42, 14, 32, .92)"
    textColor: "{colors.white}"
    rounded: "{rounded.tile}"
    padding: "18px"
  activity-button:
    backgroundColor: "{colors.white}"
    textColor: "{colors.plum}"
    rounded: "{rounded.pill}"
    padding: "11px"
  activity-button-quiet:
    backgroundColor: "rgba(255, 255, 255, .14)"
    textColor: "{colors.white}"
    rounded: "{rounded.pill}"
    padding: "11px"
---

# Design System: Phone Use

## Overview

**Creative North Star: "The Calm Shelf Product"**

Phone Use presents itself as a finished consumer product: one plain sentence, two downloads, and a few charming clay renders of the cloud character using a phone. Every colour on the page is sampled from the app icon and the hero render. The ground is a warm paper a shade lighter than the cloud, tiles are cloud cream, and pale amber, coral and plum tints rotate across the use-case tiles. A berry plum marks everything you can press and fills the one large control panel. Text is set in plum-tinted inks, so even the neutrals belong to the icon's world. The renders are multiplied onto the paper, so their white ground disappears and the cloud, laptop and phones sit directly on the page.

Density is low. Sections are split into two columns or centered, separated by generous vertical space instead of rules or bands. Copy is short: a headline, one supporting sentence, and an action. The owner pinned flat colour with no gradients, minimal copy, Geist, and stylized renders like the app icon; the owner then asked for the palette to come from the icon and the hero render, which replaced the earlier white page and single dark plum.

**Key Characteristics:**
- Warm paper ground (`#fff7f0`) with cream tiles and plum-tinted inks; every hue is sampled from the app icon.
- Berry plum is the one saturated colour in the UI: buttons, links, focus, and the control panel.
- Amber, coral and plum appear on surfaces only as pale tints, rotating across the use-case tiles.
- Flat colour fills everywhere in the UI; depth and modelling come from the renders.
- Geist alone, weight 600 for headings with tight negative tracking.
- Every control is a full pill; containers are large soft rectangles (24px and 32px).
- Clay renders multiplied onto the page ground, unframed.

## Colors

A warm, icon-sampled palette: paper and cream grounds, plum-tinted inks, pale amber, coral and plum tints for tiles, and one berry plum for action.

### Primary
- **Berry Plum** (plum): primary buttons, links, the focus ring, list markers, the sent-state form note, the email field's focus stroke and caret, the skip link, the text of the white Allow and Take over buttons, and the fill of the control panel. White text on it reaches 6.5:1.
- **Pressed Berry** (plum-hi): hover state for primary buttons and links only.
- **Deep Plum** (plum-deep): the text of quiet buttons on cream. It is also the colour of the phone frames in the renders, which is why it reads as part of the same object.

### Secondary
- **Amber Tint** (amber-tint), **Coral Tint** (coral-tint), **Plum Blush** (plum-tint): pale surface tints from the icon's amber, coral and berry sky. They fill the second, third and fourth use-case tiles in each row. Coral Tint is also the status tag's fill, and Plum Blush is the 3px focus halo around the email field.
- **Coral Ink** (coral-ink): the status tag's text, a deepened coral that reaches 4.8:1 on Coral Tint.
- **Icon Amber** (amber): text selection highlight only, with Plum Ink text.

### Neutral
- **Warm Paper** (bg): the page ground and the browser theme colour; renders are multiplied onto it.
- **Cloud Cream** (cream): use-case tiles (first of each four), download tiles, and quiet buttons. Its hover deepens to `#fbdcc4`.
- **Paper White** (white): input fields and the text on plum buttons.
- **Hairline** (line): the footer's top rule. It is decorative only; at 1.3:1 on the page it cannot mark a control's boundary.
- **Plum Ink** (ink): headings, the brand name, tile titles, lede text on legal pages.
- **Muted Ink** (ink-2): body copy under headings, nav links, tile text, legal paragraphs. It holds 6.4:1 or better on every tint.
- **Quiet Ink** (ink-3): fine print (hero note, dates, "Coming soon", version line, placeholder text). It reaches 5.6:1 on the page and 5.1:1 on cream; keep any new tertiary text at or above 4.5:1.
- **Error Red** (error): the failed-state form message only.

### Named Rules
**The Icon Palette Rule.** Every colour comes from the app icon or the hero render. Berry plum is the only saturated colour in the interface; amber, coral and plum reach surfaces only as pale tints, and full-strength amber appears only as the selection highlight.

**The Tint Rotation Rule.** Use-case tiles cycle cream, amber tint, coral tint, plum tint in that order, so each row of four shows all four. Text on every tint stays in Plum Ink and Muted Ink.

**The Flat Fill Rule.** UI surfaces are flat colours with no CSS gradients. The shading inside the clay renders is part of the image, not a license for gradient fills.

## Typography

**Display Font:** Geist (with system-ui, -apple-system, sans-serif)
**Body Font:** Geist (same stack)

**Character:** One neutral grotesque used in three weights for structure (600 for headings, 500 for controls, 400 for text). Large headings tighten to -0.04em, which makes the page read as a product site rather than a document.

### Hierarchy
- **Display** (600, clamp(44px, 5.6vw, 76px), 1.02, -0.04em): the home hero headline, which breaks over three lines in the left column of the hero split.
- **Display Page** (600, clamp(40px, 6vw, 60px), -0.04em): page titles on legal, 404 and confirmation pages (404 and confirmation go to 64px max).
- **Headline** (600, clamp(32px, 4vw, 48px), 1.08, -0.025em): section headings, usually a short sentence ending in a period.
- **Title** (600, 20-24px, -0.025em): download tile platform names (20px) and legal subheads (24px).
- **Title Small** (600, 17px, -0.015em): use-case tile titles.
- **Lead** (400, clamp(19px, 1.7vw, 21px), 1.55): the hero subhead in Muted Ink, capped at 30ch; the use-case subhead runs 18-20px; legal ledes use 20px in Plum Ink.
- **Body** (400, 18px, 1.55; 17px under 520px): paragraph text in Muted Ink, 40ch in marketing sections and 68ch on legal pages.
- **Tile Text** (400, 15px, 1.45): use-case descriptions in Muted Ink.
- **Small** (400, 14px): notes, dates, version lines, form messages, footer.
- **Label** (500, 16px, line-height 1): button text; 15px on small buttons, 13px on the status tag.

### Named Rules
**The Single Family Rule.** Geist sets everything; headings never go heavier than 600, and hierarchy comes from size and tracking.

**The Short Measure Rule.** Text blocks are capped in ch (30ch lead, 40ch body, 46ch fine print, 68ch legal) and headings use balanced wrapping.

## Layout

Content sits in a centered column with a 1160px max width and a fluid gutter (clamp(20px, 5vw, 64px)). The home page alternates two-column splits and centered blocks: the hero is a 5:6 split with copy on the left and the render on the right, the use cases are centered with a four-column tile grid, the control section is a 5:6 split, the bridge a 1:1 split with the render on the left, and the downloads are centered with a four-column tile grid. Splits are vertically centered. Sections are separated by large padding (clamp(80px, 11vw, 140px); the use-case section uses clamp(72px, 10vw, 128px)) rather than dividers; the footer's hairline is the only rule. Tile grids use 14px gaps for use cases and 16px for downloads. Legal pages narrow to 720px, and the 404 and confirmation pages narrow to 640px, centered.

Renders fill their column width.

Responsive: at 860px and below, all splits stack to one column, the hero centers its copy and actions, and both tile grids become two columns. At 520px and below, the use-case grid becomes one column, body drops to 17px, the header keeps only the Download button, and hero and signup buttons go full width.

## Elevation & Depth

The interface is flat. Surfaces separate by fill (warm paper, cream and tints, berry plum) and by space, not by shadow. Depth on the page comes from the clay renders, which carry their own soft contact shadows into the page through the multiply blend.

### Shadow Vocabulary
- **Device Glass** (`box-shadow: 0 24px 48px -20px rgba(0, 0, 0, .55)`): only on the two iOS cards in the control panel, because they depict system objects floating on the plum panel.
- **Field Halo** (`box-shadow: 0 0 0 3px` Plum Blush, with a Berry Plum border): focus state of the email field.

### Named Rules
**The Renders Carry Depth Rule.** Cards, tiles and buttons have no drop shadows. Shadows appear only on depictions of a device object or as a focus halo.

## Shapes

Every control is a full pill (999px): buttons, the email field, the status tag, the skip link, and the Allow, Deny and Take over buttons in the control panel. Containers are soft, large-radius rectangles: 24px for use-case tiles, download tiles and the iOS cards, 32px for the control panel. The app icon is shown with 8px corners at 32px (10px at 44px). Focus outlines are 2px Berry Plum, offset 3px, with 6px corners. There are no borders on containers.

## Components

### Buttons
Soft, solid pills with no outline.
- **Shape:** full pill (999px), 48px tall, 24px side padding.
- **Primary:** Berry Plum fill, white Geist 500 at 16px. Used for downloads and the form submit.
- **Hover / Focus / Active:** fill shifts to Pressed Berry over 0.2s; press scales to 0.98 on the ease-out curve `cubic-bezier(.16, 1, .3, 1)` over 0.3s; focus shows the global 2px plum ring. Disabled drops to 60% opacity.
- **Quiet:** Cloud Cream fill with Deep Plum text, for the secondary choice beside a primary (Download for Mac). Hover deepens the cream.
- **Small:** 38px tall, 18px padding, 15px text, for the header's Download.

### Status Tag
A Coral Tint pill with Coral Ink text (13px, weight 500, 4px 12px padding) that carries product status, currently "Alpha" above the hero headline. It states a fact about the product; it is not a section label.

### Use-Case Tiles
- **Corner Style:** 24px.
- **Background:** rotating Cloud Cream, Amber Tint, Coral Tint, Plum Blush (The Tint Rotation Rule); no border, no shadow.
- **Internal Padding:** 22px 22px 24px; a Title Small in Plum Ink over a Tile Text description in Muted Ink, left-aligned.

### Download Tiles
- **Corner Style:** 24px.
- **Background:** Cloud Cream, no border, no shadow.
- **Internal Padding:** 28px 20px, minimum 150px tall, contents centered in a column: platform name as Title, then the action (primary button, App Store badge, or "Coming soon" in Quiet Ink).

### Inputs / Fields
- **Style:** white pill on the warm page, 48px tall, 18px padding, Geist 16px, Berry Plum caret, Quiet Ink placeholder, 1px stroke `#b0899a`. A field's resting stroke should reach 3:1 against the page ground.
- **Focus:** stroke turns Berry Plum and a 3px Plum Blush halo appears; the default outline is removed.
- **Messages:** a 14px note below the row, Muted Ink by default, Berry Plum when sent, Error Red when failed.

### Navigation
Header: the app icon (32px, 8px corners) and "Phone Use" in Plum Ink at 600 on the left; on the right, 15px Muted Ink text links that turn Plum Ink on hover, followed by a small primary button. Under 520px only the button remains. Footer: brand, then Muted Ink links at 14px, above a hairline top border.

### Control Panel (signature)
A Berry Plum panel (32px corners) that stacks two mock iOS cards 14px apart. Both cards are near-black plum glass (`rgba(42, 14, 32, .92)`, 24px corners, Device Glass shadow) with the app icon at 44px, a 13px caption in `#c9bccd`, a 19px action line at 600, and a 13px tabular status line.
- **Request card:** "Agent requests control" with a two-column pair of pill buttons: Deny in translucent white (`rgba(255, 255, 255, .14)`) with white text, Allow in white with Berry Plum text.
- **Live Activity card:** the running step and time, with one full-width white "Take over" pill in Berry Plum text.
The panel is the one place the page fills a large area with plum.

### Clay Renders
Soft-3D clay in the app icon's palette: the cloud character, a cream laptop and deep plum phones showing a home-screen grid of soft-coloured app tiles. The bridge render pairs a clay-style plum bridge case with a realistic iPhone, as the owner asked. Renders are generated on a light ground and shown with `mix-blend-mode: multiply`, so the ground takes on the page's warm paper and the image has no visible edge. They fill their column in a split.

## Do's and Don'ts

### Do:
- **Do** keep the page on Warm Paper and use Berry Plum for every primary action, link and focus ring.
- **Do** pair a primary Berry Plum button with a Cloud Cream quiet button when two choices are equal in kind (Linux and Mac).
- **Do** rotate cream, amber, coral and plum tints across a set of equal tiles, in that order.
- **Do** make every control a full pill (999px) and every container a 24px or 32px rounded rectangle without border or shadow.
- **Do** set all type in Geist, headings at 600 with -0.025em to -0.04em tracking.
- **Do** keep copy to a heading, one sentence and an action per section.
- **Do** generate new imagery as soft-3D clay renders in the app icon's palette on a light ground, and show it with `mix-blend-mode: multiply` so it sits on the page unframed.
- **Do** keep tertiary text at 4.5:1 or better on every ground it sits on (Quiet Ink is the floor).

### Don't:
- **Don't** use CSS gradients on any UI surface or text.
- **Don't** fill controls or set text in full-strength amber or coral; those hues reach the interface as pale tints, plus Coral Ink inside the status tag.
- **Don't** add drop shadows to tiles, buttons or sections; shadows belong only to device depictions and the field focus halo.
- **Don't** put a small label or tag above section headings; the status tag is reserved for product status.
- **Don't** use weights above 600 or a second typeface for display.
- **Don't** frame renders in cards or tinted boxes, or show them without the multiply blend; a white rectangle around a render breaks the page.
