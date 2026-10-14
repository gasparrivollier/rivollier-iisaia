import 'package:flutter/material.dart';

import '../theme.dart';

enum TagVariant { forest, terracotta, gold }

/// Port of `.tag` from tokens.css.
class PillTag extends StatelessWidget {
  const PillTag(this.label, {super.key, this.variant = TagVariant.forest});

  final String label;
  final TagVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      TagVariant.forest => (AppColors.forestSoft, AppColors.forest),
      TagVariant.terracotta => (AppColors.terracottaSoft, AppColors.terracotta),
      TagVariant.gold => (AppColors.goldSoft, AppColors.goldDarkText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    );
  }
}

/// Port of `.quota-pill` from tokens.css.
class QuotaPill extends StatelessWidget {
  const QuotaPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.forest, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

/// Port of `.chip` from tokens.css.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : AppColors.paperRaised,
          border: Border.all(color: selected ? AppColors.forest : AppColors.lineStrong),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.paper : AppColors.inkSoft,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
