import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'recurrence.dart';

enum Priority { low, medium, high }

const _uuid = Uuid();

@HiveType(typeId: 0)
class Task extends HiveObject {
  Task({
    String? id,
    required this.title,
    this.notes,
    this.dueDateTime,
    this.allDay = false,
    this.recurrence = Recurrence.none,
    this.reminderMinutes,
    this.priority = Priority.medium,
    List<String>? tags,
    this.isCompleted = false,
    DateTime? createdAt,
    this.updatedAt,
    this.completedAt,
    this.notificationId,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now().toUtc(),
        tags = tags ?? [];

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? notes;

  @HiveField(3)
  DateTime? dueDateTime;

  @HiveField(4)
  bool allDay;

  @HiveField(5)
  Recurrence recurrence;

  @HiveField(6)
  int? reminderMinutes; // store minutes for Hive compatibility

  @HiveField(7)
  Priority priority;

  @HiveField(8)
  List<String> tags;

  @HiveField(9)
  bool isCompleted;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime? updatedAt;

  @HiveField(12)
  DateTime? completedAt;

  @HiveField(13)
  int? notificationId;

  Duration? get reminderBefore =>
      reminderMinutes != null ? Duration(minutes: reminderMinutes!) : null;

  Task copyWith({
    String? title,
    String? notes,
    DateTime? dueDateTime,
    bool? allDay,
    Recurrence? recurrence,
    Duration? reminderBefore,
    Priority? priority,
    List<String>? tags,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    int? notificationId,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDateTime: dueDateTime ?? this.dueDateTime,
      allDay: allDay ?? this.allDay,
      recurrence: recurrence ?? this.recurrence,
      reminderMinutes: reminderBefore?.inMinutes ?? reminderMinutes,
      priority: priority ?? this.priority,
      tags: tags ?? List<String>.from(this.tags),
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      notificationId: notificationId ?? this.notificationId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'dueDateTime': dueDateTime?.toIso8601String(),
      'allDay': allDay,
      'recurrence': recurrence.name,
      'reminderMinutes': reminderMinutes,
      'priority': priority.name,
      'tags': tags,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'notificationId': notificationId,
    };
  }

  static Task fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      dueDateTime: json['dueDateTime'] != null
          ? DateTime.tryParse(json['dueDateTime'] as String)
          : null,
      allDay: json['allDay'] as bool? ?? false,
      recurrence: Recurrence.values.firstWhere(
        (r) => r.name == json['recurrence'],
        orElse: () => Recurrence.none,
      ),
      reminderMinutes: json['reminderMinutes'] as int?,
      priority: Priority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => Priority.medium,
      ),
      tags: (json['tags'] as List?)?.cast<String>() ?? <String>[],
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : DateTime.now().toUtc(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      notificationId: json['notificationId'] as int?,
    );
  }
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return Task(
      id: fields[0] as String?,
      title: fields[1] as String? ?? '',
      notes: fields[2] as String?,
      dueDateTime: fields[3] as DateTime?,
      allDay: fields[4] as bool? ?? false,
      recurrence: fields[5] as Recurrence? ?? Recurrence.none,
      reminderMinutes: fields[6] as int?,
      priority: fields[7] as Priority? ?? Priority.medium,
      tags: (fields[8] as List?)?.cast<String>() ?? <String>[],
      isCompleted: fields[9] as bool? ?? false,
      createdAt: fields[10] as DateTime? ?? DateTime.now().toUtc(),
      updatedAt: fields[11] as DateTime?,
      completedAt: fields[12] as DateTime?,
      notificationId: fields[13] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.dueDateTime)
      ..writeByte(4)
      ..write(obj.allDay)
      ..writeByte(5)
      ..write(obj.recurrence)
      ..writeByte(6)
      ..write(obj.reminderMinutes)
      ..writeByte(7)
      ..write(obj.priority)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.completedAt)
      ..writeByte(13)
      ..write(obj.notificationId);
  }
}

class PriorityAdapter extends TypeAdapter<Priority> {
  @override
  final int typeId = 1;

  @override
  Priority read(BinaryReader reader) {
    final index = reader.readByte();
    if (index < 0 || index >= Priority.values.length) {
      return Priority.medium;
    }
    return Priority.values[index];
  }

  @override
  void write(BinaryWriter writer, Priority obj) {
    writer.writeByte(obj.index);
  }
}

class RecurrenceAdapter extends TypeAdapter<Recurrence> {
  @override
  final int typeId = 2;

  @override
  Recurrence read(BinaryReader reader) {
    final index = reader.readByte();
    if (index < 0 || index >= Recurrence.values.length) {
      return Recurrence.none;
    }
    return Recurrence.values[index];
  }

  @override
  void write(BinaryWriter writer, Recurrence obj) {
    writer.writeByte(obj.index);
  }
}
