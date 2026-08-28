import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Temporary Chats tab body — replaced by the real screen in the Chats
/// stage.
class ChatPlaceholder extends StatelessWidget {
  const ChatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Conversations',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: UmColors.mutedForeground,
        ),
      ),
    );
  }
}