import 'package:flutter/material.dart';

import '../theme.dart';

/// Port of `.topbar` + `.nav-back`/`.nav-title`/`.nav-action` from tokens.css.
/// Not a Flutter [AppBar] on purpose — the mockups' top bar is a plain row
/// inside the scrolling frame, not a fixed Material app bar.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.backLabel = 'Back',
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final String backLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            _NavBack(label: backLabel, onTap: onBack!)
          else
            const SizedBox(width: 52),
          Text(
            title,
            style: context.yvotyType.serifStyle(fontSize: 17),
          ),
          trailing ?? const SizedBox(width: 52),
        ],
      ),
    );
  }
}

class _NavBack extends StatelessWidget {
  const _NavBack({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: AppColors.inkSoft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
