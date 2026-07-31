import 'package:flutter/material.dart';
import '../design_tokens/app_typography.dart';
import 'app_button.dart';

/// Header row for a content section: title (+ optional supporting text) on
/// the left, one compact action on the right. Used for e.g.
/// "5 เมนูน่าลองจากหมู" + "เปลี่ยนชุด".
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
    this.actionIcon,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTypography.caption),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          AppButton(
            label: actionLabel!,
            onPressed: onActionTap,
            variant: AppButtonVariant.text,
            icon: actionIcon,
            expand: false,
          ),
      ],
    );
  }
}
