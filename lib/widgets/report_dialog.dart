import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'nbr_button.dart';

/// The member-side Report dialog (CONTEXT: Report, ADR 0003): a required
/// reason; submits are written to `reports/{id}` with the reporter's
/// identity from the verified token. Pops with the trimmed reason, or
/// null when cancelled.
Future<String?> showReportDialog(
  BuildContext context, {
  required String title,
  required String description,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReportDialog(title: title, description: description),
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.title, required this.description});

  final String title;
  final String description;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Give a short reason.');
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: UmColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: UmColors.ink, width: 2),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: UmColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.description,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: UmColors.mutedForeground),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: 'Reason (required)',
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
                      color: _error == null
                          ? UmColors.ink
                          : UmColors.destructive,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _error == null
                          ? UmColors.ink
                          : UmColors.destructive,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                      label: 'Submit report',
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
      ),
    );
  }
}
