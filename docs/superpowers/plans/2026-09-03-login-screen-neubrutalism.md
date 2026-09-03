# Login Screen Neubrutalism Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Login Screen into an authentic, high-contrast Neubrutalist campus bulletin, eliminating the empty bottom void with a two-tone hero + ticker tape, clear `@umindanao.edu.ph` domain gate, 3-step "How We Trade" grid, and a campus meetup & safety banner.

**Architecture:** Refactor `lib/auth/sign_in_screen.dart` into well-isolated, modular widgets (`_HeroPanel`, `_SignInCard`, `_HowItWorksSection`, `_CampusMeetupBanner`, `_LoginFooter`) adhering to `DESIGN.md` Neubrutalist laws (thick black borders, 0-blur hard offset shadows, flat color blocks, Google Fonts Space Grotesk and Outfit). Add complementary SVG sticker assets in `assets/stickers/`.

**Tech Stack:** Flutter, `google_fonts`, `flutter_svg`, `lucide_icons_flutter`, `flutter_test`.

## Global Constraints

- Android is the target platform.
- Strictly adhere to `DESIGN.md`: ink border (`#000000`), hard shadows with `blurRadius: 0`, color palette (`UmColors.primary #7C2D12`, `UmColors.gold #FFC72C`, `UmColors.goldSoft #FEF3C7`, `UmColors.surface #FFFFFF`, `UmColors.ink #000000`).
- The login gate must strictly emphasize `@umindanao.edu.ph` institutional Google accounts (ADR 0001/0008).
- Existing test contracts in `test/widget_test.dart` MUST continue to pass: expects `'Sign in with Google'`, `'UM Marketplace'`, and `'Ga'`.
- All 103 existing tests must pass and `flutter analyze` must report 0 issues.

---

### Task 1: Create Neubrutalist SVG Sticker Assets

**Files:**
- Create: `assets/stickers/shield.svg`
- Create: `assets/stickers/pin.svg`

**Interfaces:**
- Consumed by: `SvgPicture.asset('assets/stickers/shield.svg')` and `SvgPicture.asset('assets/stickers/pin.svg')`.
- Produces: 100x100 SVG vector stickers styled with 4px ink stroke (`#000000`) and `#FFC72C` gold fill, matching `assets/stickers/bag.svg` and `starburst.svg`.

- [ ] **Step 1: Create `assets/stickers/shield.svg`**

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <path d="M50 10 L82 22 V50 C82 70 50 90 50 90 C50 90 18 70 18 50 V22 Z" fill="#FFC72C" stroke="#000000" stroke-width="4" stroke-linejoin="round"/>
  <path d="M36 48 L46 58 L66 38" fill="none" stroke="#000000" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

- [ ] **Step 2: Create `assets/stickers/pin.svg`**

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <path d="M50 90 C50 90 20 58 20 38 A30 30 0 1 1 80 38 C80 58 50 90 50 90 Z" fill="#FFC72C" stroke="#000000" stroke-width="4" stroke-linejoin="round"/>
  <circle cx="50" cy="38" r="12" fill="#FFFFFF" stroke="#000000" stroke-width="4"/>
</svg>
```

- [ ] **Step 3: Verify assets exist and commit**

```bash
git add assets/stickers/shield.svg assets/stickers/pin.svg
git commit -m "feat(assets): add shield and pin neubrutalist stickers"
```

---

### Task 2: Implement Redesigned Two-Tone Hero Panel with Marquee Ticker Tape

**Files:**
- Modify: `lib/auth/sign_in_screen.dart` (`_HeroPanel`)
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `UmColors`, `UmShadows`, `GoogleFonts.spaceGrotesk`, `GoogleFonts.outfit`, `assets/stickers/starburst.svg`.
- Produces: `_HeroPanel` with:
  1. Maroon header container with slanted `Ga` badge, `UM Marketplace` display title, tagline card, and `starburst.svg` sticker.
  2. Edge-to-edge Gold ticker tape bar (`3dp` ink border top/bottom) with:
     `⚡ @umindanao.edu.ph ONLY ⚡ 0% FEES ⚡ ON-CAMPUS MEETUPS ⚡`.
  3. Slanted `VERIFIED ONLY` badge overlapping the ticker line.

- [ ] **Step 1: Write widget test verifying Hero Panel elements**

In `test/widget_test.dart`, check that `'UM Marketplace'`, `'Ga'`, and `'@umindanao.edu.ph ONLY'` appear on screen.

- [ ] **Step 2: Implement `_HeroPanel` in `lib/auth/sign_in_screen.dart`**

```dart
class _HeroPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: UmColors.primary,
            border: Border(bottom: BorderSide(color: UmColors.ink, width: 3)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.rotate(
                      angle: -0.04,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: UmColors.gold,
                          border: Border.all(color: UmColors.ink, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: UmColors.ink,
                              offset: UmShadows.small,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          'Ga',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: UmColors.ink,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'UM Marketplace',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        height: 1.05,
                        letterSpacing: -0.5,
                        color: UmColors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: UmColors.surface,
                        border: Border.all(color: UmColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: UmColors.ink,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        'The campus marketplace for University of Mindanao students.',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          height: 1.35,
                          color: UmColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                top: 18,
                child: Transform.rotate(
                  angle: 0.08,
                  child: SvgPicture.asset(
                    'assets/stickers/starburst.svg',
                    width: 64,
                    height: 64,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Neubrutalist Gold Ticker Tape
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const BoxDecoration(
            color: UmColors.gold,
            border: Border(bottom: BorderSide(color: UmColors.ink, width: 3)),
            boxShadow: [
              BoxShadow(
                color: UmColors.ink,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '⚡ @umindanao.edu.ph ONLY ⚡ 0% FEES ⚡ ON-CAMPUS MEETUPS ⚡',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                    color: UmColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Run test**

```bash
flutter test test/widget_test.dart
```
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/auth/sign_in_screen.dart test/widget_test.dart
git commit -m "feat(auth): redesign hero panel with marquee ticker tape"
```

---

### Task 3: Enhance Sign-In Card with Institutional Domain Gate Callout

**Files:**
- Modify: `lib/auth/sign_in_screen.dart` (`_SignInCard`)

**Interfaces:**
- Consumes: `_busy`, `onSignIn`, `NbrButton`, `UmColors`, `assets/logos/google_g.svg`, `bag.svg`, `tag.svg`.
- Produces: `_SignInCard` featuring:
  - Header: `badgeCheck500` icon in gold box + `"Sign in to start trading"`.
  - Notice container in `goldSoft`:
    - Bold label: `"Institutional Account Required"`.
    - Subtext: `"Sign in with your @umindanao.edu.ph student Google account. Personal Gmail accounts are refused."`
  - `NbrButton` with Google logo.
  - Overlapping `bag.svg` top-right and `tag.svg` bottom-left stickers.

- [ ] **Step 1: Update `_SignInCard` implementation**

Add the styled notice container with 1.5dp ink border, 4dp rounded corners, and clear student domain guidance.

- [ ] **Step 2: Run tests**

```bash
flutter test test/widget_test.dart
```
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/auth/sign_in_screen.dart
git commit -m "feat(auth): add institutional domain callout to sign in card"
```

---

### Task 4: Implement "HOW WE TRADE" 3-Step Brutal Grid

**Files:**
- Modify: `lib/auth/sign_in_screen.dart` (`_HowItWorksSection` / replaces `_TrustStickers`)

**Interfaces:**
- Consumes: `LucideIcons.mailCheck500`, `LucideIcons.messageSquare500`, `LucideIcons.mapPin500`.
- Produces: `_HowItWorksSection` containing:
  - Pill label: `"HOW WE TRADE"`, Space Grotesk 800, gold fill, 2dp ink border.
  - 3 flex cards:
    - `01` `MailCheck`: `@umindanao` — `"Student email only"`
    - `02` `MessageSquare`: `Direct Deal` — `"₱0 fees • 1-on-1 chat"`
    - `03` `MapPin`: `On-Campus` — `"Matina & Bolton meetups"`
  - Each card: `goldSoft` background, `2dp` ink border, `3dp` offset hard shadow (`Offset(3, 3)`), `8dp` radius.

- [ ] **Step 1: Implement `_HowItWorksSection` widget**

```dart
class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        number: '01',
        icon: LucideIcons.mailCheck500,
        title: '@umindanao',
        caption: 'Student email only',
      ),
      (
        number: '02',
        icon: LucideIcons.messageSquare500,
        title: 'Direct Deal',
        caption: '₱0 fees • Chat 1-on-1',
      ),
      (
        number: '03',
        icon: LucideIcons.mapPin500,
        title: 'On-Campus',
        caption: 'Matina & Bolton hubs',
      ),
    ];

    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: UmColors.gold,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(color: UmColors.ink, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: Text(
              'HOW WE TRADE',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 0.8,
                color: UmColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final step in steps)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: UmColors.goldSoft,
                      border: Border.all(color: UmColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: UmColors.ink,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: UmColors.ink,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                step.number,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                  color: UmColors.gold,
                                ),
                              ),
                            ),
                            Icon(step.icon, size: 16, color: UmColors.primary),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: UmColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.caption,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                            fontSize: 9.5,
                            color: UmColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/widget_test.dart
```
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/auth/sign_in_screen.dart
git commit -m "feat(auth): add how we trade 3-step brutal grid"
```

---

### Task 5: Implement Campus Meetup & Safety Banner and Footer

**Files:**
- Modify: `lib/auth/sign_in_screen.dart` (`_CampusMeetupBanner`, `_LoginFooter`)

**Interfaces:**
- Consumes: `UmColors`, `LucideIcons.shieldCheck500`, `LucideIcons.mapPin500`, `GoogleFonts`.
- Produces: 
  - `_CampusMeetupBanner`:
    - Heading: `[MapPin] SAFE CAMPUS MEETUPS`.
    - Campus chips: `Matina`, `Bolton`, `Tagum`, `Peñaplata`.
    - Guidance note: *"Always meet in high-traffic campus zones (Cafeteria, Library, Gym Quad). Inspect gear before cash or GCash handoff."*
  - `_LoginFooter`:
    - Peer-to-peer tagline + student pride caption.

- [ ] **Step 1: Implement `_CampusMeetupBanner` and `_LoginFooter`**

```dart
class _CampusMeetupBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const campuses = ['Matina', 'Bolton', 'Tagum', 'Peñaplata'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: UmColors.ink,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: UmColors.gold,
                  border: Border.all(color: UmColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(LucideIcons.mapPin500, size: 16, color: UmColors.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SAFE CAMPUS MEETUPS',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    letterSpacing: 0.4,
                    color: UmColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final campus in campuses)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: UmColors.goldSoft,
                    border: Border.all(color: UmColors.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    campus,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: UmColors.ink,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.shieldCheck500, size: 14, color: UmColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Meet in open areas: Cafeteria, Library Lobby, or Gym. Inspect items thoroughly before cash or GCash handoff.',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500,
                    fontSize: 10.5,
                    height: 1.35,
                    color: UmColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/widget_test.dart
```
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/auth/sign_in_screen.dart
git commit -m "feat(auth): add campus meetup safety banner and footer"
```

---

### Task 6: Final Verification & Analysis

**Files:**
- `lib/auth/sign_in_screen.dart`
- `test/widget_test.dart`

- [ ] **Step 1: Run flutter analyze**

```bash
flutter analyze
```
Expected: 0 issues

- [ ] **Step 2: Run the full test suite**

```bash
flutter test
```
Expected: All 103+ tests pass

- [ ] **Step 3: Push changes to `origin/qa/bypass`**

```bash
git push origin qa/bypass
```
Expected: Successfully pushed
