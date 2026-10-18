import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/remote_asset.dart';
import '../../services/remote_asset_service.dart';
import '../theme/tokens.dart';

/// Returns the local file for [asset], downloading it first if needed.
///
/// The first download asks the user, showing the link so they can check it. An
/// accepted prompt is remembered and later downloads go ahead without asking;
/// a cancelled one is not, so the next sound or image asks again. Returns null
/// if the user declines, cancels, or the download fails.
Future<File?> ensureRemoteAsset(
  BuildContext context,
  WidgetRef ref,
  RemoteAsset asset,
) async {
  final service = ref.read(remoteAssetServiceProvider);
  final cached = service.cachedFile(asset);
  if (cached != null) return cached;

  if (!service.consentGranted) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _DownloadConsentDialog(asset: asset, url: service.urlFor(asset)),
    );
    if (accepted != true) return null;
    await service.grantConsent();
    if (!context.mounted) return null;
  }

  final cancel = RemoteAssetCancel();
  final progress = ValueNotifier<double?>(null);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  var progressOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadProgressDialog(
      asset: asset,
      progress: progress,
      onCancel: cancel.cancel,
    ),
  ).whenComplete(() => progressOpen = false);

  try {
    return await service.download(
      asset,
      onProgress: (fraction) => progress.value = fraction,
      cancel: cancel,
    );
  } on RemoteAssetDownloadException catch (e) {
    if (!cancel.isCancelled) {
      messenger?.showSnackBar(
        SnackBar(content: Text("Couldn't download ${asset.label}. $e")),
      );
    }
    return null;
  } finally {
    if (progressOpen) navigator.pop();
    progress.dispose();
  }
}

class _DownloadConsentDialog extends StatefulWidget {
  const _DownloadConsentDialog({required this.asset, required this.url});

  final RemoteAsset asset;
  final String url;

  @override
  State<_DownloadConsentDialog> createState() => _DownloadConsentDialogState();
}

class _DownloadConsentDialogState extends State<_DownloadConsentDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final asset = widget.asset;
    return AlertDialog(
      title: Text('Download ${asset.label}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To keep the app small, sounds and images are not built in. '
              'This ${asset.kindLabel} (${asset.sizeLabel}) will be '
              'downloaded once from:',
            ),
            const SizedBox(height: BloopSpace.x3),
            Container(
              padding: const EdgeInsets.only(left: BloopSpace.x3),
              decoration: BoxDecoration(
                color: tokens.sunken,
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(BloopRadii.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.url,
                      key: const Key('remoteAssetUrl'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: _copied ? 'Copied' : 'Copy link',
                    onPressed: _copy,
                    icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BloopSpace.x3),
            Text(
              'If you accept, other sounds and images will download when you '
              'pick them, without asking again.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog({
    required this.asset,
    required this.progress,
    required this.onCancel,
  });

  final RemoteAsset asset;
  final ValueListenable<double?> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Downloading ${asset.label}'),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (_, value, _) => LinearProgressIndicator(value: value),
      ),
      actions: [TextButton(onPressed: onCancel, child: const Text('Cancel'))],
    );
  }
}
