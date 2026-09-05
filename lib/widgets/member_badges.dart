import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/member_store.dart';
import '../theme/app_theme.dart';

/// The trust badges beside a member's name (DESIGN.md §5): the
/// verified-UM-student pill on every account (a platform marker — every
/// member passed the UM email gate, ADR 0001) and the gold Admin pill on
/// the single admin (ADR 0003).
class MemberBadges extends StatelessWidget {
  const MemberBadges({super.key, required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: UmColors.goldSoft,
            border: Border.all(color: UmColors.ink, width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.badgeCheck500, size: 16, color: UmColors.ink),
              SizedBox(width: 6),
              Text(
                'Verified UM student',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: UmColors.ink,
                ),
              ),
            ],
          ),
        ),
        if (member.isAdmin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: UmColors.gold,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Admin',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: UmColors.ink,
              ),
            ),
          ),
      ],
    );
  }
}
