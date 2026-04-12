import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.feltGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Oh Hell',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.gold,
                    fontSize: 72,
                    letterSpacing: 4,
                    shadows: [
                      const Shadow(
                        color: Color(0x88000000),
                        blurRadius: 8,
                        offset: Offset(3, 3),
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'The Trick-Taking Card Game',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textOnDark.withAlpha(180),
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}
