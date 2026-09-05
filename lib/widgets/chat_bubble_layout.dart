/// Bubble geometry shared by the direct and channel chats (2026-09-05
/// decision, `.mockups/theme/default/chat-bubble-layout.html`). Not style
/// tokens: these are structural and don't move with the Custom Style
/// spacing ladder.
class ChatBubbleLayout {
  ChatBubbleLayout._();

  /// Sender avatar inside the bubble header, next to the name.
  static const avatarSize = 18.0;

  /// Gap between that avatar and the sender name.
  static const headerGap = 8.0;

  /// Same gap above and below the quoted-reply block.
  static const quoteGap = 10.0;

  /// Bubble `maxWidth` as a fraction of the message list width, both
  /// directions.
  static const widthFraction = 0.85;
}
