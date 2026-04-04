import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/category.dart';
import 'category_color_catalog.dart';
import 'category_color_resolver.dart';
import 'category_icon_catalog.dart';
import 'category_icon_resolver.dart';
import 'edit_category_screen.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  static const _defaultNames = {'Food', 'Utilities', 'Development'};

  Future<void> _openEditor(BuildContext context, {Category? category}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditCategoryScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryListProvider);
    final iconCatalogAsync = ref.watch(categoryIconCatalogProvider);
    final iconCatalog = iconCatalogAsync.value ?? const <CategoryIconOption>[];
    final iconLabelByKey = {
      for (final option in iconCatalog) option.key: option.label,
    };
    final colorCatalogAsync = ref.watch(categoryColorCatalogProvider);
    final colorCatalog =
        colorCatalogAsync.value ?? const <CategoryColorOption>[];
    final colorLabelByKey = {
      for (final option in colorCatalog) option.key: option.label,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ResponsiveBody(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Text(
                  'No categories yet.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final category = items[index];
                final isDefault = _defaultNames.contains(category.name);
                final hasDescription = (category.description ?? '')
                    .trim()
                    .isNotEmpty;
                final hasIcon = (category.iconKey ?? '').trim().isNotEmpty;
                final hasColor = (category.color ?? '').trim().isNotEmpty;
                final resolvedIcon = resolveCategoryIcon(category.iconKey);
                final resolvedColor = hasColor
                    ? resolveCategoryColor(context, category.color)
                    : Theme.of(context).colorScheme.surfaceContainerHighest;
                final iconForeground = _idealForeground(resolvedColor);

                final subtitleParts = <String>[];
                if (isDefault) {
                  subtitleParts.add('Starter category');
                }
                if (hasDescription) {
                  subtitleParts.add(category.description!.trim());
                }
                if (hasIcon) {
                  final normalizedIcon = normalizeIconKey(
                    category.iconKey ?? '',
                  );
                  subtitleParts.add(
                    'icon: ${iconLabelByKey[normalizedIcon] ?? normalizedIcon}',
                  );
                }
                if (hasColor) {
                  final normalizedColor = normalizeCategoryColorKey(
                    category.color ?? '',
                  );
                  subtitleParts.add(
                    'color: ${colorLabelByKey[normalizedColor] ?? normalizedColor}',
                  );
                }

                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: resolvedColor,
                    child: Icon(resolvedIcon, size: 16, color: iconForeground),
                  ),
                  title: Text(category.name),
                  subtitle: subtitleParts.isEmpty
                      ? null
                      : Text(
                          subtitleParts.join(' • '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _openEditor(context, category: category);
                        ref.invalidate(categoryListProvider);
                      } else if (value == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Delete category?'),
                            content: Text(
                              'Expenses using “${category.name}” will show as uncategorized.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await ref
                              .read(categoryRepositoryProvider)
                              .delete(category.id);
                          ref.invalidate(categoryListProvider);
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _openEditor(context);
          ref.invalidate(categoryListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Color _idealForeground(Color background) {
  final luminance = background.computeLuminance();
  return luminance < 0.5 ? Colors.white : Colors.black87;
}
