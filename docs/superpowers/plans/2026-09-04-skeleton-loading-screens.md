# Skeleton Loading Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a unified, neo-brutalist shimmer engine (`BrutalShimmer`) and high-fidelity skeleton loading screens across all 8 primary application screens (Home, Browse, Product Detail, Chats, Chat Thread, Profile, Notifications, and Moderation).

**Architecture:** A zero-dependency Flutter shimmer engine in `lib/widgets/brutal_shimmer.dart` provides an animated gradient sweep across neo-brutalist container blocks (`BrutalSkeletonBox`). Specialized high-fidelity skeleton widgets (`ProductCardSkeleton`, `ChatRowSkeleton`, `ChatThreadSkeleton`, `_MyListingsSkeleton`, `_NotificationsSkeleton`, `_ReportsSkeleton`, `ListingDetailSkeleton`) match the exact dimensions, borders, and shadows of real screen content, replacing flat grey boxes and empty spaces during Firestore stream loading.

**Tech Stack:** Flutter, Dart, Google Fonts, Lucide Icons, flutter_test.

## Global Constraints

- Neo-brutalist styling: 2dp solid ink borders (`UmColors.ink`), 0-blur hard shadows (`Offset(4, 4)` for cards, `Offset(3, 3)` for rows/chips).
- Colors: `UmColors.muted` (`#E2E8F0`) base tone, `#F8FAFC` highlight sheen, `UmColors.surface` card shells, and soft green/gold tint accents.
- Animation: 1500ms repeating diagonal shimmer sweep; zero external package dependencies (`shimmer` or `skeletonizer` not allowed).
- Analyzer cleanliness: zero warnings from `flutter analyze` (`flutter_lints ^6.0.0`).
- Test suite: all existing tests must pass along with new widget tests (`flutter test`).

---

### Task 1: Core Brutal Shimmer Engine & Primitive Skeleton Box

**Files:**
- Create: `lib/widgets/brutal_shimmer.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces:
  - `class BrutalShimmer extends StatefulWidget`: controls a repeating 1500ms `AnimationController` and applies a sliding `ShaderMask` / `LinearGradient`.
  - `class BrutalSkeletonBox extends StatelessWidget`: customizable block (`width`, `height`, `borderRadius`, `border`, `color`, `child`).

- [ ] **Step 1: Write test for BrutalShimmer and BrutalSkeletonBox in widget_test.dart**

Add the following test in `test/widget_test.dart`:

```dart
group('BrutalShimmer and BrutalSkeletonBox', () {
  testWidgets('renders BrutalSkeletonBox with border and dimensions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrutalShimmer(
            child: BrutalSkeletonBox(
              width: 120,
              height: 40,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BrutalShimmer), findsOneWidget);
    expect(find.byType(BrutalSkeletonBox), findsOneWidget);
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(BrutalSkeletonBox),
        matching: find.byType(Container),
      ),
    );
    expect((box.decoration as BoxDecoration).color, UmColors.muted);
  });

  testWidgets('BrutalShimmer advances animation without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrutalShimmer(
            child: BrutalSkeletonBox(width: 100, height: 20),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BrutalShimmer), findsOneWidget);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "renders BrutalSkeletonBox with border and dimensions"`
Expected: Compilation failure or missing `BrutalShimmer` class.

- [ ] **Step 3: Implement BrutalShimmer and BrutalSkeletonBox in lib/widgets/brutal_shimmer.dart**

Create `lib/widgets/brutal_shimmer.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Sweeps a diagonal highlight gradient over skeleton child widgets.
class BrutalShimmer extends StatefulWidget {
  const BrutalShimmer({
    super.key,
    required this.child,
    this.baseColor = UmColors.muted,
    this.highlightColor = const Color(0xFFF8FAFC),
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  @override
  State<BrutalShimmer> createState() => _BrutalShimmerState();
}

class _BrutalShimmerState extends State<BrutalShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final progress = _controller.value;
            // Slide from -1.0 to 2.0 to ensure a full diagonal traversal across the layout
            final slide = -1.0 + (progress * 3.0);
            return LinearGradient(
              begin: Alignment(slide - 1.0, -1.0),
              end: Alignment(slide + 1.0, 1.0),
              colors: [
                widget.baseColor,
                widget.highlightColor.withValues(alpha: 0.75),
                widget.baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Primitive neo-brutal skeleton block with solid ink border and muted fill.
class BrutalSkeletonBox extends StatelessWidget {
  const BrutalSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.hasBorder = false,
    this.borderColor = UmColors.ink,
    this.borderWidth = 2.0,
    this.color = UmColors.muted,
    this.child,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final bool hasBorder;
  final Color borderColor;
  final double borderWidth;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: hasBorder
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "renders BrutalSkeletonBox with border and dimensions"`
Expected: PASS

- [ ] **Step 5: Commit Task 1**

```bash
git add lib/widgets/brutal_shimmer.dart test/widget_test.dart
git commit -m "feat(widgets): add BrutalShimmer and BrutalSkeletonBox primitives"
```

---

### Task 2: Product Card Skeleton & Feed Integration (Home & Browse)

**Files:**
- Create: `lib/widgets/product_card_skeleton.dart`
- Modify: `lib/home/home_screen.dart`
- Modify: `lib/home/browse_screen.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces:
  - `class ProductCardSkeleton extends StatelessWidget`: high-fidelity placeholder matching `ListingCard` (white card, 2dp ink border, 4dp hard shadow, 4:3 photo top, title line, condition pill, green price chip).
- Consumes:
  - `BrutalShimmer`, `BrutalSkeletonBox` from `lib/widgets/brutal_shimmer.dart`.

- [ ] **Step 1: Write test for ProductCardSkeleton and feed loading states**

Add tests in `test/widget_test.dart`:

```dart
group('ProductCardSkeleton and Feed Skeletons', () {
  testWidgets('ProductCardSkeleton renders card structure with photo, title, and price placeholders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductCardSkeleton(),
        ),
      ),
    );

    expect(find.byType(ProductCardSkeleton), findsOneWidget);
    expect(find.byType(BrutalShimmer), findsOneWidget);
  });

  testWidgets('HomeScreen renders ProductCardSkeleton grid when listings stream is loading', (tester) async {
    final fakeMember = FakeMemberStore();
    final fakeListings = FakeListingsStore();
    // Do not emit listings yet — stream is pending (data is null)

    await tester.pumpWidget(_app(members: fakeMember, listings: fakeListings));
    await tester.pump();

    expect(find.byType(ProductCardSkeleton), findsWidgets);
    expect(find.text('Recent listings'), findsOneWidget);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "ProductCardSkeleton renders card structure with photo, title, and price placeholders"`
Expected: Compilation failure or missing `ProductCardSkeleton`.

- [ ] **Step 3: Implement ProductCardSkeleton in lib/widgets/product_card_skeleton.dart**

Create `lib/widgets/product_card_skeleton.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brutal_shimmer.dart';

/// High-fidelity skeleton card matching the exact physical layout of [ListingCard].
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: UmColors.ink,
            offset: UmShadows.card,
            blurRadius: 0,
          ),
        ],
      ),
      child: BrutalShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 4:3 Aspect ratio cover image placeholder
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: UmColors.muted,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                  border: Border(bottom: BorderSide(color: UmColors.ink, width: 2)),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title placeholder line
                    const BrutalSkeletonBox(
                      height: 14,
                      width: double.infinity,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 6),
                    // Condition / category pill placeholder
                    Row(
                      children: const [
                        BrutalSkeletonBox(
                          height: 14,
                          width: 52,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        SizedBox(width: 6),
                        BrutalSkeletonBox(
                          height: 14,
                          width: 44,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Price placeholder (tinted soft green)
                    BrutalSkeletonBox(
                      height: 18,
                      width: 68,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      color: UmColors.success.withValues(alpha: 0.25),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update home_screen.dart and browse_screen.dart to use ProductCardSkeleton**

In `lib/home/home_screen.dart`:
Replace `_FeedSkeleton` with:

```dart
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => const ProductCardSkeleton(),
    );
  }
}
```

In `lib/home/browse_screen.dart`:
Replace `_BrowseSkeleton` with:

```dart
class _BrowseSkeleton extends StatelessWidget {
  const _BrowseSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => const ProductCardSkeleton(),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/widget_test.dart --plain-name "HomeScreen renders ProductCardSkeleton grid when listings stream is loading"`
Expected: PASS

- [ ] **Step 6: Commit Task 2**

```bash
git add lib/widgets/product_card_skeleton.dart lib/home/home_screen.dart lib/home/browse_screen.dart test/widget_test.dart
git commit -m "feat(home): integrate high-fidelity ProductCardSkeleton in Home and Browse feeds"
```

---

### Task 3: Product Detail Screen Skeleton

**Files:**
- Create: `lib/widgets/listing_detail_skeleton.dart`
- Modify: `lib/home/listing_detail_screen.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces:
  - `class ListingDetailSkeleton extends StatelessWidget`: skeleton with 4:3 hero swiper frame, price bar, badges, seller strip, and action bar placeholders.
- Consumes:
  - `BrutalShimmer`, `BrutalSkeletonBox` from `lib/widgets/brutal_shimmer.dart`.

- [ ] **Step 1: Write test for ListingDetailSkeleton**

Add test in `test/widget_test.dart`:

```dart
testWidgets('ListingDetailSkeleton renders hero frame, price, and seller strip placeholders', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: ListingDetailSkeleton(),
      ),
    ),
  );

  expect(find.byType(ListingDetailSkeleton), findsOneWidget);
  expect(find.byType(BrutalShimmer), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "ListingDetailSkeleton renders hero frame, price, and seller strip placeholders"`
Expected: Compilation error for missing `ListingDetailSkeleton`.

- [ ] **Step 3: Implement ListingDetailSkeleton in lib/widgets/listing_detail_skeleton.dart**

Create `lib/widgets/listing_detail_skeleton.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brutal_app_bar.dart';
import 'brutal_shimmer.dart';

/// Full-page skeleton for the product detail view.
class ListingDetailSkeleton extends StatelessWidget {
  const ListingDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrutalAppBar(title: 'LISTING'),
            Expanded(
              child: BrutalShimmer(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 4:3 Hero photo frame
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: UmColors.muted,
                          border: Border.all(color: UmColors.ink, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: UmColors.ink,
                              offset: UmShadows.card,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Price & condition block
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        BrutalSkeletonBox(
                          height: 32,
                          width: 140,
                          color: Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        BrutalSkeletonBox(
                          height: 20,
                          width: 64,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Title placeholder (2 lines)
                    const BrutalSkeletonBox(
                      height: 20,
                      width: double.infinity,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 6),
                    const BrutalSkeletonBox(
                      height: 16,
                      width: 200,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 16),
                    // Category & location chips
                    Row(
                      children: const [
                        BrutalSkeletonBox(
                          height: 24,
                          width: 80,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        SizedBox(width: 8),
                        BrutalSkeletonBox(
                          height: 24,
                          width: 100,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Seller strip placeholder card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: UmColors.surface,
                        border: Border.all(color: UmColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: UmColors.ink,
                            offset: UmShadows.card,
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const BrutalSkeletonBox(
                            width: 44,
                            height: 44,
                            borderRadius: BorderRadius.all(Radius.circular(999)),
                            hasBorder: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                BrutalSkeletonBox(
                                  height: 14,
                                  width: 120,
                                  borderRadius: BorderRadius.all(Radius.circular(4)),
                                ),
                                SizedBox(height: 6),
                                BrutalSkeletonBox(
                                  height: 12,
                                  width: 80,
                                  borderRadius: BorderRadius.all(Radius.circular(999)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description paragraph placeholders
                    const BrutalSkeletonBox(
                      height: 14,
                      width: double.infinity,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 6),
                    const BrutalSkeletonBox(
                      height: 14,
                      width: 240,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "ListingDetailSkeleton renders hero frame, price, and seller strip placeholders"`
Expected: PASS

- [ ] **Step 5: Commit Task 3**

```bash
git add lib/widgets/listing_detail_skeleton.dart test/widget_test.dart
git commit -m "feat(detail): add high-fidelity ListingDetailSkeleton"
```

---

### Task 4: Chats List & Chat Thread Skeletons

**Files:**
- Modify: `lib/chats/chats_screen.dart`
- Modify: `lib/chats/chat_thread_screen.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces:
  - Updated `_ChatsSkeleton` in `chats_screen.dart` using `BrutalShimmer` with 4 `_ChatRowSkeleton`s (avatar, title, preview line, timestamp pill).
  - Updated `_ThreadSkeleton` in `chat_thread_screen.dart` with pinned product card placeholder and alternating incoming/outgoing message bubbles.

- [ ] **Step 1: Write test for Chats and ChatThread skeletons**

Add tests in `test/widget_test.dart`:

```dart
group('Chats and ChatThread Skeletons', () {
  testWidgets('ChatsScreen renders high-fidelity chat row skeletons when stream is loading', (tester) async {
    final fakeChat = FakeChatStore();
    // Leave stream pending (do not emitList)

    await tester.pumpWidget(
      MaterialApp(
        theme: buildUmTheme(),
        home: ChatsScreen(
          viewerUid: 'test-user',
          chatStore: fakeChat,
          memberStore: FakeMemberStore(),
          listingsStore: FakeListingsStore(),
          ratingStore: FakeRatingStore(),
          reportStore: FakeReportStore(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Conversations'), findsOneWidget);
    expect(find.byType(BrutalShimmer), findsWidgets);
  });

  testWidgets('ChatThreadScreen renders thread skeleton when listing is loading', (tester) async {
    final fakeListings = FakeListingsStore();
    final testChat = Chat(
      id: 'test_chat',
      listingId: 'loading_listing',
      sellerId: 'seller',
      buyerId: 'test-user',
      participants: {'seller', 'test-user'},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildUmTheme(),
        home: ChatThreadScreen(
          chat: testChat,
          viewerUid: 'test-user',
          chatStore: FakeChatStore(),
          memberStore: FakeMemberStore(),
          listingsStore: fakeListings,
          ratingStore: FakeRatingStore(),
          reportStore: FakeReportStore(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BrutalShimmer), findsWidgets);
  });
});
```

- [ ] **Step 2: Run tests to verify initial state**

Run: `flutter test test/widget_test.dart --plain-name "ChatsScreen renders high-fidelity chat row skeletons when stream is loading"`

- [ ] **Step 3: Update lib/chats/chats_screen.dart with high-fidelity _ChatsSkeleton**

In `lib/chats/chats_screen.dart`:
Import `../widgets/brutal_shimmer.dart`.
Update `_ChatsSkeleton`:

```dart
class _ChatsSkeleton extends StatelessWidget {
  const _ChatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return BrutalShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Conversations',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UmColors.surface,
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
                child: Row(
                  children: [
                    const BrutalSkeletonBox(
                      width: 44,
                      height: 44,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      hasBorder: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          BrutalSkeletonBox(
                            height: 14,
                            width: 110,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          SizedBox(height: 6),
                          BrutalSkeletonBox(
                            height: 11,
                            width: 180,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const BrutalSkeletonBox(
                      height: 12,
                      width: 36,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Update lib/chats/chat_thread_screen.dart with high-fidelity _ThreadSkeleton and message list loading state**

In `lib/chats/chat_thread_screen.dart`:
Import `../widgets/brutal_shimmer.dart`.
Update `_ThreadSkeleton`:

```dart
class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    return BrutalShimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Pinned listing placeholder
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UmColors.surface,
                border: Border.all(color: UmColors.ink, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: UmColors.ink, offset: Offset(4, 4), blurRadius: 0),
                ],
              ),
              child: Row(
                children: [
                  const BrutalSkeletonBox(
                    width: 56,
                    height: 56,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        BrutalSkeletonBox(
                          height: 14,
                          width: 140,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        SizedBox(height: 6),
                        BrutalSkeletonBox(
                          height: 12,
                          width: 70,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Message bubble placeholders (alternating incoming & outgoing)
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 180,
                      height: 48,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: UmColors.surface,
                        border: Border.all(color: UmColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 150,
                      height: 48,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: UmColors.primary.withValues(alpha: 0.3),
                        border: Border.all(color: UmColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 220,
                      height: 56,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: UmColors.gold.withValues(alpha: 0.35),
                        border: Border.all(color: UmColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

In `_MessageList`'s `builder` in `chat_thread_screen.dart`:
Replace `if (messages == null) return const SizedBox.shrink();` with:

```dart
        if (messages == null) {
          return const _ThreadSkeleton();
        }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/widget_test.dart --plain-name "ChatsScreen renders high-fidelity chat row skeletons when stream is loading"`
Expected: PASS

- [ ] **Step 6: Commit Task 4**

```bash
git add lib/chats/chats_screen.dart lib/chats/chat_thread_screen.dart test/widget_test.dart
git commit -m "feat(chats): implement high-fidelity skeleton loading for conversations and chat thread"
```

---

### Task 5: Profile, Notifications & Moderation Skeletons

**Files:**
- Modify: `lib/profile/profile_screen.dart`
- Modify: `lib/notifications/notification_center_screen.dart`
- Modify: `lib/moderation/moderation_screen.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces:
  - High-fidelity `_MyListingsSkeleton` and `_RatingSkeleton` in `profile_screen.dart`.
  - High-fidelity `_NotificationsSkeleton` in `notification_center_screen.dart`.
  - High-fidelity `_ReportsSkeleton` in `moderation_screen.dart`.

- [ ] **Step 1: Write tests for Profile, Notifications, and Moderation skeletons**

Add tests in `test/widget_test.dart`:

```dart
group('Profile, Notifications, and Moderation Skeletons', () {
  testWidgets('NotificationCenterScreen renders notification row skeletons when stream is loading', (tester) async {
    final fakeNotifs = FakeNotificationStore();
    // Stream pending

    await tester.pumpWidget(
      MaterialApp(
        theme: buildUmTheme(),
        home: NotificationCenterScreen(
          ownerId: 'test-owner',
          notificationStore: fakeNotifs,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BrutalShimmer), findsWidgets);
    expect(find.text('NOTIFICATIONS'), findsOneWidget);
  });

  testWidgets('ModerationScreen renders report card skeletons when reports stream is loading', (tester) async {
    final fakeReports = FakeReportStore();
    // Stream pending

    await tester.pumpWidget(
      MaterialApp(
        theme: buildUmTheme(),
        home: ModerationScreen(
          memberStore: FakeMemberStore(),
          listingsStore: FakeListingsStore(),
          reportStore: fakeReports,
          chatStore: FakeChatStore(),
          ratingStore: FakeRatingStore(),
          viewerId: 'admin-id',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BrutalShimmer), findsWidgets);
    expect(find.text('Open reports'), findsOneWidget);
  });
});
```

- [ ] **Step 2: Update lib/profile/profile_screen.dart**

Import `../widgets/brutal_shimmer.dart`.
Update `_MyListingsSkeleton`:

```dart
class _MyListingsSkeleton extends StatelessWidget {
  const _MyListingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return BrutalShimmer(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UmColors.surface,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: UmColors.ink,
                      offset: UmShadows.card,
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const BrutalSkeletonBox(
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          BrutalSkeletonBox(
                            height: 14,
                            width: 130,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          SizedBox(height: 6),
                          BrutalSkeletonBox(
                            height: 11,
                            width: 64,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          SizedBox(height: 6),
                          BrutalSkeletonBox(
                            height: 14,
                            width: 80,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                            color: Color(0xFFDCFCE7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const BrutalSkeletonBox(
                      height: 28,
                      width: 80,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      hasBorder: true,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Update lib/notifications/notification_center_screen.dart**

Import `../widgets/brutal_shimmer.dart`.
Update `_NotificationsSkeleton`:

```dart
class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return BrutalShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UmColors.surface,
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
                child: Row(
                  children: [
                    const BrutalSkeletonBox(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      hasBorder: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          BrutalSkeletonBox(
                            height: 13,
                            width: 120,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          SizedBox(height: 6),
                          BrutalSkeletonBox(
                            height: 11,
                            width: 200,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Update lib/moderation/moderation_screen.dart**

Import `../widgets/brutal_shimmer.dart`.
Update `_ReportsSkeleton`:

```dart
class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return BrutalShimmer(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: UmColors.surface,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        BrutalSkeletonBox(
                          height: 18,
                          width: 80,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        BrutalSkeletonBox(
                          height: 12,
                          width: 40,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const BrutalSkeletonBox(
                      height: 14,
                      width: 160,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        BrutalSkeletonBox(
                          height: 28,
                          width: 90,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                          hasBorder: true,
                        ),
                        SizedBox(width: 8),
                        BrutalSkeletonBox(
                          height: 28,
                          width: 80,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                          hasBorder: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/widget_test.dart --plain-name "NotificationCenterScreen renders notification row skeletons when stream is loading"`
Expected: PASS

- [ ] **Step 6: Commit Task 5**

```bash
git add lib/profile/profile_screen.dart lib/notifications/notification_center_screen.dart lib/moderation/moderation_screen.dart test/widget_test.dart
git commit -m "feat(skeletons): implement high-fidelity skeletons for Profile, Notifications, and Moderation"
```

---

### Task 6: Full Verification, Static Analysis & Git Push

- [ ] **Step 1: Run flutter analyze**

Run: `flutter analyze`
Expected: 0 issues found.

- [ ] **Step 2: Run complete test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 3: Push to origin main**

Run: `git push origin main`
Expected: Branch up to date on origin/main.
