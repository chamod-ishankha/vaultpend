import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/category.dart';
import 'category_color_catalog.dart';
import 'category_color_resolver.dart';
import 'category_icon_catalog.dart';
import 'category_icon_resolver.dart';

class EditCategoryScreen extends ConsumerStatefulWidget {
  const EditCategoryScreen({super.key, this.category});

  /// Null = create; non-null = rename.
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

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _nameCtrl.text = c.name;
      _descriptionCtrl.text = c.description ?? '';
      _selectedIconKey = c.iconKey ?? '';
      _selectedColorKey = c.color ?? '';
    }
  }

  Color _previewColor(BuildContext context) {
    return resolveCategoryColor(context, _selectedColorKey);
  }

  Color _idealForeground(Color background) {
    final luminance = background.computeLuminance();
    return luminance < 0.5 ? Colors.white : Colors.black87;
  }

  Future<void> _pickIcon() async {
    final catalog = await ref.read(categoryIconCatalogProvider.future);
    if (!mounted) {
      return;
    }
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        var search = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = search.trim().toLowerCase();
            final filtered = catalog.where((option) {
              if (query.isEmpty) return true;
              return option.key.contains(query) ||
                  option.label.toLowerCase().contains(query);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose an icon',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search icons',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setSheetState(() {
                          search = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, ''),
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('No icon'),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (context, _) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          final isSelected = option.key == _selectedIconKey;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: Icon(
                                option.icon,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            title: Text(option.label),
                            subtitle: Text(option.key),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle)
                                : null,
                            onTap: () =>
                                Navigator.pop(sheetContext, option.key),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedIconKey = picked;
    });
  }

  Future<void> _pickColor() async {
    final catalog = await ref.read(categoryColorCatalogProvider.future);
    if (!mounted) {
      return;
    }
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a color',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, ''),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('No color'),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: catalog.length,
                    separatorBuilder: (context, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = catalog[index];
                      final isSelected = option.key == _selectedColorKey;
                      final optionColor = resolveCategoryColor(
                        context,
                        option.key,
                      );
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: optionColor,
                          child: Icon(
                            Icons.palette_outlined,
                            color: _idealForeground(optionColor),
                          ),
                        ),
                        title: Text(option.label),
                        subtitle: Text(option.key),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle)
                            : null,
                        onTap: () => Navigator.pop(sheetContext, option.key),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedColorKey = picked;
    });
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
    final ok = await repo.isNameAvailable(name, excludingId: existing?.id);
    if (!ok) {
      setState(() {
        _error = 'You already have a category with this name';
        _saving = false;
      });
      return;
    }
    final c = existing ?? Category();
    c.name = name;
    c.description = _descriptionCtrl.text.trim().isEmpty
        ? null
        : _descriptionCtrl.text.trim();
    c.iconKey = _selectedIconKey.trim().isEmpty
        ? null
        : _selectedIconKey.trim();
    c.color = _selectedColorKey.trim().isEmpty
        ? null
        : _selectedColorKey.trim();
    await repo.put(c);
    ref.invalidate(categoryListProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;
    final iconCatalogAsync = ref.watch(categoryIconCatalogProvider);
    final iconCatalog = iconCatalogAsync.value ?? const <CategoryIconOption>[];
    final selectedLabel = _iconLabelForKey(iconCatalog, _selectedIconKey);
    final colorCatalogAsync = ref.watch(categoryColorCatalogProvider);
    final colorCatalog =
        colorCatalogAsync.value ?? const <CategoryColorOption>[];
    final selectedColorLabel = _colorLabelForKey(
      colorCatalog,
      _selectedColorKey,
    );

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit category' : 'New category')),
      body: ResponsiveBody(
        maxWidth: 680,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => _saving ? null : _save(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionCtrl,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Icon (optional)',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _previewColor(context),
                        child: Icon(
                          resolveCategoryIcon(_selectedIconKey),
                          size: 18,
                          color: _idealForeground(_previewColor(context)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedIconKey.trim().isEmpty
                              ? 'No icon selected'
                              : selectedLabel == null
                              ? normalizeIconKey(_selectedIconKey)
                              : '$selectedLabel · ${normalizeIconKey(_selectedIconKey)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Color (optional)',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _previewColor(context),
                              child: Icon(
                                Icons.color_lens_outlined,
                                size: 18,
                                color: _idealForeground(_previewColor(context)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedColorKey.trim().isEmpty
                                    ? 'No color selected'
                                    : selectedColorLabel == null
                                    ? _selectedColorKey
                                    : '$selectedColorLabel · ${normalizeCategoryColorKey(_selectedColorKey)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _saving ? null : _pickColor,
                              icon: const Icon(Icons.palette_outlined),
                              label: const Text('Choose color'),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedColorKey = '';
                                      });
                                    },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _saving ? null : _pickIcon,
                        icon: const Icon(Icons.grid_view_outlined),
                        label: const Text('Choose icon'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _selectedIconKey = '';
                                });
                              },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? 'Save' : 'Add category'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _iconLabelForKey(List<CategoryIconOption> catalog, String? iconKey) {
  final normalized = normalizeIconKey(iconKey ?? '');
  if (normalized.isEmpty) {
    return null;
  }
  for (final option in catalog) {
    if (option.key == normalized) {
      return option.label;
    }
  }
  return null;
}

String? _colorLabelForKey(List<CategoryColorOption> catalog, String? colorKey) {
  final normalized = normalizeCategoryColorKey(colorKey ?? '');
  if (normalized.isEmpty) {
    return null;
  }
  for (final option in catalog) {
    if (option.key == normalized) {
      return option.label;
    }
  }
  return null;
}
