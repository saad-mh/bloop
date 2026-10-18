import 'dart:io';

import 'package:bloop/models/remote_asset.dart';
import 'package:bloop/services/remote_asset_service.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:bloop/ui/widgets/remote_asset_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _rain = RemoteAsset.audio(
  path: 'audio/rain_1.mp3',
  label: 'Rain Drop',
  sizeBytes: 3477420,
);
const _forest = RemoteAsset.image(
  path: 'scenery/forest_1.jpg',
  label: 'Forest Path',
  sizeBytes: 718920,
);

/// Skips the network: "downloading" just records the request.
class _FakeAssets extends RemoteAssetService {
  final fetched = <String>[];
  final _have = <String>{};
  bool consent = false;

  @override
  bool get consentGranted => consent;

  @override
  Future<void> grantConsent() async => consent = true;

  @override
  File? cachedFile(RemoteAsset asset) =>
      _have.contains(asset.path) ? File('/tmp/${asset.fileName}') : null;

  @override
  Future<File> download(
    RemoteAsset asset, {
    void Function(double? fraction)? onProgress,
    RemoteAssetCancel? cancel,
  }) async {
    fetched.add(asset.path);
    _have.add(asset.path);
    return File('/tmp/${asset.fileName}');
  }
}

void main() {
  late _FakeAssets assets;
  late List<File?> results;

  Future<void> pump(WidgetTester tester) async {
    results = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [remoteAssetServiceProvider.overrideWith((ref) => assets)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  TextButton(
                    onPressed: () async => results.add(
                      await ensureRemoteAsset(context, ref, _rain),
                    ),
                    child: const Text('rain'),
                  ),
                  TextButton(
                    onPressed: () async => results.add(
                      await ensureRemoteAsset(context, ref, _forest),
                    ),
                    child: const Text('forest'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => assets = _FakeAssets());

  testWidgets('shows the link, the size and a copy button', (tester) async {
    await pump(tester);
    await tester.tap(find.text('rain'));
    await tester.pumpAndSettle();

    expect(find.text('Download Rain Drop?'), findsOneWidget);
    expect(find.textContaining('3.3 MB'), findsOneWidget);
    expect(
      find.text(
        'https://raw.githubusercontent.com/saad-mh/bloop/master/assets/'
        'audio/rain_1.mp3',
      ),
      findsOneWidget,
    );

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.tap(find.byTooltip('Copy link'));
    await tester.pump();
    expect(copied, endsWith('audio/rain_1.mp3'));
    expect(find.byTooltip('Copied'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('cancel downloads nothing and asks again next time', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('rain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(assets.fetched, isEmpty);
    expect(assets.consent, isFalse);

    // A different file asks again.
    await tester.tap(find.text('forest'));
    await tester.pumpAndSettle();
    expect(find.text('Download Forest Path?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(assets.fetched, isEmpty);
  });

  testWidgets('accepting downloads, and later files do not ask', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('rain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(assets.consent, isTrue);
    expect(assets.fetched, ['audio/rain_1.mp3']);
    expect(results.single, isNotNull);

    await tester.tap(find.text('forest'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Download Forest Path?'), findsNothing);
    expect(assets.fetched, ['audio/rain_1.mp3', 'scenery/forest_1.jpg']);
  });

  testWidgets('an already downloaded file opens without a prompt', (
    tester,
  ) async {
    assets._have.add(_rain.path);
    await pump(tester);
    await tester.tap(find.text('rain'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(results.single, isNotNull);
  });
}
