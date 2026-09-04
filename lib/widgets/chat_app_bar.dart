import 'package:flutter/material.dart';

import '../theme/mesh_tokens.dart';
import 'app_bar.dart';
import 'mesh_ui.dart';

/// The shared app bar of the two chat screens (direct + channel) —
/// circular/accent family per [[app-bar-schema]]: an explicit accent back
/// arrow on the left, exactly one ⋮ trigger on the right
/// ([MeshAppBarMenuButton], the same widget [meshMainAppBar] uses), and the
/// [title] block centered on the screen. Both sides are 48×48 boxes with a
/// matching 16dp visible inset, so `centerTitle` really means screen center.
AppBar meshChatAppBar(
  BuildContext context, {
  required Widget title,
  required List<PopupMenuEntry<dynamic>> Function(BuildContext) menuItemBuilder,
  String? menuTooltip,
  VoidCallback? onBack,
}) {
  final scheme = Theme.of(context).colorScheme;
  return AppBar(
    // Default IconButton = 48×48 inside the 56dp leading slot → the 24dp
    // glyph sits 4 + 12 = 16dp from the edge.
    leading: IconButton(
      icon: Icon(Icons.arrow_back, color: scheme.primary),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
    ),
    title: title,
    centerTitle: true,
    titleSpacing: 0,
    actions: [
      // AppBarTheme.actionsPadding (right: 4) + this 4 + the 48-box's own
      // (48-32)/2 = 8 centering gap → the circle's visible right edge sits
      // 16dp from the screen edge, the same inset the main cards' ⋮ has
      // after its Transform.translate correction (see meshMainAppBar).
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: MeshAppBarMenuButton(
          itemBuilder: menuItemBuilder,
          tooltip: menuTooltip,
        ),
      ),
    ],
  );
}

/// Title of [meshChatAppBar]: the conversation name only, centered — text
/// only, no avatar, so the direct and channel chat bars are the same height
/// and the same shape (2026-09-04 feedback: a 32px channel avatar in the
/// name row pushed the whole block and read as a different bottom padding).
/// The status badges live in [ChatBadgeBar] under the bar, not here.
class ChatAppBarTitle extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;

  const ChatAppBarTitle({super.key, required this.name, this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Text(name, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (onTap == null) return text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: text,
    );
  }
}

/// The status-badge strip directly under [meshChatAppBar] (2026-09-04) —
/// the exact card Contacts' search field sits in (`contacts_screen.dart`):
/// `MeshCard` with zero margin/padding/radius, no outline and NO shadow of
/// its own — the screen paints a [MeshCardEdgeShadow] at the top of its
/// list `Stack` instead, so the shadow stays above scrolled-up bubbles
/// (issue #149). [badges] is a `ContactBadgeRow`/`ChannelBadgeRow` with
/// `showTrailingIcons: false` and `alignment: WrapAlignment.center` — the
/// same badges the contact/channel cards render, so the strip and the card
/// a user just tapped read as one thing.
class ChatBadgeBar extends StatelessWidget {
  final Widget badges;

  const ChatBadgeBar({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return MeshCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      radius: 0,
      castsShadow: false,
      outlined: false,
      color: Theme.of(context).colorScheme.surface,
      // Full width explicitly: Contacts' card is stretched by its TextField,
      // but a Wrap of badges is content-sized and would leave the card a
      // narrow island in the Column (caught by chat_app_bar_test).
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spacingXs,
            vertical: t.spacingSm,
          ),
          child: badges,
        ),
      ),
    );
  }
}
