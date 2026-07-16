import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ForgeSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const ForgeSearchBar({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  State<ForgeSearchBar> createState() => _ForgeSearchBarState();
}

class _ForgeSearchBarState extends State<ForgeSearchBar> {
  late final TextEditingController _controller;
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _showClearButton = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ForgeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      _controller = widget.controller ?? TextEditingController();
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final show = _controller.text.isNotEmpty;
    if (show != _showClearButton) {
      setState(() {
        _showClearButton = show;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
        suffixIcon: _showClearButton
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 20),
                onPressed: () {
                  _controller.clear();
                  if (widget.onChanged != null) {
                    widget.onChanged!('');
                  }
                  if (widget.onClear != null) {
                    widget.onClear!();
                  }
                },
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
