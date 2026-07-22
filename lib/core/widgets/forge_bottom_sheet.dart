import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a standardized, premium bottom sheet.
Future<T?> showForgeBottomSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget child,
  bool isScrollControlled = true,
  bool isLoading = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return ForgeBottomSheetLayout(
        title: title,
        subtitle: subtitle,
        isLoading: isLoading,
        child: child,
      );
    },
  );
}

/// The layout structure for the premium bottom sheet.
class ForgeBottomSheetLayout extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool isLoading;

  const ForgeBottomSheetLayout({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Body content
                child,
              ],
            ),
          ),
        ),

        // Blur loading overlay
        if (isLoading)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A reusable bottom sheet selector showing a list of options.
Future<String?> showForgeOptionSelector({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Map<String, String> options,
  String? selectedValue,
  IconData Function(String key)? iconBuilder,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Options list
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: options.entries.map((entry) {
                      final isSelected = entry.key == selectedValue;
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
                          leading: iconBuilder != null
                              ? Icon(
                                  iconBuilder(entry.key),
                                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                                )
                              : null,
                          title: Text(
                            entry.value,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                              : null,
                          onTap: () => Navigator.pop(sheetContext, entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
