import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/category.dart';
import 'category_color_resolver.dart';
import 'category_icon_resolver.dart';

class EditCategoryScreen extends ConsumerStatefulWidget {
  const EditCategoryScreen({super.key, this.category});

  final Category? category;

  @override
  ConsumerState<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends ConsumerState<EditCategoryScreen> {
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _error;
  bool _saving = false;
  String _selectedIconKey = '';
  String _selectedColorKey = '';
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _nameCtrl.text = c.name;
      _descriptionCtrl.text = c.description ?? '';
      _selectedIconKey = c.iconKey ?? '';
      _selectedColorKey = c.color ?? '';
      _isVisible = c.isVisible;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Enter a name';
        _saving = false;
      });
      return;
    }
    final repo = ref.read(categoryRepositoryProvider);
    final existing = widget.category;
    final available = await repo.isNameAvailable(
      name,
      excludingId: existing?.id,
    );
    if (!available) {
      setState(() {
        _error = 'Category name already exists';
        _saving = false;
      });
      return;
    }

    try {
      final c = existing ?? Category();
      c.name = name;
      c.description = _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim();
      c.iconKey = _selectedIconKey.isEmpty ? null : _selectedIconKey;
      c.color = _selectedColorKey.isEmpty ? null : _selectedColorKey;
      c.isVisible = _isVisible;

      await repo.put(c);
      ref.invalidate(categoryListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEdit = widget.category != null;
    final previewColor = resolveCategoryColor(context, _selectedColorKey);
    final previewIcon = resolveCategoryIcon(_selectedIconKey);
    final ext = theme.vaultSpend;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        centerTitle: false,
        title: Text(
          isEdit ? 'Edit Category' : 'New Category',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Save',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            if (_error != null) _buildErrorCard(scheme, _error!),

            // Form Section
            _buildInputSection(
              theme: theme,
              scheme: scheme,
              ext: ext,
              label: 'Category Name',
              controller: _nameCtrl,
              hint: 'e.g. Monthly Subscriptions',
              isLarge: true,
            ),
            const SizedBox(height: 24),
            _buildInputSection(
              theme: theme,
              scheme: scheme,
              ext: ext,
              label: 'Description',
              controller: _descriptionCtrl,
              hint:
                  'Detail how this category tracks your liquid capital movement...',
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Preview Section
            _buildPreviewSection(
              theme: theme,
              scheme: scheme,
              ext: ext,
              previewColor: previewColor,
              previewIcon: previewIcon,
            ),
            const SizedBox(height: 32),

            // Insights (Bento boxes)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildVisibilityBento(theme, scheme, ext)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBentoCard(
                      theme: theme,
                      scheme: scheme,
                      ext: ext,
                      title: 'Analytics',
                      description: 'Smart tagging generates trend sparklines.',
                      icon: Icons.auto_graph_rounded,
                      accentColor: scheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            ObsidianButton(
              onPressed: _save,
              isLoading: _saving,
              text: isEdit ? 'Update category' : 'Add category',
              enableShimmer: true,
              width: double.infinity,
            ),
            const SizedBox(height: 24),
            Text(
              'Securely stored in your Digital Obsidian vault',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required ThemeData theme,
    required ColorScheme scheme,
    required VaultSpendThemeExtension ext,
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isLarge = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(ext.editCategoryFieldRadius),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: isLarge
                ? theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  )
                : theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    height: 1.5,
                  ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: scheme.outline),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection({
    required ThemeData theme,
    required ColorScheme scheme,
    required VaultSpendThemeExtension ext,
    required Color previewColor,
    required IconData previewIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(
          ext.editCategoryPreviewSectionRadius,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Glow
          Positioned(
            top: -64,
            right: -64,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withOpacity(0.08),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Content
          Column(
            children: [
              Text(
                'CATEGORY PREVIEW',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: ext.editCategoryPreviewAvatarSize,
                height: ext.editCategoryPreviewAvatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [previewColor, previewColor.withOpacity(0.6)],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: previewColor.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(previewIcon, size: 48, color: scheme.surface),
                ),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 250;
                  final children = [
                    _buildCustomizationAction(
                      theme: theme,
                      scheme: scheme,
                      icon: Icons.grid_view_rounded,
                      color: scheme.primary,
                      label: 'Choose Icon',
                      onTap: _showIconPicker,
                    ),
                    if (!isNarrow)
                      const SizedBox(width: 16)
                    else
                      const SizedBox(height: 16),
                    _buildCustomizationAction(
                      theme: theme,
                      scheme: scheme,
                      icon: Icons.palette_rounded,
                      color: scheme.secondary,
                      label: 'Choose Color',
                      onTap: _showColorPicker,
                    ),
                  ];
                  if (isNarrow) {
                    return Column(children: children);
                  }
                  return Row(children: children);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationAction({
    required ThemeData theme,
    required ColorScheme scheme,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityBento(
    ThemeData theme,
    ColorScheme scheme,
    VaultSpendThemeExtension ext,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ext.editCategoryBentoRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 16,
                color: _isVisible ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'VISIBILITY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _isVisible ? scheme.primary : scheme.outline,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              SizedBox(
                height: 24,
                child: Switch(
                  value: _isVisible,
                  onChanged: (v) => setState(() => _isVisible = v),
                  activeThumbColor: scheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isVisible
                ? 'Category appears in your obsidian dashboard.'
                : 'Hidden from your primary transaction pipelines.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoCard({
    required ThemeData theme,
    required ColorScheme scheme,
    required VaultSpendThemeExtension ext,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ext.editCategoryBentoRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ColorScheme scheme, String error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIconPicker() async {
    final catalog = await ref.read(categoryIconCatalogProvider.future);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131317),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text('SELECT ICON', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: catalog.length,
                itemBuilder: (ctx, i) {
                  final option = catalog[i];
                  final isSelected = option.key == _selectedIconKey;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _selectedIconKey = option.key);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      child: Icon(
                        option.icon,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() async {
    final catalog = await ref.read(categoryColorCatalogProvider.future);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131317),
      showDragHandle: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SELECT COLOR',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: catalog.map((option) {
                  final color = resolveCategoryColor(context, option.key);
                  final isSelected = option.key == _selectedColorKey;
                  return InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () {
                      setState(() => _selectedColorKey = option.key);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
