enum RemoteAssetKind { audio, image }

/// Where the optional media lives. These files stay in the repo at the same
/// paths, they just aren't listed in pubspec.yaml, so they don't ship in the
/// app. Don't move them without updating this.
const String remoteAssetBaseUrl =
    'https://raw.githubusercontent.com/saad-mh/bloop/master/assets/';

/// A sound or image fetched on first use instead of being bundled.
class RemoteAsset {
  const RemoteAsset({
    required this.path,
    required this.label,
    required this.kind,
    required this.sizeBytes,
  });

  const RemoteAsset.audio({
    required String path,
    required String label,
    required int sizeBytes,
  }) : this(
         path: path,
         label: label,
         kind: RemoteAssetKind.audio,
         sizeBytes: sizeBytes,
       );

  const RemoteAsset.image({
    required String path,
    required String label,
    required int sizeBytes,
  }) : this(
         path: path,
         label: label,
         kind: RemoteAssetKind.image,
         sizeBytes: sizeBytes,
       );

  /// Path under the repo's `assets/` folder, e.g. `audio/rain_1.mp3`.
  final String path;
  final String label;
  final RemoteAssetKind kind;

  /// Approximate download size, shown in the prompt.
  final int sizeBytes;

  String get fileName => path.split('/').last;

  String get kindLabel => kind == RemoteAssetKind.audio ? 'sound' : 'image';

  String url([String baseUrl = remoteAssetBaseUrl]) => '$baseUrl$path';

  String get sizeLabel {
    final mb = sizeBytes / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(sizeBytes / 1024).round()} KB';
  }
}
