import '../style.dart';
import 'default_style.dart';

/// Catalog of every selectable style. To add a new style: create
/// `styles/<name>_style.dart` exporting a `MeshStyle`, then add it to
/// [StyleRegistry.all] below. Never reuse or repurpose an existing `id`.
class StyleRegistry {
  StyleRegistry._();

  static final List<MeshStyle> all = [defaultStyle];

  static MeshStyle byId(String id) {
    for (final style in all) {
      if (style.id == id) return style;
    }
    return defaultStyle;
  }
}
