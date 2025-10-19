import 'dart:ui';
import 'package:flutter/material.dart';

class CheckBadge extends StatelessWidget {
  const CheckBadge({
    super.key,
    required this.done,
    required this.onTap,
    this.tooltipWhenDone = 'Mark incomplete',
    this.tooltipWhenTodo = 'Mark complete',
  });

  final bool done;
  final VoidCallback onTap;
  final String tooltipWhenDone;
  final String tooltipWhenTodo;

  @override
  Widget build(BuildContext context) {
    final icon = done ? Icons.check : Icons.radio_button_unchecked;
    final bg = done ? Colors.green : Colors.black54;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: bg.withOpacity(0.65),
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Tooltip(
              message: done ? tooltipWhenDone : tooltipWhenTodo,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.check, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
