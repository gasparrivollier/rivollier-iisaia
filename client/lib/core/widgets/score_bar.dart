import 'package:flutter/material.dart';

import '../theme.dart';

/// Port of `.scorebar-track`/`.scorebar-fill` from tokens.css.
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.value});

  /// 0.0 - 1.0
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: 6,
        color: AppColors.line,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: AppColors.forest),
        ),
      ),
    );
  }
}
