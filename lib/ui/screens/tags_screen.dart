import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tags_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/tag_utils.dart';
import '../theme/tokens.dart';
import '../widgets/bloop_icon_button.dart';
import '../widgets/screen_header.dart';

/// Create, rename and delete tags, with how many open tasks each one has.
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
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
        await ref.read(tagsProvider.notifier).renameTag(tag, name);
      case _Delete():
        await _confirmDelete(tag);
    }
  }

  Future<void> _confirmDelete(String tag) async {
    final tasks = ref.read(taskListProvider).valueOrNull ?? const [];
    final affected = taskCountForTag(tasks, tag);
    final open = ref.read(tagOpenCountsProvider)[tag] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tokens = BloopTokens.of(context);
        return AlertDialog(
          title: Text('Delete "$tag"?'),
          content: Text(_deleteImpact(affected, open)),
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Tags',
              leading: BloopIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: tagsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (tags) => ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    BloopSpace.x5,
                    BloopSpace.x2,
                    BloopSpace.x5,
                    BloopSpace.x6,
                  ),
                  children: [
                    if (tags.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: BloopSpace.x4,
                        ),
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
              ),
            ),
          ],
        ),
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
                  TextSpan(text: '#', style: TextStyle(color: tokens.muted)),
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

/// What deleting a tag does, in terms of the tasks it touches. [affected]
/// counts completed tasks too; [open] is the part still on the list.
String _deleteImpact(int affected, int open) {
  if (affected == 0) return 'No tasks use this tag.';
  final tasks = affected == 1 ? '1 task' : '$affected tasks';
  final done = affected - open;
  final detail = done == 0
      ? ''
      : ' ($open open, $done completed)';
  return 'It will be removed from $tasks$detail. '
      'The tasks themselves are kept.';
}
