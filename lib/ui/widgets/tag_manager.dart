import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tags_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/tag_utils.dart';
import '../theme/tokens.dart';
import 'bloop_icon_button.dart';

/// Create, rename and delete tags, with how many open tasks each one has.
///
/// A plain column with no scrolling or outer padding of its own, so it can sit
/// inside a settings list. Tags are monochrome.
class TagManager extends ConsumerStatefulWidget {
  const TagManager({super.key});

  @override
  ConsumerState<TagManager> createState() => _TagManagerState();
}

class _TagManagerState extends ConsumerState<TagManager> {
  final _newController = TextEditingController();
  TagNameError? _newError;

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final error = await ref
        .read(tagsProvider.notifier)
        .addTag(_newController.text);
    if (!mounted) return;
    setState(() => _newError = error);
    if (error == null) _newController.clear();
  }

  Future<void> _edit(String tag) async {
    final action = await showDialog<_TagEdit>(
      context: context,
      builder: (_) => _EditTagDialog(tag: tag),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _Rename(:final name):
        final error = await ref
            .read(tagsProvider.notifier)
            .renameTag(tag, name);
        if (error != null && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      case _Delete():
        await _confirmDelete(tag);
    }
  }

  Future<void> _confirmDelete(String tag) async {
    // Null while the list is loading or failed: say so rather than "none".
    final tasks = ref.read(taskListProvider).valueOrNull;
    final usage = tasks == null ? null : tagUsage(tasks, tag);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tokens = BloopTokens.of(context);
        return AlertDialog(
          title: Text('Delete "$tag"?'),
          content: Text(_deleteImpact(usage)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: tokens.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await ref.read(tagsProvider.notifier).deleteTag(tag);
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final counts = ref.watch(tagOpenCountsProvider);
    final tokens = BloopTokens.of(context);
    final theme = Theme.of(context);

    return tagsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(BloopSpace.x4),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(BloopSpace.x4),
        child: Text('Could not load tags: $e'),
      ),
      data: (tags) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: BloopSpace.x4),
              child: Text(
                'No tags yet. Add one below, then pick it when you '
                'add or edit a task.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.muted,
                ),
              ),
            ),
          for (final tag in tags)
            _TagRow(
              tag: tag,
              openCount: counts[tag] ?? 0,
              onEdit: () => _edit(tag),
            ),
          const SizedBox(height: BloopSpace.x4),
          _buildNewTag(tokens, theme),
        ],
      ),
    );
  }

  Widget _buildNewTag(BloopTokens tokens, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(BloopSpace.x3),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(BloopRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _newController,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_newError != null) setState(() => _newError = null);
              },
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                labelText: 'New tag',
                errorText: _newError?.message,
              ),
            ),
          ),
          const SizedBox(width: BloopSpace.x3),
          Padding(
            padding: const EdgeInsets.only(top: BloopSpace.x1),
            child: FilledButton(onPressed: _add, child: const Text('Add')),
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.openCount,
    required this.onEdit,
  });

  final String tag;
  final int openCount;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: kBloopMinTouchTarget + 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '#',
                    style: TextStyle(color: tokens.muted),
                  ),
                  TextSpan(text: tag),
                  TextSpan(
                    text: '  ·  $openCount open',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          BloopIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit $tag tag',
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// What the edit dialog asked for.
sealed class _TagEdit {}

class _Rename extends _TagEdit {
  _Rename(this.name);
  final String name;
}

class _Delete extends _TagEdit {}

/// Renames a tag, or hands back a request to delete it. Owns its controller
/// so it outlives the dialog's exit animation.
class _EditTagDialog extends ConsumerStatefulWidget {
  const _EditTagDialog({required this.tag});

  final String tag;

  @override
  ConsumerState<_EditTagDialog> createState() => _EditTagDialogState();
}

class _EditTagDialogState extends ConsumerState<_EditTagDialog> {
  late final _controller = TextEditingController(text: widget.tag);
  TagNameError? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final existing = ref.read(tagsProvider).valueOrNull ?? const <String>[];
    final error = validateTagName(
      _controller.text,
      existing,
      renaming: widget.tag,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final name = _controller.text.trim();
    Navigator.pop(context, name == widget.tag ? null : _Rename(name));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    return AlertDialog(
      title: const Text('Edit tag'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Name',
          errorText: _error?.message,
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: tokens.error),
          onPressed: () => Navigator.pop(context, _Delete()),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// What deleting a tag does, in terms of the tasks it touches. [usage] is
/// null when the task list isn't available to count.
String _deleteImpact(({int total, int open})? usage) {
  if (usage == null) {
    return 'It will be removed from every task that uses it. '
        'The tasks themselves are kept.';
  }
  if (usage.total == 0) return 'No tasks use this tag.';
  final tasks = usage.total == 1 ? '1 task' : '${usage.total} tasks';
  final done = usage.total - usage.open;
  final detail = done == 0 ? '' : ' (${usage.open} open, $done completed)';
  return 'It will be removed from $tasks$detail. '
      'The tasks themselves are kept.';
}
