import 'package:flutter/material.dart';

/// Persistent, centered background icon for the companion-connect screens
/// (2026-08-29 redesign) — always at the true center of the screen body,
/// behind the status chip/switcher/list/form, which may visually cover it.
/// Replaces the old per-screen `EmptyState` icon that only existed while
/// the state/port list was empty and disappeared once results arrived.
class ScreenWatermarkIcon extends StatelessWidget {
  const ScreenWatermarkIcon({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.10),
          ),
          child: Icon(
            icon,
            size: 52,
            color: scheme.primary.withValues(alpha: 0.32),
          ),
        ),
      ),
    );
  }
}
