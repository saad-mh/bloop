import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tags_provider.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return const Center(child: Text('No tags yet'));
          }
          return ListView.builder(
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ListTile(
                title: Text(tag),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final controller = TextEditingController(text: tag);
                        final newTag = await showDialog<String>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Rename tag'),
                            content: TextField(
                              controller: controller,
                              decoration: const InputDecoration(hintText: 'Tag'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(
                                    context, controller.text.trim()),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                        if (newTag != null && newTag.isNotEmpty) {
                          await ref
                              .read(tagsProvider.notifier)
                              .renameTag(tag, newTag);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref.read(tagsProvider.notifier).deleteTag(tag);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = TextEditingController();
          final newTag = await showDialog<String>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('New tag'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Tag'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: const Text('Add'),
                ),
              ],
            ),
          );
          if (newTag != null && newTag.isNotEmpty) {
            await ref.read(tagsProvider.notifier).addTag(newTag);
          }
        },
        heroTag: 'tags_fab',
        child: const Icon(Icons.add),
      ),
    );
  }
}
