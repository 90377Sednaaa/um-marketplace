import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../data/listing_store.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_dialog.dart';
import '../widgets/nbr_button.dart';

/// Picks one photo from the gallery and returns compressed bytes (photo
/// memory stays inside the Listing document, ADR 0006). Returns null when
/// the user cancels.
Future<Uint8List?> pickAndCompressGalleryPhoto() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 900,
    imageQuality: 70,
  );
  if (picked == null) return null;
  var bytes = await picked.readAsBytes();
  // Safety net: re-compress anything that still exceeds ~300 KB so 2 photos
  // fit comfortably under Firestore's 1 MiB document limit.
  if (bytes.length > 300 * 1024) {
    bytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 800,
      minHeight: 800,
      quality: 70,
    );
  }
  return bytes;
}

/// The Sell flow (DESIGN.md screen 4, sticker-light cut): a single
/// ink-bordered card — details, price, category/condition, optional photos
/// — published straight to Firestore. Hosted as the second tab of the
/// AppShell: there is no back button (the tab switcher navigates) and
/// publishing hands control back to the shell's Home tab.
class SellScreen extends StatefulWidget {
  const SellScreen({
    super.key,
    required this.sellerId,
    required this.sellerDisplayName,
    required this.listingsStore,
    required this.onPublished,
    this.pickPhoto = pickAndCompressGalleryPhoto,
  });

  final String sellerId;

  /// The seller's own public display name — written onto the listing
  /// (rules validate it against the member doc).
  final String sellerDisplayName;
  final ListingStore listingsStore;

  /// Called after a successful publish so the shell can return to Home.
  final VoidCallback onPublished;

  /// Injectable for tests; default walks the real gallery picker.
  final Future<Uint8List?> Function() pickPhoto;

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();

  String? _category;
  String _condition = 'good';
  final List<Uint8List> _photos = [];

  bool _busy = false;
  String? _error;
  bool _pickFailed = false;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= kMaxListingPhotos) return;
    try {
      final bytes = await widget.pickPhoto();
      if (bytes == null) return;
      if (!mounted) return;
      setState(() {
        _photos.add(bytes);
        _pickFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pickFailed = true);
    }
  }

  Future<void> _publish() async {
    final title = _title.text.trim();
    final price = double.tryParse(_price.text.trim());
    final category = _category;

    String? problem;
    if (title.length < 3) {
      problem = 'Give it a short title (at least 3 characters).';
    } else if (price == null || price <= 0) {
      problem = 'Set a price above zero.';
    } else if (category == null) {
      problem = 'Pick a category.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.listingsStore.createListing(
        widget.sellerId,
        ListingDraft(
          title: title,
          price: price!,
          category: category!,
          condition: _condition,
          sellerDisplayName: widget.sellerDisplayName,
          description: _description.text.trim(),
          location: _location.text.trim(),
          photos: List.of(_photos),
        ),
      );
      if (!mounted) return;
      // Clear the form so a fresh listing starts blank.
      _title.clear();
      _price.clear();
      _location.clear();
      _description.clear();
      setState(() {
        _category = null;
        _condition = 'good';
        _photos.clear();
        _error = null;
        _pickFailed = false;
      });
      widget.onPublished();
    } catch (_) {
      if (mounted) {
        await showBrutalErrorDialog(
          context,
          title: 'Publish failed',
          message: 'Could not publish. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: UmColors.surface,
                      border: Border.all(color: UmColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: UmColors.ink,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _NbrField(
                          controller: _title,
                          hint: 'Title — e.g. Calculus 201 textbook',
                          maxLength: 60,
                        ),
                        const SizedBox(height: 12),
                        _NbrField(
                          controller: _price,
                          hint: 'Price in pesos',
                          prefixText: '₱',
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Category',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 8),
                        _PillSelector<String>(
                          options: kListingCategories,
                          selected: _category,
                          onSelected: (v) => setState(() => _category = v),
                        ),
                        const SizedBox(height: 16),
                        Text('Condition',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 8),
                        _PillSelector<String>(
                          options: kListingConditions,
                          selected: _condition,
                          onSelected: (v) => setState(() => _condition = v),
                        ),
                        const SizedBox(height: 16),
                        _NbrField(
                          controller: _location,
                          hint: 'Location (optional) — e.g. Matina campus',
                          maxLength: 40,
                        ),
                        const SizedBox(height: 16),
                        _NbrField(
                          controller: _description,
                          hint: 'Description (optional) — condition, reason '
                              'for selling, meetup notes…',
                          maxLines: 3,
                          maxLength: 300,
                        ),
                        const SizedBox(height: 16),
                        Text('Photos (up to $kMaxListingPhotos)',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 8),
                        _PhotoGrid(
                          photos: _photos,
                          canAdd: _photos.length < kMaxListingPhotos,
                          onAdd: _addPhoto,
                          onRemove: (index) => setState(
                              () => _photos.removeAt(index)),
                        ),
                        if (_pickFailed) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Could not load that photo — try another one.',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: UmColors.destructive),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                              color: UmColors.destructive,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        NbrButton(
                          label: _busy ? 'Publishing…' : 'Publish listing',
                          stretch: true,
                          onPressed: _busy ? null : _publish,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your listing appears on the Home feed the moment it '
                    'goes live.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: UmColors.mutedForeground,
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

/// Ink-bordered input (DESIGN.md §5): white fill, 2 dp ink border, 8 dp
/// radius, 3 dp hard shadow.
class _NbrField extends StatelessWidget {
  const _NbrField({
    required this.controller,
    required this.hint,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;

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
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          prefixText: prefixText,
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: UmColors.mutedForeground,
              ),
        ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

/// Neubrutalist pill selector: selected = gold fill, else white.
class _PillSelector<T> extends StatelessWidget {
  const _PillSelector({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          InkWell(
            onTap: () => onSelected(option),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: option == selected ? UmColors.gold : UmColors.surface,
                border: Border.all(color: UmColors.ink, width: 2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                option.toString(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: UmColors.ink,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  final List<Uint8List> photos;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < photos.length; i++)
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: UmColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.memory(
                    photos[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: UmColors.muted,
                      child: const Icon(LucideIcons.imageOff300,
                          color: UmColors.mutedForeground),
                    ),
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: InkWell(
                    onTap: () => onRemove(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: UmColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.x300,
                        size: 14,
                        color: UmColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (canAdd)
          InkWell(
            onTap: onAdd,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: UmColors.surface,
                border: Border.all(color: UmColors.ink, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.camera300,
                  size: 26, color: UmColors.ink),
            ),
          ),
      ],
    );
  }
}