import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:meshcore_open/theme/mesh_tokens.dart';
import 'package:meshcore_open/theme/mesh_theme.dart';

void main() {
  Widget rolesSample() {
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final tokens = MeshTokens.of(context);
        return SizedBox(
          width: 320,
          height: 340,
          child: ColoredBox(
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'bodyMedium — main content',
                    style: textTheme.bodyMedium,
                  ),
                  Text('bodySmall — secondary', style: textTheme.bodySmall),
                  Text('titleSmall — card title', style: textTheme.titleSmall),
                  Text('labelSmall — tiny label', style: textTheme.labelSmall),
                  Text(
                    'labelMedium — list title',
                    style: textTheme.labelMedium,
                  ),
                  Text(
                    'monoCaption 11 — meta',
                    style: tokens.monoCaption(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    'monoBody 13 — content',
                    style: tokens.monoBody(color: scheme.onSurface),
                  ),
                  Text(
                    'ACCENT LABEL',
                    style: tokens.accentLabel(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  goldenTest(
    'default style text roles (dark)',
    fileName: 'theme_roles_dark',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'roles',
          child: Theme(
            data: MeshTheme.dark().copyWith(
              extensions: const [MeshTokens.defaultTokens],
            ),
            child: rolesSample(),
          ),
        ),
      ],
    ),
  );

  goldenTest(
    'default style text roles (light)',
    fileName: 'theme_roles_light',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'roles',
          child: Theme(
            data: MeshTheme.light().copyWith(
              extensions: const [MeshTokens.defaultTokens],
            ),
            child: rolesSample(),
          ),
        ),
      ],
    ),
  );
}
