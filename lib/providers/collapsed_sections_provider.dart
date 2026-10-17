import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/task_sections.dart';

/// Home sections currently folded away. Whenever starts collapsed; the choice
/// lasts for the session and is shared by every tag filter.
final collapsedSectionsProvider = StateProvider<Set<TaskSection>>(
  (ref) => {TaskSection.whenever},
);
