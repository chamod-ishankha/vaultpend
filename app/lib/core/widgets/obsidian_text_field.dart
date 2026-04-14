import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class ObsidianTextField extends StatefulWidget {
  const ObsidianTextField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.inputFormatters,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.validator,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  State<ObsidianTextField> createState() => _ObsidianTextFieldState();
}

class _ObsidianTextFieldState extends State<ObsidianTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            widget.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: ext.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              TextFormField(
                focusNode: _focusNode,
                controller: widget.controller,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                onChanged: widget.onChanged,
                maxLines: widget.maxLines,
                validator: widget.validator,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  prefixIcon: widget.prefixIcon != null
                      ? IconTheme(
                          data: IconThemeData(
                            color: _isFocused ? scheme.primary : scheme.outline,
                            size: 20,
                          ),
                          child: widget.prefixIcon!,
                        )
                      : null,
                  suffixIcon: widget.suffixIcon != null
                      ? IconTheme(
                          data: IconThemeData(
                            color: _isFocused ? scheme.primary : scheme.outline,
                            size: 20,
                          ),
                          child: widget.suffixIcon!,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  // Hide standard error text since we might want custom error handling or positioning,
                  // but for now, let it show if needed, or hide it if it breaks the layout.
                  // We'll keep it for now but might need more styling.
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
                ),
                textCapitalization: widget.textCapitalization,
                autofocus: widget.autofocus,
                inputFormatters: widget.inputFormatters,
              ),
              // Focused Glow Bottom Border
              Positioned(
                bottom: 0,
                left: 12,
                right: 12,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  decoration: BoxDecoration(
                    color: _isFocused ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: _isFocused
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, -1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
