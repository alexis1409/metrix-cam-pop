import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    debugPrint('>>> SplashScreen: Starting auth check...');
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) {
      debugPrint('>>> SplashScreen: Not mounted after delay');
      return;
    }

    try {
      debugPrint('>>> SplashScreen: Checking auth status...');
      final authProvider = context.read<AuthProvider>();
      await authProvider.checkAuthStatus();

      if (!mounted) {
        debugPrint('>>> SplashScreen: Not mounted after auth check');
        return;
      }

      debugPrint('>>> SplashScreen: isAuthenticated = ${authProvider.isAuthenticated}');
      if (authProvider.isAuthenticated) {
        debugPrint('>>> SplashScreen: Navigating to /impulsador');
        Navigator.of(context).pushReplacementNamed('/impulsador');
      } else {
        debugPrint('>>> SplashScreen: Navigating to /login');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e, stack) {
      debugPrint('>>> SplashScreen ERROR: $e');
      debugPrint('>>> Stack: $stack');
      // En caso de error, ir a login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Color rojo del logo Metrix
    const metrixRed = Color(0xFFE52D27);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF8F9FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Metrix
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: metrixRed,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: metrixRed.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/icon/icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // App name - Metrix Cam
                  const Text(
                    'Metrix Cam',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Eslogan
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: metrixRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Inteligencia Analítica',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: metrixRed,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                  // Modern loading indicator
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation(metrixRed),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cargando...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
