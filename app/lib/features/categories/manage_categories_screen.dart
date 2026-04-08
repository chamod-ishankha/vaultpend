import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/category.dart';
import 'category_color_resolver.dart';
import 'category_icon_resolver.dart';
import 'edit_category_screen.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {Category? category}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditCategoryScreen(category: category),
      ),
    );
    // Refresh once after returning from editor
    ref.invalidate(categoryListProvider);
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Remove "${category.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(categoryRepositoryProvider).delete(category.id);
      ref.invalidate(categoryListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryListProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openEditor(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveBody(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (items) {
            final visibleCount = items.where((c) => c.isVisible).length;
            final hiddenCount = items.length - visibleCount;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _CategoryPreviewCard(categories: items.take(5).toList()),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        title: 'VISIBILITY',
                        status: 'HEALTHY',
                        description: '$visibleCount Visible, $hiddenCount Hidden',
                        icon: Icons.visibility_rounded,
                        accentColor: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        title: 'ANALYTICS',
                        status: '${items.length}',
                        description: 'Total Categories',
                        icon: Icons.auto_graph_rounded,
                        accentColor: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'MANAGE CATEGORIES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ...items.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CategoryListItem(
                    category: c,
                    onTap: () => _openEditor(context, ref, category: c),
                    onToggleVisibility: (v) async {
                      final updated = Category()
                        ..id = c.id
                        ..name = c.name
                        ..iconKey = c.iconKey
                        ..color = c.color
                        ..description = c.description
                        ..isVisible = v;
                      await ref.read(categoryRepositoryProvider).put(updated);
                      ref.invalidate(categoryListProvider);
                    },
                    onDelete: () => _deleteCategory(context, ref, c),
                  ),
                )),
                const SizedBox(height: 100),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryPreviewCard extends StatelessWidget {
  final List<Category> categories;
  const _CategoryPreviewCard({required this.categories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ObsidianCard(
      level: ObsidianCardTonalLevel.high,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORY PREVIEW',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          categories.isEmpty
              ? Text(
                  'No categories configured',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: categories.map((c) {
                    final color = resolveCategoryColor(context, c.color);
                    return Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.4), width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          resolveCategoryIcon(c.iconKey),
                          color: color,
                          size: 20,
                        ),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 20),
          Text(
            'Organize your infrastructure by deploying categories across your transaction pipeline.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _StatusCard({
    required this.title,
    required this.status,
    required this.description,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.outline,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryListItem extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(bool) onToggleVisibility;

  const _CategoryListItem({
    required this.category,
    required this.onTap,
    required this.onDelete,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = resolveCategoryColor(context, category.color);
    final isVisible = category.isVisible;

    return Dismissible(
      key: ValueKey(category.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded, color: scheme.error),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Category?'),
            content: Text('Remove "${category.name}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed == true;
      },
      onDismissed: (_) => onDelete(),
      child: ObsidianCard(
        level: ObsidianCardTonalLevel.low,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    resolveCategoryIcon(category.iconKey),
                    color: color,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  category.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: isVisible ? scheme.primary : scheme.outline,
                  size: 20,
                ),
                onPressed: () => onToggleVisibility(!isVisible),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
