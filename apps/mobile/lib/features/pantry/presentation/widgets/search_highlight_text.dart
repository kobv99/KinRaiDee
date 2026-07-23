import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class SearchHighlightText extends StatelessWidget {
  const SearchHighlightText({
    required this.text,
    required this.query,
    super.key,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final trimmedQuery = query.trim();
    final matchIndex = text.toLowerCase().indexOf(trimmedQuery.toLowerCase());

    if (trimmedQuery.isEmpty || matchIndex < 0) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: effectiveStyle,
      );
    }

    final matchEnd = matchIndex + trimmedQuery.length;
    final effectiveHighlightStyle =
        highlightStyle ??
        effectiveStyle.copyWith(
          color: AppColors.primaryDark,
          backgroundColor: AppColors.primaryLight,
          fontWeight: FontWeight.w700,
        );

    return Text.rich(
      TextSpan(
        style: effectiveStyle,
        children: [
          if (matchIndex > 0) TextSpan(text: text.substring(0, matchIndex)),
          TextSpan(
            text: text.substring(matchIndex, matchEnd),
            style: effectiveHighlightStyle,
          ),
          if (matchEnd < text.length) TextSpan(text: text.substring(matchEnd)),
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: text,
    );
  }
}
