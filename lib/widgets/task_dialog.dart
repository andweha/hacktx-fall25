// lib/widgets/task_dialog.dart
import 'dart:ui';

import 'package:flutter/material.dart';

typedef TaskToggleCallback = Future<void> Function();

class TaskDialog extends StatelessWidget {
  const TaskDialog({
    super.key,
    required this.title,
    required this.completed,
    required this.onToggle,
    required this.onCancel,
  });

  final String title;
  final bool completed;
  final TaskToggleCallback onToggle;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return completed
        ? _CompletedTaskDialog(
            title: title,
            onToggle: onToggle,
            onCancel: onCancel,
          )
        : _IncompleteTaskDialog(
            title: title,
            completed: completed,
            onToggle: onToggle,
            onCancel: onCancel,
          );
  }
}

class _IncompleteTaskDialog extends StatelessWidget {
  const _IncompleteTaskDialog({
    required this.title,
    required this.completed,
    required this.onToggle,
    required this.onCancel,
  });

  final String title;
  final bool completed;
  final TaskToggleCallback onToggle;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.7,
      widthFactor: 1,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Material(
            elevation: 12,
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0D9CC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B4034),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    completed
                        ? 'Need to change your mind?'
                        : 'Did you finish this task?',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF7A6F62),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: Icon(
                        completed ? Icons.undo : Icons.check_circle_outline,
                      ),
                      onPressed: onToggle,
                      label: Text(
                        completed ? 'Mark Incomplete' : 'Mark Complete',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: completed
                            ? const Color(0xFFB59F84)
                            : const Color(0xFFEABF4E),
                        foregroundColor: const Color(0xFF4B4034),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0D9CC)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A6F62),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedTaskDialog extends StatelessWidget {
  const _CompletedTaskDialog({
    required this.title,
    required this.onToggle,
    required this.onCancel,
  });

  final String title;
  final TaskToggleCallback onToggle;
  final VoidCallback onCancel;

  static const _dateString = 'October 12, 12:28 PM';
  static const _locationString = 'Kyoto, Japan';
  static const _assetPath =
      'assets/images/task_complete_bg.png'; // Replace with your image.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.65,
      widthFactor: 1,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    _assetPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: const Color(0xFF2A1F1A));
                    },
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [
                          Color.fromRGBO(0, 0, 0, 0.05),
                          Color.fromRGBO(0, 0, 0, 0.45),
                        ],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const [
                              Color.fromRGBO(0, 0, 0, 0.0),
                              Color.fromRGBO(0, 0, 0, 0.65),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ) ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _dateString,
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ) ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    // fontWeight: FontWeight.w700,
                                  ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 4),
                            Text(
                              _locationString,
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 15,
                                    // fontWeight: FontWeight.w700,
                                  ) ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: onToggle,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromRGBO(255, 255, 255, 0.92),
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text('Mark Incomplete'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
