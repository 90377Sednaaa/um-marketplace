# Design Specification: High-Fidelity Skeleton Loading Screens

**Date:** 2026-09-04  
**Status:** Approved  
**Author:** Antigravity  

## 1. Overview

Currently, several screens in `um-marketplace` render static, plain grey rectangular boxes (`UmColors.muted` with 2dp ink borders) or empty space (`SizedBox.shrink()`) while Firestore data streams are loading. This produces a flat, lifeless experience before content arrives.

This specification details a comprehensive, neo-brutalist **High-Fidelity Skeleton Loading System** powered by a zero-dependency `BrutalShimmer` engine. Across all 8 primary application screens, skeletons mirror the exact structural anatomy of real components (image aspect ratios, typography heights, status badges, price chips, and hard shadows) while animating with a subtle diagonal light sweep.

---

## 2. Core Shimmer Engine (`lib/widgets/brutal_shimmer.dart`)

### 2.1 Architecture
Rather than importing external packages that conflict with neo-brutalist box shadows and borders, we build a native Flutter shimmer engine:
- **`BrutalShimmer`**: A stateful widget controlling a repeating `AnimationController` with a 1500ms duration.
- **`ShaderMask` / Sliding LinearGradient**: Sweeps a gradient across its children:
  - Base tone: `UmColors.muted` (`#E2E8F0`).
  - Highlight tone: `#F8FAFC` (subtle white-blue sheen at 60% opacity).
  - Stops: `[0.0, 0.5, 1.0]`.
  - Transform: Diagonal slide from `Alignment(-1.5, -0.5)` to `Alignment(2.0, 1.5)`.
- **`BrutalShimmerScope`**: Inherited widget allowing multiple sibling skeleton elements to share the single animation ticker so all placeholders on a screen shimmer in unison.

### 2.2 Skeleton Primitives
- **`BrutalSkeletonBox`**:
  - Properties: `double? width`, `double? height`, `BorderRadius borderRadius`, `bool hasBorder`, `BoxBorder? border`, `Color? color`.
  - Default corner radius: `8dp` (matching cards) or `999dp` (for pills and badges).
  - Default border: `Border.all(color: UmColors.ink, width: 2)` for bordered cards, or borderless for internal text/image placeholder bars.

---

## 3. Screen Specifications

### 3.1 Product Card & Feed Skeletons (`ProductCardSkeleton`, `home_screen.dart`, `browse_screen.dart`)
- **Card Container**:
  - Surface: `UmColors.surface` with 2dp ink border (`UmColors.ink`), 8dp radius, and 4dp solid ink shadow (`BoxShadow(color: UmColors.ink, offset: Offset(4, 4), blurRadius: 0)`).
  - Aspect ratio: matches `ListingCard` (0.70 child aspect ratio in 2-column grid).
- **Internal Layout**:
  - **Image Box**: Top 4:3 cover placeholder with `UmColors.muted` fill and 2dp bottom ink divider.
  - **Title Line**: Height 14dp, 75% width, 4dp radius.
  - **Meta Line**: Height 12dp, 45% width (representing condition/location).
  - **Price Pill**: Height 20dp, width 70dp, 999 pill radius, tinted in soft success green (`UmColors.success.withValues(alpha: 0.15)`).
- **Home Feed**: Displays the persistent search bar, horizontal category capsules, and a 4-item (2x2) grid of `ProductCardSkeleton`s.
- **Browse Screen**: Displays the app bar, search input, filter chips row, and a 4-item (2x2) grid of `ProductCardSkeleton`s.

### 3.2 Product Detail Skeleton (`ListingDetailSkeleton`, `listing_detail_screen.dart`)
- **Hero Image Frame**: 4:3 aspect ratio framed box with 2dp ink border and 4dp hard shadow.
- **Price Block**: 32dp tall price placeholder bar with condition pill placeholder badge.
- **Title Block**: 2 lines of text placeholders (height 20dp and 16dp).
- **Category & Location Chips**: 2 pill-shaped placeholders with 999 radius.
- **Seller Strip**: Mimics `_SellerStrip` with a 40x40 circular avatar, seller display name bar, verified-student badge pill, and star rating line.
- **Sticky Bottom Action Bar**: Outlined dual button placeholders for "Chat" and "Make an offer".

### 3.3 Conversations List Skeleton (`ChatsSkeleton`, `chats_screen.dart`)
- **Container**: ListView with 4 `ChatRowSkeleton` items.
- **Row Anatomy**:
  - Container: White surface with 2dp ink border, 3dp hard shadow (`Offset(3, 3)`), 8dp radius.
  - Left: 44x44 circular avatar placeholder with 2dp ink border.
  - Middle: Column with a 14dp student name bar and an 11dp message preview bar (60% width).
  - Right: 14dp x 36dp timestamp pill placeholder.

### 3.4 Chat Thread Skeleton (`ChatThreadSkeleton`, `chat_thread_screen.dart`)
- **Pinned Product Snippet**:
  - Container: Height 72dp with 2dp ink border and 4dp hard shadow.
  - Left: 56x56 square thumbnail placeholder with 6dp radius.
  - Middle: Title placeholder line and price placeholder pill.
- **Message List**:
  - 4 alternating skeleton message bubbles with 2dp ink border and 3dp hard shadow:
    - 2 incoming message bubbles (aligned left, white surface, width 180dp and 120dp).
    - 2 outgoing message bubbles (aligned right, maroon tint, width 160dp and 200dp).
    - 1 offer message placeholder (gold tinted container with pill badge).
- **Composer Bar**: Fixed bottom bar with text field placeholder and disabled send button.

### 3.5 Profile Screen Skeletons (`profile_screen.dart`)
- **Rating Card Skeleton**: Replaces the static `'★ — · no trades yet'` while ratings stream loads with a star icon placeholder, score pill, and trade count line.
- **My Listings Skeleton (`_MyListingsSkeleton`)**:
  - 3 high-fidelity listing rows:
  - 56x56 square image thumbnail with 6dp radius.
  - Column with title line (14dp), condition text (11dp), and price line (14dp).
  - Right: Pill-shaped "Mark as sold" button outline placeholder (width 80dp, height 28dp, 999 radius).

### 3.6 Notification Center Skeleton (`_NotificationsSkeleton`, `notification_center_screen.dart`)
- **4 Notification Rows**:
  - White surface with 2dp ink border and 3dp hard shadow.
  - Left: 40x40 square type icon placeholder with 2dp ink border.
  - Middle: Column with 13dp title line, 11dp body description line, and timestamp pill.
  - Right: Gold "NEW" indicator pill placeholder for unread state.

### 3.7 Admin Moderation Skeleton (`_ReportsSkeleton`, `moderation_screen.dart`)
- **3 Report Cards**:
  - White surface with 2dp ink border and 3dp hard shadow.
  - Header: Reason pill tag placeholder and relative timestamp pill.
  - Body: Reporter and reported member tags with shield icon placeholder.
  - Bottom row: Dual action pill button placeholders ("Hide listing" and "Dismiss").

---

## 4. Neo-Brutalist Design Tokens & Consistency

All skeleton components follow `DESIGN.md`:
- **Borders:** 2dp solid ink borders (`UmColors.ink`).
- **Corner Radii:** 8dp for cards/containers; 999 for pills, badges, and chips.
- **Shadows:** Hard solid offsets (`UmShadows.card` `Offset(4, 4)` or `UmShadows.small` `Offset(3, 3)`) with 0 blur.
- **Colors:**
  - Base placeholder: `UmColors.muted` (`#E2E8F0`).
  - Shimmer highlight: `#F8FAFC`.
  - Surface: `UmColors.surface` (`#FFFFFF`).
  - Tint highlights: soft green for prices, soft gold for badges.

---

## 5. Testing & Verification

1. **Unit & Widget Tests (`test/widget_test.dart`)**:
   - Verify `BrutalShimmer` initializes animation controller and drives gradient transition cleanly.
   - Verify `HomeScreen` renders `ProductCardSkeleton`s when listings stream emits `null`.
   - Verify `BrowseScreen` renders `ProductCardSkeleton`s when listings stream emits `null`.
   - Verify `ChatsScreen` renders `ChatRowSkeleton`s when chats stream emits `null`.
   - Verify `ChatThreadScreen` renders `ChatThreadSkeleton` when listing/messages stream emits `null`.
   - Verify `ProfileScreen` renders `_MyListingsSkeleton` with thumbnail, text, and button placeholders.
   - Verify `NotificationCenterScreen` renders `_NotificationsSkeleton` with icon and text placeholders.
   - Verify `ModerationScreen` renders `_ReportsSkeleton` with report card placeholders.
2. **Quality Gates**:
   - `flutter analyze` with 0 issues.
   - All tests in `flutter test` passing (129+ tests).
