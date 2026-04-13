import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/category.dart';
import 'category_color_resolver.dart';
import 'category_icon_resolver.dart';
import 'edit_category_screen.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Category? category,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditCategoryScreen(category: category),
      ),
    );
    // Refresh once after returning from editor
    ref.invalidate(categoryListProvider);
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
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

  void _showActionMenu(BuildContext context, WidgetRef ref, Category category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131317),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Category'),
              onTap: () {
                Navigator.pop(ctx);
                _openEditor(context, ref, category: category);
              },
            ),
            ListTile(
              leading: Icon(
                category.isVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              title: Text(
                category.isVisible ? 'Hide Category' : 'Show Category',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final updated = Category()
                  ..id = category.id
                  ..name = category.name
                  ..iconKey = category.iconKey
                  ..color = category.color
                  ..description = category.description
                  ..isVisible = !category.isVisible;
                await ref.read(categoryRepositoryProvider).put(updated);
                ref.invalidate(categoryListProvider);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteCategory(context, ref, category);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryListProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        centerTitle: false,
        title: Text(
          'Categories',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: scheme.outline, size: 28),
            onPressed: () {},
            tooltip: 'Search Categories',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Container(
        width: ext.manageCategoriesFabSize,
        height: ext.manageCategoriesFabSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.primaryContainer],
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.3),
              offset: const Offset(0, 8),
              blurRadius: 30,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _openEditor(context, ref),
            child: Icon(Icons.add_rounded, color: scheme.onPrimary, size: 32),
          ),
        ),
      ),
      body: ResponsiveBody(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (items) {
            final visibleCount = items.where((c) => c.isVisible).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
              children: [
                _buildTopSummary(context, visibleCount),
                const SizedBox(height: 16),
                ...items.map((c) => _buildCategoryItem(context, c, ref)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopSummary(BuildContext context, int count) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(ext.manageCategoriesHeaderPadding),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withOpacity(0.8)),
        ),
      ),
      child: Stack(
        children: [
          // Background blurred circle decor
          Positioned(
            right: -32,
            top: -32,
            child: Container(
              width: ext.manageCategoriesDecorSize,
              height: ext.manageCategoriesDecorSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withOpacity(0.04),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withOpacity(0.05),
                    blurRadius: 40,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VAULT STRUCTURE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$count Active Categories',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.7,
                child: Text(
                  'Organize your capital across obsidian-grade vaults. Define flows and monitor velocity per sector.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, Category c, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;
    final color = resolveCategoryColor(context, c.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ext.manageCategoriesCardRadius),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ext.manageCategoriesCardRadius),
          onTap: () => _openEditor(context, ref, category: c),
          child: Padding(
            padding: EdgeInsets.all(ext.manageCategoriesCardPadding),
            child: Row(
              children: [
                // Icon block
                Container(
                  width: ext.manageCategoriesIconTileSize,
                  height: ext.manageCategoriesIconTileSize,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.1),
                        blurRadius: 15,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    resolveCategoryIcon(c.iconKey),
                    color: color,
                    size: ext.manageCategoriesIconSize,
                  ),
                ),

                // Content block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (c.isVisible)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          if (!c.isVisible)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.onSurfaceVariant.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'HIDDEN',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.description?.isNotEmpty == true
                            ? c.description!
                            : 'Asset class tracking',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Action block
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => _showActionMenu(context, ref, c),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
