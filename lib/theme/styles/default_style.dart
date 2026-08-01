import '../mesh_theme.dart';
import '../mesh_tokens.dart';
import '../style.dart';

/// The style matching today's shipped UI, unchanged. Built from the
/// existing [MeshTheme.light]/[MeshTheme.dark] plus [MeshTokens.defaultTokens]
/// — no color/radius/font value is redefined here, only re-attached.
final MeshStyle defaultStyle = MeshStyle(
  id: 'default',
  displayName: 'Default',
  light: MeshTheme.light().copyWith(
    extensions: const [MeshTokens.defaultTokens],
  ),
  dark: MeshTheme.dark().copyWith(
    extensions: const [MeshTokens.defaultTokens],
  ),
);
