import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../live_session_page.dart';
import '../log_past_session_page.dart';
import '../../controllers/live_session_controller.dart';
import '../../../../core/services/foreground_task_handler.dart';

class SessionModePickerSheet extends ConsumerWidget {
  const SessionModePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center_rounded, color: AppTheme.primary),
              const SizedBox(width: 12),
              Text(
                'Ready to train?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ModeCard(
            title: 'START LIVE SESSION',
            subtitle: 'Track your workout now',
            icon: Icons.play_circle_filled_rounded,
            isPrimary: true,
            onTap: () async {
              Navigator.pop(context);
              
              // Initialize foreground service if needed
              await ForegroundServiceManager.init();
              
              ref.read(liveSessionControllerProvider.notifier).startLiveSession();
              final state = ref.read(liveSessionControllerProvider);
              if (state.draft != null) {
                await ForegroundServiceManager.startService(state.draft!.title, state.draft!.startTime);
              }
              
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LiveSessionPage()),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          _ModeCard(
            title: 'LOG PAST SESSION',
            subtitle: 'Already done? Log it here',
            icon: Icons.description_rounded,
            isPrimary: false,
            onTap: () {
              Navigator.pop(context);
              ref.read(liveSessionControllerProvider.notifier).startPastSession();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogPastSessionPage()),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? AppTheme.primary.withValues(alpha: 0.5) : Colors.white10,
            width: isPrimary ? 2 : 1,
          ),
          color: isPrimary ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
        ),
        child: Row(
          children: [
            Icon(icon, color: isPrimary ? AppTheme.primary : Colors.white70, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPrimary ? AppTheme.primary : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }
}
