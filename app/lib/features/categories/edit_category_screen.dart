import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../core/widgets/obsidian_text_field.dart';
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
    final available = await repo.isNameAvailable(name, excludingId: existing?.id);
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
      c.description = _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim();
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

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        title: Text(isEdit ? 'Edit Category' : 'New Category'),
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // Hero Preview
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: previewColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: previewColor.withOpacity(0.3), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: previewColor.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(previewIcon, size: 40, color: previewColor),
                  ),
                ),
              ),
            ),

            if (_error != null) _buildErrorCard(scheme, _error!),

            Text(
              'GENERAL',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ObsidianCard(
              level: ObsidianCardTonalLevel.low,
              padding: const EdgeInsets.all(16),
              child: ObsidianTextField(
                controller: _nameCtrl,
                label: 'Category Name',
                hintText: 'e.g. Groceries',
                autofocus: !isEdit,
              ),
            ),

            const SizedBox(height: 32),
            Text(
              'CUSTOMIZATION',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ObsidianCard(
              level: ObsidianCardTonalLevel.low,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSelectionRow(
                    label: 'Category Icon',
                    value: _selectedIconKey.isEmpty ? 'DEFAULT' : _selectedIconKey.toUpperCase(),
                    onTap: _showIconPicker,
                    icon: previewIcon,
                    accentColor: previewColor,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSelectionRow(
                    label: 'Category Color',
                    value: _selectedColorKey.isEmpty ? 'DEFAULT' : _selectedColorKey.toUpperCase(),
                    onTap: _showColorPicker,
                    icon: Icons.palette_rounded,
                    accentColor: previewColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(
              'VISIBILITY',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ObsidianCard(
              level: ObsidianCardTonalLevel.low,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 20,
                    color: _isVisible ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Show in Transaction Pipeline')),
                  Switch(
                    value: _isVisible,
                    onChanged: (v) => setState(() => _isVisible = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            ObsidianButton(
              onPressed: _saving ? null : _save,
              text: isEdit ? 'UPDATE CATEGORY' : 'CREATE CATEGORY',
              isLoading: _saving,
              style: ObsidianButtonStyle.primary,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
    required Color accentColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: accentColor, size: 18),
      ),
      title: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline.withOpacity(0.5)),
    );
  }

  Widget _buildErrorCard(ColorScheme scheme, String error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ObsidianCard(
        level: ObsidianCardTonalLevel.low,
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(error, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w500)),
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
        padding: const EdgeInsets.all(16),
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
                    onTap: () {
                      setState(() => _selectedIconKey = option.key);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary) : null,
                      ),
                      child: Icon(
                        option.icon,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SELECT COLOR', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: catalog.map((option) {
                final color = resolveCategoryColor(context, option.key);
                final isSelected = option.key == _selectedColorKey;
                return InkWell(
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
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
