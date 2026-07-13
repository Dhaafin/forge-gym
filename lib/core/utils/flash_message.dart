import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FlashMessage {
  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, String message, {required bool isError}) {
    // Dismiss the previous entry immediately if it exists
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    
    // Create new OverlayEntry
    final entry = OverlayEntry(
      builder: (context) => _FlashMessageWidget(
        message: message,
        isError: isError,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _FlashMessageWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _FlashMessageWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_FlashMessageWidget> createState() => _FlashMessageWidgetState();
}

class _FlashMessageWidgetState extends State<_FlashMessageWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Elastic bounce curve going forward, smooth snap back going reverse
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInBack,
    );

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_controller.isAnimating || _controller.isDismissed) return;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final statusColor = widget.isError ? AppTheme.error : AppTheme.primary;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Positioned sliding translation from above screen (-160) to safe top area + 16px
        final double topPosition = -160.0 + (_animation.value * (160.0 + statusBarHeight + 16.0));
        return Positioned(
          top: topPosition,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Glowing Neon Accent bar on the left
                        Container(
                          width: 4,
                          height: 32,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          widget.isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                          color: statusColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension FlashMessageExtension on BuildContext {
  void showSuccessFlash(String message) {
    FlashMessage.show(this, message, isError: false);
  }

  void showErrorFlash(String message) {
    FlashMessage.show(this, message, isError: true);
  }
}
