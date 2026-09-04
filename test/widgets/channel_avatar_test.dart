import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/models/channel.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets(
    'community public channel: groups icon in secondary tint + people badge',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ChannelAvatar(
            type: ChannelType.communityPublic,
            label: 'nomad',
            size: 42,
          ),
        ),
      );
      final avatar = tester.widget<AvatarCircle>(find.byType(AvatarCircle));
      final t = MeshTokens.of(tester.element(find.byType(AvatarCircle)));
      expect(avatar.icon, Icons.groups);
      expect(avatar.color, t.secondary);
      expect(avatar.size, 42);
      expect(find.byIcon(Icons.people), findsOneWidget);
    },
  );

  testWidgets('public channel: public icon in signal tint, no badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ChannelAvatar(type: ChannelType.public, label: 'Public')),
    );
    final avatar = tester.widget<AvatarCircle>(find.byType(AvatarCircle));
    final t = MeshTokens.of(tester.element(find.byType(AvatarCircle)));
    expect(avatar.icon, Icons.public);
    expect(avatar.color, t.signal);
    expect(find.byIcon(Icons.people), findsNothing);
  });

  testWidgets('hashtag and private channels use the primary tint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChannelAvatar(type: ChannelType.hashtag, label: '#a'),
            ChannelAvatar(type: ChannelType.private, label: 'b'),
          ],
        ),
      ),
    );
    final avatars = tester
        .widgetList<AvatarCircle>(find.byType(AvatarCircle))
        .toList();
    final t = MeshTokens.of(tester.element(find.byType(AvatarCircle).first));
    expect(avatars[0].icon, Icons.tag);
    expect(avatars[0].color, t.primary);
    expect(avatars[1].icon, Icons.lock);
    expect(avatars[1].color, t.primary);
  });
}
