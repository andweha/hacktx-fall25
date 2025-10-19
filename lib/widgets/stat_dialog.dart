// lib/widgets/stat_dialog.dart
import 'package:flutter/material.dart';

/// A reusable, minimalist stat popup you can use for streaks, XP, rankings, etc.
///
/// You control the text via [title], [value], and optional [caption]/[description].
/// You can also pass custom [body] content and/or [actions].
///
/// NOTE: This widget only renders the rounded sheet content.
/// The caller is responsible for showing it inside a dialog and handling animations.
class StatDialog extends StatelessWidget {
  const StatDialog({
    super.key,
    required this.title,
    required this.value,
    this.caption,
    this.description,
    this.body,
    this.actions,
    this.height = 260,
    this.showGrabHandle = true,
    this.onClose,
  });

  /// e.g., "Streak"
  final String title;

  /// e.g., "3"
  final String value;

  /// e.g., "weeks"
  final String? caption;

  /// Extra explanatory text (multi-line allowed).
  final String? description;

  /// Optional custom content area below the header; use for charts, chips, etc.
  final Widget? body;

  /// Optional action buttons shown at the bottom (e.g., Close).
  final List<Widget>? actions;

  /// Fixed height for the bottom sheet content (outside container + padding handled by caller).
  final double height;

  /// Shows the little drag handle at the top.
  final bool showGrabHandle;

  /// If provided, shows an "X" close button in the top-right and calls this when pressed.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 12,
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Stack(
            children: [
              // Close button (optional)
              if (onClose != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ),
              // Main content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showGrabHandle) ...[
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0D9CC),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Header (value + title + caption)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (caption != null && caption!.isNotEmpty)
                              Text(
                                caption!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (description != null &&
                      description!.trim().isNotEmpty) ...[
                    Text(
                      description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Custom body area (e.g., chips, small list, chart)
                  if (body != null) ...[
                    Expanded(child: body!),
                    const SizedBox(height: 12),
                  ] else
                    const Spacer(),

                  // Actions (e.g., Close)
                  if (actions != null && actions!.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!,
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
