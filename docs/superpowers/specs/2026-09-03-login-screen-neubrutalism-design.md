# Login Screen Neubrutalism Overhaul — Design Spec

**Date:** 2026-09-03  
**Status:** Approved by User  
**Target:** `lib/auth/sign_in_screen.dart`, `assets/stickers/`

---

## 1. Problem Statement & Goals

The existing `SignInScreen` has excessive unused white space at the bottom (taking up over 40% of the screen height on mobile devices) and appears generic beneath the primary sign-in card.

### Goals
1. **Eliminate the bottom empty void**: Transform the lower half of the screen into a rich, informative, authentic Neubrutalist campus bulletin.
2. **Redesign the Hero Panel**: Upgrade from a plain maroon box to a two-tone Neubrutalist header featuring a bold header lockup, slanted `Ga` badge, display typography, and a prominent edge-to-edge Gold ticker tape (`@umindanao.edu.ph ONLY • 0% FEES • ON-CAMPUS MEETUPS`).
3. **Clarify the Institutional Domain Requirement**: Make it immediately obvious that only `@umindanao.edu.ph` institutional Google accounts can sign in (per ADR 0001/0008 and UM policy).
4. **Campus Trading Guide ("How We Trade")**: Introduce a 3-step numbered brutal grid explaining the verified student workflow (`01 School Email`, `02 Direct Deal`, `03 On-Campus`).
5. **Campus Meetup & Safety Banner**: A dedicated Neubrutalist callout block highlighting safe physical meetup zones (Matina, Bolton, Tagum, Peñaplata; Cafeteria, Library, Gym Quad) with safety guidelines.
6. **Preserve Neubrutalist Laws & Test Contracts**: Maintain strict 2dp/3dp ink borders, zero-blur hard shadows, flat saturated color blocks, Space Grotesk/Outfit typography, and guarantee that all 103 existing automated tests continue to pass.

---

## 2. Visual & Structural Design

### A. Screen Layout Anatomy

```
Scaffold (background: UmColors.background)
└── SafeArea
    └── Column
        ├── _HeroPanel (fixed top)
        │   ├── Maroon Header Container (#7C2D12, bottom 3dp border)
        │   │   ├── Slanted 'Ga' Gold Sticker Badge (Space Grotesk 900)
        │   │   ├── Title: 'UM Marketplace' (Space Grotesk 900, 32px)
        │   │   ├── Tagline Card: 'The campus marketplace for University of Mindanao students.'
        │   │   ├── Overlapping 'starburst.svg' Sticker
        │   │   └── Slanted 'VERIFIED ONLY' Pill Badge
        │   └── Marquee Ticker Tape (Gold #FFC72C, 3dp top & bottom borders)
        │       └── '⚡ @umindanao.edu.ph ONLY ⚡ 0% FEES ⚡ ON-CAMPUS MEETUPS ⚡'
        │
        └── Expanded -> SingleChildScrollView (padding: 16dp)
            ├── _SignInCard (White fill, 2dp border, 4dp shadow)
            │   ├── BadgeCheck icon + 'Sign in to start trading'
            │   ├── Domain Gate Banner: 'Institutional Google Account Only'
            │   │   └── '@umindanao.edu.ph email required. Personal Gmail refused.'
            │   ├── NbrButton ('Sign in with Google' with Google SVG logo)
            │   └── Overlapping stickers ('bag.svg' top-right, 'tag.svg' bottom-left)
            │
            ├── SizedBox(height: 24)
            │
            ├── _HowItWorksSection
            │   ├── Header Pill: 'HOW WE TRADE' (Space Grotesk 800)
            │   ├── SizedBox(height: 12)
            │   └── 3-Tile Row:
            │       ├── Tile 01: [Mail/Shield] '@umindanao' - 'School email only'
            │       ├── Tile 02: [Message] 'Direct Deal' - '₱0 fees • 1-on-1 chat'
            │       └── Tile 03: [MapPin] 'On-Campus' - 'Matina & Bolton meetups'
            │
            ├── SizedBox(height: 20)
            │
            ├── _CampusMeetupBanner (goldSoft fill, 2dp border, 4dp shadow)
            │   ├── Header: [MapPin] 'SAFE CAMPUS MEETUPS'
            │   ├── Campus Pills: [Matina] [Bolton] [Tagum] [Peñaplata]
            │   └── Safety Tip: 'Always meet in public areas like the Cafeteria or Library. Inspect items before handoff.'
            │
            ├── SizedBox(height: 16)
            │
            └── _LoginFooter
                ├── 'Peer-to-peer • No checkout • Meet on campus'
                └── 'Exclusively for University of Mindanao Students'
```

---

## 3. Detailed Component Specifications

### 1. `_HeroPanel`
- **Top Maroon Surface**:
  - Color: `UmColors.primary` (`#7C2D12`).
  - Slanted `Ga` badge: `UmColors.gold` (`#FFC72C`), `2dp` ink border, `Offset(2, 2)` hard shadow, tilted `-4°`.
  - Title: `UM Marketplace`, Space Grotesk 900, 32px, `UmColors.onPrimary` (`#FFFFFF`).
  - Subtitle card: `UmColors.surface` (`#FFFFFF`), `2dp` border, `Offset(3, 3)` shadow, Outfit 600, 12.5px.
  - Stickers: `assets/stickers/starburst.svg` rotated `+8°` on top right; `VERIFIED ONLY` badge in `goldSoft` rotated `-6°` overlapping the divider.
- **Ticker Strip**:
  - Full width banner below the maroon surface.
  - Color: `UmColors.gold` (`#FFC72C`), with `3dp` ink top and bottom borders.
  - Text: Space Grotesk 800, 11px, letterSpacing 0.8, black ink `#000000`.

### 2. `_SignInCard`
- **Surface**: White `#FFFFFF`, `2dp` ink border, `4dp` hard black shadow, `12dp` radius.
- **Title Row**: `LucideIcons.badgeCheck500` inside a gold container + `"Sign in to start trading"` (Space Grotesk 800, 16px).
- **Institutional Gate Callout**:
  - A dedicated container inside the card with `goldSoft` (`#FEF3C7`) fill, `1.5dp` ink border, `6dp` radius.
  - Text: Outfit 600/500, explicitly highlighting `@umindanao.edu.ph` requirement so users do not attempt personal Gmail accounts.
- **Action**: `NbrButton` with `assets/logos/google_g.svg`, white fill, 2dp border, 4dp shadow, full width.

### 3. `_HowItWorksSection`
- **Section Badge**: Centered pill: `"HOW WE TRADE"`, Space Grotesk 800, 11px, gold fill with ink border.
- **Grid Tiles**: 3 equal-width flex tiles:
  - Fill: `UmColors.goldSoft` (`#FEF3C7`), `2dp` ink border, `3dp` hard shadow, `8dp` radius.
  - Number label: Space Grotesk 900, 10px in a tiny black pill or accent text.
  - Icon: Lucide chunky 500 icon (mail, message, mapPin).
  - Title: Space Grotesk 700, 12px, ink black.
  - Description: Outfit 500, 10px, muted foreground / dark ink.

### 4. `_CampusMeetupBanner`
- **Surface**: `UmColors.goldSoft`, `2dp` ink border, `4dp` hard shadow, `8dp` radius, padded 14dp.
- **Header**: `LucideIcons.mapPin500` in primary maroon + `"SAFE CAMPUS MEETUPS"` (Space Grotesk 800, 13px).
- **Campus tags**: Horizontal wrap of mini-pills (`Matina`, `Bolton`, `Tagum`, `Peñaplata`), white fill, `1.5dp` border.
- **Safety tip**: Outfit 500, 11px: *"Meet at high-visibility campus spots: Cafeteria, Library, or Gym Quad. Inspect before you pay."*

### 5. `_LoginFooter`
- Centered captions in Outfit 600, 11px, `UmColors.mutedForeground`.

---

## 4. Asset Additions

New SVG stickers created in `assets/stickers/`:
1. `shield.svg`: Neubrutalist gold shield with 4px ink border and center checkmark.
2. `pin.svg`: Neubrutalist campus location pin with 4px ink border.

---

## 5. Verification & Testing

- **Automated Tests**:
  - Run `flutter test` and ensure all 103 tests pass.
  - Verify `shows the Google sign-in gate when signed out` finds `'Sign in with Google'`, `'UM Marketplace'`, and `'Ga'`.
  - Verify `flutter analyze` produces 0 issues with `flutter_lints ^6.0.0`.
- **Manual Verification**:
  - Check rendering on standard and tall portrait surfaces to ensure no overflow errors.
