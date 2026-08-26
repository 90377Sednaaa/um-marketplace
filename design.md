# UM Marketplace — Visual Design Spec

The design look of the app: University of Mindanao–branded campus marketplace.
Light theme only. Brand palette: **Maroon · Gold · White**.

> Hex values below are grounded in WCAG-checked pairs from a curated palette
> database ("deep burgundy + craft gold"). If official UM brand assets become
> available, re-tune `primary` to match the logo and re-check contrast (≥ 4.5:1).

## 1. Design direction

- **Style:** Vibrant & block-based — energetic, youthful, high-contrast. Fits a student buy-and-sell audience without looking like a toy.
- **Feel:** Campus-official (maroon/gold) meets modern marketplace (search-first, deal badges, visual categories).
- **Conversion focus:** The search bar is the hero CTA of the home screen. Reduce friction to search; popular-search suggestions directly beneath it.

## 2. Color system

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#7C2D12` | UM maroon. App bar tint, primary buttons, active nav, links |
| `onPrimary` | `#FFFFFF` | Text/icons on maroon |
| `secondary` | `#A16207` | Gold accent (darkened from `#CA8A04` for 3:1 contrast). Badges, highlights, seller/verified marks |
| `onSecondary` | `#FFFFFF` | Text/icons on gold |
| `secondaryContainer` | `#FEF3C7` | Soft gold wash: banners, featured chips, promo blocks |
| `surface` / `card` | `#FFFFFF` | Cards, sheets, bars |
| `background` | `#FFFFFF` | Screen background (white keeps listings clean; reserve tints for sections) |
| `onSurface` / `foreground` | `#450A0A` | Warm near-black body text |
| `muted` | `#ECEDF0` | Placeholder fills, dividers' backgrounds, skeletons |
| `mutedForeground` | `#64748B` | Secondary text: timestamps, subtitles, hints |
| `outline` / `border` | `#E7E5E4` | Card borders, input outlines, dividers |
| `success` / `price` | `#16A34A` | Prices, "deal" indicators, availability |
| `destructive` | `#DC2626` | Errors, delete actions |

Rules:
- White space does the separating; avoid tinting whole screens — maroon appears as *blocks and accents*, not backgrounds everywhere.
- Never place gold text on white (`#A16207` on white is for fills/badges with white text, not body copy).
- Prices always `success` green; discounts additionally get a gold `secondaryContainer` badge.

### Flutter mapping
Use Material 3: `ColorScheme.fromSeed(seedColor: Color(0xFF7C2D12))` then override `secondary`→`#A16207`, `error`→`#DC2626`. Load fonts via the `google_fonts` package.

## 3. Typography

Single family: **Outfit** (geometric sans — modern, distinctive headings, clean body).

| Role | Weight | Size | Notes |
|---|---|---|---|
| Display / hero | 800 | 32–36 px | Screen heroes, big promos |
| Headline | 700 | 24 px | Section titles |
| Title | 600 | 16–18 px | Card titles, list items, app bar |
| Body | 400 | 14–15 px | Descriptions, line-height ≥ 1.45 |
| Label / caption | 500 | 12–13 px | Prices context, timestamps, chips |

Anti-pattern: no all-caps body text; uppercase reserved for small labels/badges.

## 4. Spacing, shape & iconography

- **Spacing grid:** 4 dp base. Screen padding 16 dp; intra-card gaps 8–12 dp; section gaps 24–32 dp.
- **Corner radii:** cards 16 dp · buttons 12 dp · search bar & chips 999 (pill).
- **Touch targets:** ≥ 48×48 dp with ≥ 8 dp spacing (Material minimum).
- **Icons:** Material Symbols Rounded (outline style), consistent 24 dp. **Never emoji as UI icons.**
- **Elevation:** flat-first; shadow only for floating elements (FAB, dragged cards). Prefer borders/tints over shadows for depth.

## 5. Core components

- **Search bar:** pill, `muted` fill, leading search icon, maroon focus ring; sits at top of Home with popular-search chips under it.
- **Product card:** white, 16 dp radius, 1 dp `outline` border; image top (4:3, `BoxFit.cover`, placeholder while loading); title 600; **price in green 700**; condition/location caption in `mutedForeground`; optional gold badge row (e.g. "Negotiable", category chip).
- **Category tiles:** icon-in-tile grid (maroon icon on `secondaryContainer` circle), label below.
- **Buttons:** Primary = maroon filled, white label, 12 dp radius. Secondary = white filled with `outline` border. On maroon surfaces = white filled with maroon label. Disabled = `muted` fill, `mutedForeground` label. All ≥ 48 dp tall, pressed state 150 ms.
- **Badges/chips:** pill; gold `secondaryContainer` for promos/seller status; `muted` for filters.
- **Bottom navigation:** ≤ 5 items, maroon active icon+label, `mutedForeground` inactive: Home · Browse · **Sell (center FAB-style action)** · Chats · Profile.
- **Empty/error states:** friendly illustration or large outline icon, one-line message, single recovery button (maroon).

## 6. Screen inventory (v1)

1. **Home** — hero search + popular searches, category tile grid, featured/recent listings feed
2. **Browse/Search results** — filter chips (category, price, condition), listing cards in 2-column grid
3. **Product detail** — image carousel, price block, seller strip (avatar, name, verified badge, "View profile"), description, safety tips footer, sticky bottom bar: Chat + Buy/Offer buttons
4. **Sell / List an item** — step form: photos → details → price → publish; progress indicator
5. **Auth** — sign in / register (email first), UM-branded maroon header panel
6. **Chats** — conversation list → thread with product snippet pinned
7. **Profile** — avatar, ratings, my listings, settings

## 7. Motion

- Durations 150–300 ms, standard easing; motion must convey meaning (page transitions, confirmation feedback).
- Feed items: subtle fade/slide stagger on first load only. Respect reduced-motion settings.

## 8. Accessibility checklist

- [ ] Body text contrast ≥ 4.5:1 (`#450A0A` on white ≈ 13:1 ✓; `#64748B` on white ≈ 4.8:1 ✓)
- [ ] Gold never used for small text on white
- [ ] Touch targets ≥ 48 dp
- [ ] Visible focus/pressed states on every interactive element
- [ ] Image placeholders + alt semantics via semantics labels
