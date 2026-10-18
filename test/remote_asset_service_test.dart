import 'dart:io';

import 'package:bloop/models/remote_asset.dart';
import 'package:bloop/services/remote_asset_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _asset = RemoteAsset.audio(
  path: 'audio/rain_1.mp3',
  label: 'Rain Drop',
  sizeBytes: 5,
);

void main() {
  late HttpServer server;
  late Directory dir;
  late int status;
  late List<int> body;
  late int requests;

  RemoteAssetService service() => RemoteAssetService(
    baseUrl: 'http://127.0.0.1:${server.port}/',
    cacheDirectory: () async => dir,
  );

  setUp(() async {
    status = 200;
    body = [1, 2, 3, 4, 5];
    requests = 0;
    dir = await Directory.systemTemp.createTemp('remote_assets_test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requests++;
      request.response.statusCode = status;
      request.response.add(body);
      request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  test('builds the link from the repo base and the asset path', () {
    expect(
      _asset.url(),
      'https://raw.githubusercontent.com/saad-mh/bloop/master/assets/'
      'audio/rain_1.mp3',
    );
  });

  test('downloads once, then serves the file from disk', () async {
    final s = service();
    await s.init();
    expect(s.cachedFile(_asset), isNull);

    final file = await s.download(_asset);
    expect(await file.readAsBytes(), body);
    expect(s.cachedFile(_asset)?.path, file.path);

    await s.download(_asset);
    expect(requests, 1);
  });

  test('finds files saved by an earlier run', () async {
    await (await service().download(_asset)).exists();
    final fresh = service();
    await fresh.init();
    expect(fresh.isDownloaded(_asset), isTrue);
  });

  test('a failed download leaves nothing behind', () async {
    status = 404;
    final s = service();
    await s.init();

    await expectLater(
      s.download(_asset),
      throwsA(isA<RemoteAssetDownloadException>()),
    );
    expect(s.isDownloaded(_asset), isFalse);
    expect(dir.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test('consent is off until granted', () async {
    final s = service();
    await s.init();
    expect(s.consentGranted, isFalse);
    await s.grantConsent();
    expect(s.consentGranted, isTrue);
  });
}
