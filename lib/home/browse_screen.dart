import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_app_bar.dart';
import '../widgets/nbr_button.dart';
import 'listing_card.dart';
import 'listing_detail_screen.dart';

/// Browse / search results (DESIGN.md screen 2): a live text query,
/// category chips, and a filters sheet (condition + price range) over the
/// recent active listings, filtered client-side (Firestore cannot
/// substring-search). Reached from the Home hero search — never a tab
/// (DESIGN.md §5).
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({
    super.key,
    required this.viewerUid,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    this.initialQuery = '',
    this.initialCategory,
  });

  final String viewerUid;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;
  final String initialQuery;
  final String? initialCategory;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _search = TextEditingController();
  late String _query = widget.initialQuery;
  late BrowseFilters _filters =
      BrowseFilters(category: widget.initialCategory);

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openDetail(Listing listing) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingDetailScreen(
          listing: listing,
          memberStore: widget.memberStore,
          listingsStore: widget.listingsStore,
          chatStore: widget.chatStore,
          ratingStore: widget.ratingStore,
          reportStore: widget.reportStore,
          viewerId: widget.viewerUid,
        ),
      ),
    );
  }

  void _setCategory(String? category) {
    setState(() {
      _filters = BrowseFilters(
        category: category,
        condition: _filters.condition,
        minPrice: _filters.minPrice,
        maxPrice: _filters.maxPrice,
      );
    });
  }

  Future<void> _openFilters() async {
    final applied = await showModalBottomSheet<BrowseFilters>(
      context: context,
      backgroundColor: UmColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _FiltersSheet(initial: _filters),
    );
    if (applied != null && mounted) {
      setState(() => _filters = applied);
    }
  }

  void _clearAll() {
    _search.clear();
    setState(() {
      _query = '';
      _filters = const BrowseFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter =
        _query.trim().isNotEmpty || _filters.isActive;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrutalAppBar(
              title: 'BROWSE',
              leadingIcon: LucideIcons.search500,
            ),
            Expanded(
              child: StreamBuilder<List<Listing>>(
                stream: widget.listingsStore
                    .activeListingsStream(limit: kBrowseFetchLimit),
                builder: (context, snapshot) {
                  final all = snapshot.data;
                  if (all == null) return const _BrowseSkeleton();
                  final results = filterListings(all, query: _query, filters: _filters);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: UmColors.surface,
                          border:
                              Border.all(color: UmColors.ink, width: 3),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: UmColors.ink,
                              offset: Offset(4, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _search,
                          autofocus: true,
                          onChanged: (value) =>
                              setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: 'Search textbooks, gadgets…',
                            prefixIcon: const Icon(LucideIcons.search500,
                                color: UmColors.ink),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        key: const Key('browse-category-chips'),
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChipLabel(
                            label: 'All',
                            selected: _filters.category == null,
                            onTap: () => _setCategory(null),
                          ),
                          for (final category in kListingCategories)
                            _FilterChipLabel(
                              label: category,
                              selected: _filters.category == category,
                              onTap: () => _setCategory(category),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          NbrButton(
                            label: 'Filters',
                            icon: const Icon(LucideIcons.slidersHorizontal500,
                                size: 20, color: UmColors.ink),
                            fill: UmColors.surface,
                            labelColor: UmColors.ink,
                            onPressed: _openFilters,
                          ),
                          const Spacer(),
                          Text(
                            '${results.length} '
                            '${results.length == 1 ? 'result' : 'results'}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    color: UmColors.mutedForeground),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (results.isEmpty)
                        _BrowseEmpty(
                          hasActiveFilter: hasActiveFilter,
                          onClear: _clearAll,
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.70,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final listing = results[index];
                            return ListingCard(
                              listing: listing,
                              onTap: () => _openDetail(listing),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipLabel extends StatelessWidget {
  const _FilterChipLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? UmColors.goldSoft : UmColors.surface,
          border: Border.all(
            color: selected ? UmColors.ink : UmColors.mutedForeground,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: selected ? UmColors.ink : UmColors.onSurface,
          ),
        ),
      ),
    );
  }
}

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
        childAspectRatio: 0.68,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: UmColors.muted,
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _BrowseEmpty extends StatelessWidget {
  const _BrowseEmpty({
    required this.hasActiveFilter,
    required this.onClear,
  });

  final bool hasActiveFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(
            LucideIcons.searchX500,
            size: 48,
            color: UmColors.mutedForeground,
          ),
          const SizedBox(height: 12),
          Text(
            hasActiveFilter
                ? 'No listings match your search.'
                : 'No listings yet — be the first to post one!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (hasActiveFilter) ...[
            const SizedBox(height: 16),
            NbrButton(
              label: 'Clear filters',
              fill: UmColors.surface,
              labelColor: UmColors.ink,
              onPressed: onClear,
            ),
          ],
        ],
      ),
    );
  }
}

/// The filters sheet (DESIGN.md screen 2 extension): condition pills and
/// a whole-peso price range, applied client-side. Pops with the chosen
/// [BrowseFilters] (or null on dismiss).
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial});

  final BrowseFilters initial;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String? _condition = widget.initial.condition;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initial.minPrice != null) {
      _minController.text = widget.initial.minPrice!.round().toString();
    }
    if (widget.initial.maxPrice != null) {
      _maxController.text = widget.initial.maxPrice!.round().toString();
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.of(context).pop(BrowseFilters(
      condition: _condition,
      minPrice: double.tryParse(_minController.text.trim()),
      maxPrice: double.tryParse(_maxController.text.trim()),
    ));
  }

  void _clear() {
    setState(() {
      _condition = null;
      _minController.clear();
      _maxController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Condition',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              key: const Key('browse-condition-pills'),
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChipLabel(
                  label: 'All',
                  selected: _condition == null,
                  onTap: () => setState(() => _condition = null),
                ),
                for (final condition in kListingConditions)
                  _FilterChipLabel(
                    label: condition,
                    selected: _condition == condition,
                    onTap: () => setState(() => _condition = condition),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Price range (whole pesos)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PriceField(
                    controller: _minController,
                    hint: 'Min',
                    prefix: '₱',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PriceField(
                    controller: _maxController,
                    hint: 'Max',
                    prefix: '₱',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: NbrButton(
                    label: 'Clear',
                    fill: UmColors.surface,
                    labelColor: UmColors.ink,
                    stretch: true,
                    onPressed: _clear,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NbrButton(
                    label: 'Apply',
                    fill: UmColors.gold,
                    labelColor: UmColors.ink,
                    stretch: true,
                    onPressed: _apply,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.hint,
    required this.prefix,
  });

  final TextEditingController controller;
  final String hint;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        filled: true,
        fillColor: UmColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: UmColors.ink, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: UmColors.ink, width: 2),
        ),
      ),
    );
  }
}