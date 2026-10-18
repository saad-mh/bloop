import '../models/task.dart';

/// Tags offered as one-tap suggestions in onboarding.
const suggestedTags = ['personal', 'college', 'work'];

const exampleTaskTitle = 'Complete this task to see what happens';

/// The task onboarding leaves on Home. Due a minute ago, so it reads NOW and
/// sits above anything else; carries [tag] when the user made one.
Task buildExampleTask(DateTime now, {String? tag}) => Task(
  title: exampleTaskTitle,
  dueDateTime: now.subtract(const Duration(minutes: 1)),
  tags: tag == null ? [] : [tag],
);

/// Titles for the sample rows in the tag preview.
const _previewTitles = [
  'Hand in the assignment',
  'Pay the electricity bill',
  'Prepare the Friday update',
];

/// Most sample rows the tag preview shows.
const previewRowCount = 3;

/// Sample rows for the tag step, each carrying a different one of [tags]. With
/// fewer tags than rows the last rows go untagged, which shows the contrast.
/// The newest tags are used when there are more than fit.
///
/// Rows are due tomorrow, so none reads NOW or late and none ticks.
List<Task> buildPreviewTasks(DateTime now, List<String> tags) {
  final shown = tags.length > previewRowCount
      ? tags.sublist(tags.length - previewRowCount)
      : tags;
  return [
    for (var i = 0; i < _previewTitles.length; i++)
      Task(
        id: 'preview-$i',
        title: _previewTitles[i],
        dueDateTime: DateTime(now.year, now.month, now.day + 1, 9 + 4 * i),
        tags: i < shown.length ? [shown[i]] : [],
      ),
  ];
}
