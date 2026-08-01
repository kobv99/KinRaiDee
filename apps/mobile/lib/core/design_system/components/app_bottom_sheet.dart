import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_radius.dart';
import '../design_tokens/app_spacing.dart';
import '../design_tokens/app_typography.dart';
import 'app_button.dart';

/// Standard modal bottom sheet shell (used for substitution suggestions,
/// filters, etc). Always includes a drag handle and a visible close action.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.extraLarge),
      ),
    ),
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.pillRadius,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(child: Text(title, style: AppTypography.headline)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'ปิด',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      );
    },
  );
}

/// Standard confirmation dialog (e.g. exit-cooking confirmation). The
/// destructive action is styled as text-only, never the visual default.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'ทำต่อ',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
      title: Text(title, style: AppTypography.title),
      content: Text(message, style: AppTypography.body),
      actionsPadding: const EdgeInsets.all(AppSpacing.lg),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: Text(destructive ? cancelLabel : cancelLabel),
        ),
        AppButton(
          label: confirmLabel,
          expand: false,
          variant: destructive
              ? AppButtonVariant.secondary
              : AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Lightweight success/info toast (SnackBar under the hood). Never blocks
/// the UI, per spec ("avoid blocking dialogs for minor success messages").
void showAppToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mediumRadius,
        ),
        content: Text(
          message,
          style: AppTypography.body.copyWith(color: AppColors.textOnPrimary),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
}
