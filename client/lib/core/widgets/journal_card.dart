import 'package:flutter/material.dart';

import '../theme.dart';

/// Port of `.journal-card` from tokens.css: the paper-raised card used as the
/// base surface for specimen cards, fact tiles, detail panels, etc.
class JournalCard extends StatelessWidget {
  const JournalCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: content,
    );
  }
}
