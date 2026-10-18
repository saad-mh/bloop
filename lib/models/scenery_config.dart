import 'dart:ui';

import 'remote_asset.dart';

enum SceneryType {
  gradient,
  image,
}

class SceneryConfig {
  final SceneryType type;
  final List<Color>? colors;
  final RemoteAsset? asset;

  const SceneryConfig._({
    required this.type,
    this.colors,
    this.asset,
  });

  const SceneryConfig.gradient({required List<Color> colors})
      : this._(type: SceneryType.gradient, colors: colors);

  const SceneryConfig.image({required RemoteAsset asset})
      : this._(type: SceneryType.image, asset: asset);
}
