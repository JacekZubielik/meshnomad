import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';

// MeshCard(elevated: true) — mockup .mockups/depth-shadows.html, "Wariant C
// bg + Wariant B shadow" accepted 2026-08-09; wired into
// contacts_screen.dart's _ContactTile. This preview reproduces that tile in
// isolation for review before a full app build.

@Preview(name: 'MeshCard — elevated (kontakt), dark')
Widget contactCardElevatedDarkPreview() {
  return const _ContactCardPreviewScaffold(theme: null);
}

@Preview(name: 'MeshCard — elevated (kontakt), light')
Widget contactCardElevatedLightPreview() {
  return const _ContactCardPreviewScaffold(theme: false);
}

/// [theme]: null = dark (default app theme), false = light — avoids passing
/// a [ThemeData] literal through the top-level `@Preview` function args.
class _ContactCardPreviewScaffold extends StatelessWidget {
  final bool? theme;

  const _ContactCardPreviewScaffold({required this.theme});

  @override
  Widget build(BuildContext context) {
    final themeData = theme == false
        ? MeshTheme.light().copyWith(
            extensions: const [MeshTokens.defaultTokens],
          )
        : MeshTheme.dark().copyWith(
            extensions: const [MeshTokens.defaultTokens],
          );
    return Theme(
      data: themeData,
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return ColoredBox(
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MeshCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    elevated: true,
                    onTap: () {},
                    child: Row(
                      children: [
                        const AvatarCircle(name: 'Kasia Nowak'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Kasia Nowak',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'cześć, jesteś w zasięgu?',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  MeshCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    elevated: true,
                    onTap: () {},
                    child: Row(
                      children: [
                        const AvatarCircle(name: 'Tomek K.'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Tomek K.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'dotarcie potwierdzone',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
