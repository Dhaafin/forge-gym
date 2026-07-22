import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'forge_bottom_sheet.dart';

/// Shows a standardized, premium bottom sheet selector that fetches data from an API asynchronously.
/// Supports infinite scrolling pagination and debounced search queries.
Future<T?> showForgeApiOptionSelector<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Future<List<T>> Function(String query, int offset) fetchItems,
  required String Function(T item) labelBuilder,
  required String Function(T item) idBuilder,
  T? selectedValue,
  IconData Function(T item)? iconBuilder,
  bool searchEnabled = true,
  String searchHint = 'Search...',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return _ForgeApiOptionSelector<T>(
        title: title,
        subtitle: subtitle,
        fetchItems: fetchItems,
        labelBuilder: labelBuilder,
        idBuilder: idBuilder,
        selectedValue: selectedValue,
        iconBuilder: iconBuilder,
        searchEnabled: searchEnabled,
        searchHint: searchHint,
      );
    },
  );
}

class _ForgeApiOptionSelector<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<List<T>> Function(String query, int offset) fetchItems;
  final String Function(T item) labelBuilder;
  final String Function(T item) idBuilder;
  final T? selectedValue;
  final IconData Function(T item)? iconBuilder;
  final bool searchEnabled;
  final String searchHint;

  const _ForgeApiOptionSelector({
    super.key,
    required this.title,
    this.subtitle,
    required this.fetchItems,
    required this.labelBuilder,
    required this.idBuilder,
    this.selectedValue,
    this.iconBuilder,
    required this.searchEnabled,
    required this.searchHint,
  });

  @override
  State<_ForgeApiOptionSelector<T>> createState() => _ForgeApiOptionSelectorState<T>();
}

class _ForgeApiOptionSelectorState<T> extends State<_ForgeApiOptionSelector<T>> {
  final List<T> _items = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _query = '';
  int _offset = 0;
  static const int _limit = 10;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _searchController.removeListener(_onSearchChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _fetchMoreData();
    }
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final newQuery = _searchController.text.trim();
      if (_query != newQuery) {
        setState(() {
          _query = newQuery;
        });
        _fetchInitialData();
      }
    });
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _offset = 0;
      _items.clear();
      _hasMore = true;
    });

    try {
      final fetched = await widget.fetchItems(_query, 0);
      if (mounted) {
        setState(() {
          _items.addAll(fetched);
          _offset = fetched.length;
          _hasMore = fetched.length >= _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error snackbar or indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load items: $e')),
        );
      }
    }
  }

  Future<void> _fetchMoreData() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final fetched = await widget.fetchItems(_query, _offset);
      if (mounted) {
        setState(() {
          _items.addAll(fetched);
          _offset += fetched.length;
          _hasMore = fetched.length >= _limit;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine height dynamically to prevent overflow but allow screen size usage
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.75;

    return ForgeBottomSheetLayout(
      title: widget.title,
      subtitle: widget.subtitle,
      isLoading: false, // Internal loading handled inside the body for list visibility
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input
            if (widget.searchEnabled) ...[
              TextFormField(
                controller: _searchController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : _items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'No options found',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                ),
                              );
                            }

                            final item = _items[index];
                            final id = widget.idBuilder(item);
                            final label = widget.labelBuilder(item);
                            final isSelected = widget.selectedValue != null &&
                                widget.idBuilder(widget.selectedValue!) == id;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary.withValues(alpha: 0.1)
                                    : Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                leading: widget.iconBuilder != null
                                    ? Icon(
                                        widget.iconBuilder!(item),
                                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                                      )
                                    : null,
                                title: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                                    : null,
                                onTap: () => Navigator.pop(context, item),
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
}
