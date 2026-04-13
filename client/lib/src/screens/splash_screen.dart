import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:ohhell_client/src/widgets/suit_symbols_row.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/home');
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SuitSymbolsRow(fontSize: 48),
              const SizedBox(height: 24),
              Text(
                'Oh Hell',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.amber,
                      fontSize: 68,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'The Trick-Taking Card Game',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textOnDark.withAlpha(160),
                      fontSize: 15,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 56),
              const CircularProgressIndicator(
                color: AppColors.amber,
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
