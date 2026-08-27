# UM Marketplace — Visual Design Spec

The design look of the app: University of Mindanao–branded campus marketplace.
Light theme only. Brand palette: **Maroon · Gold · White · Ink Black**.

## 1. Design philosophy

**Neubrutalism, campus edition.** Raw, bold, and unpretentious — thick black outlines,
hard offset shadows, flat saturated color blocks, zero gradients. It looks hand-made and
honest, which matches what a student marketplace is: classmates trading stuff directly,
no corporate polish between them.

**Target users: University of Mindanao students.** Price-sensitive, mobile-first,
scanning between classes. They buy and sell textbooks, gadgets, org merch, dorm
essentials, review materials. Design implications:

- Fast scanning over decoration — prices and condition visible without tapping.
- Listing an item must feel like posting a sticker, not filling out paperwork.
- Trust cues matter (verified-student badge) because transactions are peer-to-peer.
- Playful "sticker-book" energy is welcome; subtle gray corporate minimalism is not.

### The neubrutalist laws (non-negotiable)

1. **Thick black borders** on every interactive/major element (ink `#000000`).
2. **Hard offset shadows** — solid black, offset equal on x/y, **blur radius 0**. No soft shadows anywhere.
3. **Mechanical press** — on tap-down, the element translates onto its shadow (offset collapses); releases with a snap. Spring/linear curves only.
4. **Flat color blocks** — no gradients, no blurs, no translucent frosted effects.
5. **Bold type** — heavy weights (600–900); body never thinner than 400.
6. **Sticker energy** — badges and promo tags may sit slightly rotated (-2°/+2°), overlapping card edges like slapped-on stickers.

## 2. Color system

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#7C2D12` | UM maroon. Filled blocks: primary buttons, app bar tint, active nav, hero panels |
| `onPrimary` | `#FFFFFF` | Text/icons on maroon |
| `gold` | `#FFC72C` | Vivid UM gold **fills carrying black ink** — highlight blocks, deal badges, Sell accents |
| `goldSoft` | `#FEF3C7` | Pale gold wash for chips, banners, category tile fills |
| `surface` / `card` | `#FFFFFF` | Cards, sheets, bars |
| `background` | `#FFFFFF` | Screen canvas |
| `onSurface` | `#450A0A` | Warm near-black body text |
| `muted` | `#ECEDF0` | Skeletons, placeholder fills |
| `mutedForeground` | `#64748B` | Secondary text: timestamps, captions, hints |
| `ink` | `#000000` | All borders and hard shadows |
| `success` / `price` | `#15803D` | Prices, availability — AA-safe on white (≈4.6:1) at any size |
| `destructive` | `#DC2626` | Errors, delete actions |

Rules:
- Maroon and gold are **fills behind black-outlined content**, not thin tints. A card is either white, maroon, gold, or `goldSoft` — never "slightly tinted".
- Gold always carries black ink (`#000` on `#FFC72C` ≈ 11:1 contrast ✓). Never white text on gold.
- Prices always green; discounted items additionally get a rotated gold sticker badge ("−20%").
- White space separates sections; color blocks carry meaning (maroon = action, gold = attention).

> Hex grounding: maroon pairings WCAG-checked via curated palette database
> ("deep burgundy + craft gold"); gold/neubrutalism treatment per style database
> "Neo Brutalism (Mobile)". Re-tune `primary` if official UM brand assets arrive.

## 3. Typography

Single family: **Outfit** (geometric sans — chunky enough to hold its own against heavy borders).

| Role | Weight | Size | Notes |
|---|---|---|---|
| Display / hero | 800–900 | 32–36 px | Uppercase allowed for promos |
| Headline | 700 | 24 px | Section titles |
| Title | 600 | 16–18 px | Card titles, app bar, buttons |
| Body | 400 | 14–15 px | Descriptions, line-height ≥ 1.45 |
| Label / caption | 500–600 | 12–13 px | Timestamps, chips, sticker badges |

Anti-patterns: light/thin weights anywhere; all-caps paragraphs (caps reserved for heroes and small labels).

## 4. Borders, shape & spacing

- **Border widths:** 2 dp standard on every major element; 3 dp on hero/featured surfaces (search bar, primary CTA panel).
- **Hard shadow offsets:** 3 dp resting on small elements (chips, inputs), 4 dp on cards/buttons, 6 dp on floating highlights. Always `BoxShadow(color: ink, offset: Offset(n, n), blurRadius: 0)`; the shadow sits inside the element's layout box (add matching padding/margin so nothing clips).
- **Corner radii:** blocks/cards/buttons 8 dp (near-square, softened for phones) · badges/stickers/chips pill (999). Pure 0 dp is the strict web form — avoid going rounder than 8 dp.
- **Spacing grid:** 4 dp base; screen padding 16 dp; intra-card gaps 8–12 dp; section gaps 24–32 dp.
- **Touch targets:** ≥ 48×48 dp with ≥ 8 dp gaps.
- **Icons:** Material Symbols Rounded (outline), 24 dp, drawn with weight ≥ 500 so they survive next to thick borders. Never emoji as UI icons.
- **Rotation:** only badges/stickers (-2°/+2°); structural cards stay straight.

## 5. Core components

- **Search bar (hero):** pill, white fill, 3 dp ink border, 4 dp hard shadow, leading search icon; focus ring replaced by shadow growth (4→6 dp). Popular-search chips beneath.
- **Product card:** white fill, 2 dp ink border, 4 dp hard shadow, 8 dp radius; image top (4:3 cover); title 600; **price in `#15803D` green, weight 800**; condition/location caption `mutedForeground`; gold rotated sticker for discounts; category chip `goldSoft`.
- **Category tiles:** `goldSoft` fill circle + maroon icon inside an ink-bordered square tile.
- **Buttons:** all filled blocks with 2 dp ink border + 4 dp hard shadow + mechanical press (translate +3,+3; shadow collapses).
  - Primary: maroon fill, white label.
  - Accent: gold fill, black label (Sell / Offer actions).
  - Secondary: white fill, black label.
  - Destructive: red fill `#DC2626`, white label.
  - Disabled: `muted` fill, `mutedForeground` label, shadow removed entirely (flat = dead).
- **Badges/stickers:** pill, gold or white fill, 2 dp border, rotated ±2°, may overlap the card edge they annotate.
- **Verified-student badge:** a gold pill on every seller strip declaring uniform membership — every member passed the UM email gate (ADR 0001), so the badge is a platform marker, not an earned distinction.
- **Bottom navigation:** white bar, 2 dp ink top border (full-width edge), ≤ 5 items; active item = maroon icon+label sitting on a `goldSoft` pill; inactive `mutedForeground`. v1 ships 4 items — Home, Sell, Chats, Profile (Browse is reached via search, not a tab); the notification bell lives in the Home app bar, never in the nav.
- **Inputs:** white fill, 2 dp ink border, 3 dp shadow; error state swaps border to red and shows message beside field in red 500-weight.
- **Empty/error states:** big outline icon in an ink-bordered square, one-line message, single recovery button (primary).

## 6. Screen inventory (v1)

1. **Home** — hero search + popular searches (static chips in v1), category tile grid, recent listings feed; notification bell top-right with unread count in a gold sticker
2. **Browse/Search results** — results of a text query with **category chips only** in v1 (price/condition filters deferred), product cards in 2-column grid
3. **Product detail** — image frame (v1: single hero photo with a "1/3" count badge; carousel deferred), price block, seller strip (avatar, name, verified-student badge, rating as ★ avg · trade count, view profile), description, safety tips footer, sticky bottom bar: **Chat + Make an offer** — there is no Buy action; the app never handles money (ADR 0002)
4. **Sell / List an item** — step form: photos → details → price → publish; progress shown as filled blocks
5. **Auth** — Google Sign-In only (ADR 0008); maroon header panel with logo lockup, ink-bordered form card. Google proves the account owns a UM address; accounts are refused unless the address matches the student format `initial.surname.######@umindanao.edu.ph` (ADR 0001)
6. **Chats** — conversation list → thread with pinned product snippet card; "Make an offer" sends an offer-typed message with a price on the thread; after a Listing is marked Sold, a rating prompt appears in the thread (stretch, ADR 0004)
7. **Profile** — avatar, rating summary (★ avg · trade count), my listings (with mark-Sold), settings; a **Moderation row appears only for the Admin** and opens screen 9 — every user is an ordinary member first (ADR 0003)
8. **Notification center** — pushed from the Home bell; list of notifications (offer, message, sold, rating) with unread items marked by a gold sticker; empty state per the empty/error component (ADR 0005)
9. **Moderation (Admin)** — one screen: open reports (reporter, reported, listing/chat, reason) each with hide-listing and ban-user actions, plus member lookup by display name; unreachable for ordinary members (ADR 0003)

## 7. Motion

- **Mechanical press everywhere:** tap-down translates the element onto its shadow; release snaps back. 80–120 ms, linear/spring curves only.
- Screen transitions: quick slide/fade 150–200 ms. Feed first-load: short stagger.
- Sticker badges may "slap" into place (scale 1.1→1.0 with overshoot) once.
- No parallax, no blur transitions, no infinite marquees in v1. Respect reduced-motion settings.

## 8. Accessibility checklist

- [ ] Body text contrast ≥ 4.5:1 (`#450A0A` on white ≈ 13:1 ✓; `#64748B` on white ≈ 4.8:1 ✓; black on gold ≈ 11:1 ✓; price green `#15803D` on white ≈ 4.6:1 ✓)
- [ ] Gold never carries white text; maroon never carries gold text
- [ ] Touch targets ≥ 48 dp; press feedback always visible (mechanical press doubles as feedback)
- [ ] Focus states: 3 dp ink border swap (never remove)
- [ ] Image placeholders + semantics labels for listings
