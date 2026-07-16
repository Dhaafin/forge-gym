import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'core/widgets/forge_spinner.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    Widget getHomeScreen() {
      // If it has data (even if currently loading or in error state), use the data to route.
      // This prevents login/logout transitions from popping up fullscreen loading/error screens.
      if (authState.hasValue) {
        final token = authState.value;
        if (token != null) {
          return const DashboardPage();
        }
        return const LoginPage();
      }

      // Initial boot failed (e.g. secure storage lookup failed)
      if (authState.hasError) {
        final error = authState.error!;
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Initialization Error',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.error),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Initial boot loading screen (checking secure storage on startup)
      return const Scaffold(
        body: Center(
          child: ForgeSpinner(
            size: 40,
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Forge Gym',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: getHomeScreen(),
    );
  }
}
