import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:meshnomad/models/custom_style_overrides.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/theme/styles/custom_style.dart';
import 'package:meshnomad/theme/mesh_theme.dart';

void main() {
  Widget sample() {
    return Builder(
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        final tokens = MeshTokens.of(context);
        return SizedBox(
          width: 260,
          height: 160,
          child: ColoredBox(
            color: tokens.bg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'bodyMedium',
                    style: textTheme.bodyMedium?.copyWith(color: tokens.ink),
                  ),
                  Text('monoBody', style: tokens.monoBody(color: tokens.ink)),
                  const SizedBox(height: 8),
                  Container(width: 60, height: 20, color: tokens.primary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  final overridden = buildCustomStyle(
    const CustomStyleOverrides(
      colorOverrides: {'primary': 0xFFFF3B30, 'bg': 0xFF1A0033},
      fontSizeOverrides: {'bodyMedium': 18.0, 'monoBodySize': 16.0},
    ),
  );

  goldenTest(
    'custom style overrides vs default (dark)',
    fileName: 'custom_style_overrides',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'default',
          child: Theme(
            data: MeshTheme.dark().copyWith(
              extensions: const [MeshTokens.defaultTokens],
            ),
            child: sample(),
          ),
        ),
        GoldenTestScenario(
          name: 'overridden',
          child: Theme(data: overridden.theme, child: sample()),
        ),
      ],
    ),
  );
}
