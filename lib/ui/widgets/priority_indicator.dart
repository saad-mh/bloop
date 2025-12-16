import 'package:flutter/material.dart';

import '../../models/task.dart';

class PriorityIndicator extends StatelessWidget {
  const PriorityIndicator({super.key, required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case Priority.high:
        color = Colors.redAccent;
        break;
      case Priority.medium:
        color = Colors.orangeAccent;
        break;
      case Priority.low:
        color = Colors.green;
        break;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
