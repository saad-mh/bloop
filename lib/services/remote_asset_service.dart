import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/remote_asset.dart';
import 'storage_service.dart';

final remoteAssetServiceProvider = ChangeNotifierProvider<RemoteAssetService>((
  ref,
) {
  final service = RemoteAssetService();
  service.init();
  return service;
});

class RemoteAssetDownloadException implements Exception {
  const RemoteAssetDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Lets the caller abandon a download that is under way.
class RemoteAssetCancel {
  HttpClient? _client;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }
}

/// Downloads sounds and images on demand and keeps them on disk, so the app
/// ships without them. Whether the user has agreed to downloads is remembered;
/// a refusal is not.
class RemoteAssetService extends ChangeNotifier {
  RemoteAssetService({
    this.baseUrl = remoteAssetBaseUrl,
    Future<Directory> Function()? cacheDirectory,
  }) : _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory;

  static const String consentKey = 'remoteAssets.downloadConsent';

  final String baseUrl;
  final Future<Directory> Function() _cacheDirectory;

  Directory? _dir;
  bool _consent = false;
  bool _disposed = false;
  final Set<String> _downloaded = {};
  final Map<String, Future<File>> _inFlight = {};

  /// True once the user has accepted the download prompt.
  bool get consentGranted => _consent;

  static Future<Directory> _defaultCacheDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/remote_assets');
  }

  String urlFor(RemoteAsset asset) => asset.url(baseUrl);

  /// Finds what is already on disk and the saved consent. Safe to call twice.
  Future<void> init() async {
    try {
      _consent =
          Hive.box(StorageService.settingsBoxName).get(consentKey) as bool? ??
          false;
    } catch (_) {
      // Storage isn't open; start without consent.
    }
    try {
      final dir = await _cacheDirectory();
      await dir.create(recursive: true);
      _dir = dir;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && !entity.path.endsWith('.part')) {
          _downloaded.add(_relative(dir, entity));
        }
      }
    } catch (_) {
      // No usable folder: nothing counts as downloaded.
    }
    _notify();
  }

  String _relative(Directory dir, File file) =>
      file.path.substring(dir.path.length + 1).replaceAll('\\', '/');

  /// The downloaded file, or null if it isn't on disk yet.
  File? cachedFile(RemoteAsset asset) {
    final dir = _dir;
    if (dir == null || !_downloaded.contains(asset.path)) return null;
    return File('${dir.path}/${asset.path}');
  }

  bool isDownloaded(RemoteAsset asset) => cachedFile(asset) != null;

  bool isDownloading(RemoteAsset asset) => _inFlight.containsKey(asset.path);

  Future<void> grantConsent() async {
    _consent = true;
    try {
      await Hive.box(StorageService.settingsBoxName).put(consentKey, true);
    } catch (_) {
      // Kept for this run even if it can't be saved.
    }
    _notify();
  }

  /// Fetches [asset] unless it is already here. [onProgress] gets 0..1, or
  /// null when the server didn't say how big the file is.
  Future<File> download(
    RemoteAsset asset, {
    void Function(double? fraction)? onProgress,
    RemoteAssetCancel? cancel,
  }) {
    final existing = cachedFile(asset);
    if (existing != null) return Future.value(existing);
    return _inFlight[asset.path] ??= _fetch(asset, onProgress, cancel)
        .whenComplete(() {
          _inFlight.remove(asset.path);
          _notify();
        });
  }

  Future<File> _fetch(
    RemoteAsset asset,
    void Function(double? fraction)? onProgress,
    RemoteAssetCancel? cancel,
  ) async {
    final dir = _dir ?? await _initDirectory();
    final target = File('${dir.path}/${asset.path}');
    final part = File('${target.path}.part');
    await target.parent.create(recursive: true);
    _notify();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    cancel?._client = client;
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(urlFor(asset)));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw RemoteAssetDownloadException(
          'The server answered ${response.statusCode}.',
        );
      }
      final total = response.contentLength > 0 ? response.contentLength : null;
      var received = 0;
      sink = part.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(total == null ? null : received / total);
      }
      await sink.close();
      sink = null;
      if (total != null && received != total) {
        throw const RemoteAssetDownloadException('The download ended early.');
      }
      await part.rename(target.path);
      _downloaded.add(asset.path);
      return target;
    } catch (e) {
      await sink?.close().catchError((_) {});
      if (await part.exists()) await part.delete();
      if (cancel?.isCancelled ?? false) {
        throw const RemoteAssetDownloadException('Download cancelled.');
      }
      if (e is RemoteAssetDownloadException) rethrow;
      throw const RemoteAssetDownloadException(
        'Check your connection and try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Directory> _initDirectory() async {
    final dir = await _cacheDirectory();
    await dir.create(recursive: true);
    return _dir = dir;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
