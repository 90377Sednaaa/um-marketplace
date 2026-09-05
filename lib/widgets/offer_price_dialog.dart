import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'nbr_button.dart';

/// Neubrutalist offer dialog (DESIGN.md screen 3/6): whole pesos only,
/// validation inline. Pops with the offered price, or null on cancel.
Future<double?> showOfferPriceDialog(BuildContext context) {
  return showDialog<double>(
    context: context,
    builder: (_) => const _OfferPriceDialog(),
  );
}

class _OfferPriceDialog extends StatefulWidget {
  const _OfferPriceDialog();

  @override
  State<_OfferPriceDialog> createState() => _OfferPriceDialogState();
}

class _OfferPriceDialogState extends State<_OfferPriceDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final price = double.tryParse(raw);
    String? problem;
    if (price == null || price <= 0) {
      problem = 'Enter a price above zero.';
    } else if (price != price.roundToDouble()) {
      problem = 'Use whole pesos only.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(price!.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: UmColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: UmColors.ink, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Make an offer',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: UmColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your offer lands on the thread as an offer message. '
              'No money moves in the app.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: UmColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 250',
                errorText: _error,
                filled: true,
                fillColor: UmColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _error == null ? UmColors.ink : UmColors.destructive,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _error == null ? UmColors.ink : UmColors.destructive,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: NbrButton(
                    label: 'Cancel',
                    fill: UmColors.surface,
                    labelColor: UmColors.ink,
                    stretch: true,
                    compact: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NbrButton(
                    label: 'Send offer',
                    fill: UmColors.gold,
                    labelColor: UmColors.ink,
                    stretch: true,
                    compact: true,
                    onPressed: _submit,
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
