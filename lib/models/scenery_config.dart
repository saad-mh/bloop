import 'dart:ui';

enum SceneryType {
  gradient,
  image,
}

class SceneryConfig {
  final SceneryType type;
  final List<Color>? colors;
  final String? assetPath;

  const SceneryConfig._({
    required this.type,
    this.colors,
    this.assetPath,
  });

  const SceneryConfig.gradient({required List<Color> colors})
      : this._(type: SceneryType.gradient, colors: colors);

  const SceneryConfig.image({required String assetPath})
      : this._(type: SceneryType.image, assetPath: assetPath);
}
