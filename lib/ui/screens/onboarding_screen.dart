import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/onboarding_provider.dart';
import '../../utils/onboarding_content.dart';
import '../../utils/tag_utils.dart';
import '../theme/tokens.dart';
import '../widgets/action_buttons.dart';
import '../widgets/choice_chip.dart';
import '../widgets/task_tile.dart';

/// First-run setup: ask for a name, then let the user make their first tags
/// with a live preview of how they look on tasks. Nothing is saved until
/// Finish, so quitting halfway starts over next launch.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 2;
  static const _maxNameLength = 30;
  static const _transition = Duration(milliseconds: 220);

  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _tags = <String>[];
  TagNameError? _tagError;
  int _step = 0;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _next() {
    if (_saving) return;
    if (_step < _stepCount - 1) {
      FocusScope.of(context).unfocus();
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_saving || _step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _step--);
  }

  /// Drops what was entered on the current step and moves on.
  void _skip() {
    if (_saving) return;
    if (_step == 0) {
      _nameController.clear();
    } else {
      _tags.clear();
      _tagController.clear();
      _tagError = null;
    }
    _next();
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final done = await ref
        .read(onboardingProvider.notifier)
        .finish(name: _nameController.text, tags: List.of(_tags));
    // On success the gate swaps this screen out.
    if (done || !mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not finish setting up. Try again.')),
    );
  }

  void _addTag(String raw) {
    final error = validateTagName(raw, _tags);
    setState(() {
      _tagError = error;
      if (error == null) {
        _tags.add(raw.trim());
        _tagController.clear();
      }
    });
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final lastStep = _step == _stepCount - 1;

    return PopScope(
      // Back steps back through the flow and only leaves from the first step.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _Progress(step: _step, count: _stepCount),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : _transition,
                  // The default centres a step that is shorter than the area.
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      BloopSpace.x4,
                      BloopSpace.x6,
                      BloopSpace.x4,
                      BloopSpace.x4,
                    ),
                    child: _step == 0 ? _nameStep(context) : _tagsStep(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BloopSpace.x4,
                  BloopSpace.x2,
                  BloopSpace.x4,
                  BloopSpace.x2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PrimaryButton(
                      label: lastStep ? 'Finish' : 'Next',
                      expand: true,
                      onPressed: _saving ? null : _next,
                    ),
                    Row(
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: _saving ? null : _back,
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: _saving ? null : _skip,
                          child: Text(lastStep ? 'Skip tags' : 'Skip'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameStep(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloopTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Welcome to Bloop', style: theme.textTheme.headlineLarge),
        ),
        const SizedBox(height: BloopSpace.x3),
        Text(
          "Let's get you set up. It only takes a minute.",
          style: theme.textTheme.bodyLarge?.copyWith(color: tokens.muted),
        ),
        const SizedBox(height: BloopSpace.x8),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(_maxNameLength)],
          onSubmitted: (_) => _next(),
          decoration: const InputDecoration(
            labelText: 'What should we call you?',
            helperText: 'You can change this later in Settings.',
          ),
        ),
      ],
    );
  }

  Widget _tagsStep(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloopTokens.of(context);
    final suggestions = [
      for (final s in suggestedTags)
        if (validateTagName(s, _tags) == null) s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Tag your tasks', style: theme.textTheme.headlineLarge),
        ),
        const SizedBox(height: BloopSpace.x3),
        Text(
          'Tags help you tell tasks apart at a glance. Add a few now, or '
          'skip and make them later in Settings.',
          style: theme.textTheme.bodyLarge?.copyWith(color: tokens.muted),
        ),
        const SizedBox(height: BloopSpace.x6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_tagError != null) setState(() => _tagError = null);
                },
                onSubmitted: _addTag,
                decoration: InputDecoration(
                  labelText: 'New tag',
                  errorText: _tagError?.message,
                ),
              ),
            ),
            const SizedBox(width: BloopSpace.x3),
            Padding(
              padding: const EdgeInsets.only(top: BloopSpace.x1),
              child: FilledButton(
                onPressed: () => _addTag(_tagController.text),
                child: const Text('Add'),
              ),
            ),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: BloopSpace.x4),
          Wrap(
            spacing: BloopSpace.x2,
            runSpacing: BloopSpace.x2,
            children: [
              for (final s in suggestions)
                BloopChoiceChip(
                  key: ValueKey('suggestion-$s'),
                  label: s,
                  selected: false,
                  icon: Icons.add,
                  onSelected: (_) => _addTag(s),
                ),
            ],
          ),
        ],
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: BloopSpace.x4),
          Wrap(
            spacing: BloopSpace.x2,
            runSpacing: BloopSpace.x2,
            children: [
              for (final tag in _tags)
                InputChip(
                  key: ValueKey('tag-$tag'),
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                  deleteButtonTooltipMessage: 'Remove $tag',
                ),
            ],
          ),
        ],
        const SizedBox(height: BloopSpace.x8),
        _TagPreview(tags: _tags),
      ],
    );
  }
}

/// "Step 1 of 2" with a bar segment per step.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BloopSpace.x4,
        BloopSpace.x4,
        BloopSpace.x4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${step + 1} of $count',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: BloopSpace.x2),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: BloopSpace.x2),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= step ? tokens.action : tokens.border,
                        borderRadius: BorderRadius.circular(BloopRadii.sm),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sample task rows carrying the user's tags, so it is clear what a tag looks
/// like and how it helps tell tasks apart. Shows suggested tags until the
/// user has made one.
class _TagPreview extends StatelessWidget {
  const _TagPreview({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloopTokens.of(context);
    final example = tags.isEmpty;
    final tasks = buildPreviewTasks(
      DateTime.now(),
      example ? suggestedTags : tags,
    );
    final summary = [
      for (final t in tasks)
        t.tags.isEmpty ? t.title : '${t.title}, tagged ${t.tags.first}',
    ].join('; ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          example ? 'What tags look like' : 'Your tags on tasks',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: BloopSpace.x1),
        Text(
          example
              ? 'Example tags shown. Add your own to see them here.'
              : 'This is how they will appear on your task list.',
          style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
        ),
        const SizedBox(height: BloopSpace.x3),
        Semantics(
          label: 'Preview of tasks. $summary',
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(BloopRadii.lg),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: tokens.border),
                    borderRadius: BorderRadius.circular(BloopRadii.lg),
                  ),
                  child: Column(
                    children: [
                      for (final task in tasks)
                        TaskTile(key: ValueKey(task.id), task: task),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
