import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import 'mesh_dashed_divider.dart';

class EmojiPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;

  const EmojiPicker({super.key, required this.onEmojiSelected});

  static const List<String> quickEmojis = ['👍', '❤️', '😂', '🎉', '👏', '🔥'];

  static const List<String> smileys = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😅',
    '😂',
    '🤣',
    '😊',
    '😇',
    '🙂',
    '🙃',
    '😉',
    '😌',
    '😍',
    '🥰',
    '😘',
    '😗',
    '😙',
    '😚',
    '😋',
    '😛',
    '😝',
    '😜',
    '🤪',
    '🤨',
    '🧐',
    '🤓',
    '😎',
    '🥸',
    '🤩',
    '🥳',
    '😏',
    '😒',
    '😞',
    '😔',
    '😟',
    '😕',
    '🙁',
    '😣',
    '😖',
    '😫',
    '😩',
    '🥺',
    '😢',
    '😭',
    '😤',
    '😠',
    '😡',
    '🤬',
    '🤯',
    '😳',
    '🥵',
    '🥶',
    '😱',
    '😨',
    '😰',
    '😥',
    '😓',
    '🤗',
    '🤔',
    '🤭',
    '🤫',
    '🤥',
    '😶',
  ];
  static const List<String> gestures = [
    '👍',
    '👎',
    '👊',
    '✊',
    '🤛',
    '🤜',
    '🤞',
    '✌️',
    '🤟',
    '🤘',
    '👌',
    '🤌',
    '🤏',
    '👈',
    '👉',
    '👆',
    '👇',
    '☝️',
    '👋',
    '🤚',
    '🖐️',
    '✋',
    '🖖',
    '👏',
    '🙌',
    '👐',
    '🤲',
    '🤝',
    '🙏',
    '✍️',
    '💅',
    '🤳',
    '💪',
  ];
  static const List<String> hearts = [
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '💔',
    '❤️‍🔥',
    '❤️‍🩹',
    '💕',
    '💞',
    '💓',
    '💗',
    '💖',
    '💘',
    '💝',
    '💟',
    '💌',
    '💢',
    '💥',
    '💫',
    '💦',
    '💨',
    '🕳️',
    '💬',
    '👁️‍🗨️',
    '🗨️',
    '🗯️',
    '💭',
  ];
  static const List<String> objects = [
    '🎉',
    '🎊',
    '🎈',
    '🎁',
    '🎀',
    '🪅',
    '🪆',
    '🏆',
    '🥇',
    '🥈',
    '🥉',
    '⚽',
    '⚾',
    '🥎',
    '🏀',
    '🏐',
    '🏈',
    '🏉',
    '🎾',
    '🥏',
    '🎳',
    '🏏',
    '🏑',
    '🏒',
    '🥍',
    '🏓',
    '🏸',
    '🥊',
    '🥋',
    '🥅',
    '⛳',
    '🔥',
    '⭐',
    '🌟',
    '✨',
    '⚡',
    '💡',
    '🔦',
    '🏮',
    '🪔',
    '📱',
    '💻',
    '⌚',
    '📷',
    '📺',
    '📻',
    '🎵',
    '🎶',
    '🚀',
  ];

  Map<String, List<String>> _emojiCategories(AppLocalizations l10n) {
    return {
      l10n.emojiCategorySmileys: smileys,
      l10n.emojiCategoryGestures: gestures,
      l10n.emojiCategoryHearts: hearts,
      l10n.emojiCategoryObjects: objects,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emojiCategories = _emojiCategories(l10n);
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MeshTokens.of(context).lg),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(MeshTokens.of(context).spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.chat_addReaction,
                  style: TextStyle(
                    // 03-roles-chrome.md: titleSmall + 5 (default 13+5=18).
                    fontSize:
                        (Theme.of(context).textTheme.titleSmall?.fontSize ??
                            13) +
                        5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MeshTokens.of(context).spacingMd,
              vertical: MeshTokens.of(context).spacingXs,
            ),
            child: Wrap(
              spacing: 12,
              children: quickEmojis
                  .map(
                    (emoji) => InkWell(
                      onTap: () {
                        onEmojiSelected(emoji);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.all(
                          MeshTokens.of(context).spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(
                            MeshTokens.of(context).xs,
                          ),
                        ),
                        child: Text(
                          emoji,
                          style: MeshTokens.of(context).emoji(),
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const MeshDashedDivider(space: 16),
          Expanded(
            child: DefaultTabController(
              length: emojiCategories.length,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: emojiCategories.keys
                        .map((cat) => Tab(text: cat))
                        .toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: emojiCategories.values
                          .map(
                            (emojis) => GridView.builder(
                              padding: EdgeInsets.all(
                                MeshTokens.of(context).spacingXs,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                  ),
                              itemCount: emojis.length,
                              itemBuilder: (context, index) => InkWell(
                                onTap: () {
                                  onEmojiSelected(emojis[index]);
                                  Navigator.pop(context);
                                },
                                child: Center(
                                  child: Text(
                                    emojis[index],
                                    style: MeshTokens.of(context).emoji(),
                                    textHeightBehavior:
                                        const TextHeightBehavior(
                                          applyHeightToFirstAscent: false,
                                          applyHeightToLastDescent: false,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
