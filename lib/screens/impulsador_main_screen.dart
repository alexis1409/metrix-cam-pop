import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/demostrador_provider.dart';
import 'demostrador/demostrador_home_content.dart';
import 'profile/profile_content.dart';

class ImpulsadorMainScreen extends StatefulWidget {
  const ImpulsadorMainScreen({super.key});

  @override
  State<ImpulsadorMainScreen> createState() => _ImpulsadorMainScreenState();
}

class _ImpulsadorMainScreenState extends State<ImpulsadorMainScreen> {
  int _currentIndex = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeData();
      });
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final demostradorProvider = context.read<DemostradorProvider>();

    if (authProvider.user != null) {
      demostradorProvider.setUser(authProvider.user);
      await demostradorProvider.loadAsignacionesHoy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DemostradorHomeContent(),
      const ProfileContent(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      extendBody: true,
      bottomNavigationBar: _buildModernNavBar(),
    );
  }

  Widget _buildModernNavBar() {
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark.withAlpha(230)
                  : Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withAlpha(40)
                      : AppColors.primaryStart.withAlpha(20),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? AppColors.borderDark.withAlpha(100)
                    : Colors.white.withAlpha(200),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Inicio',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentIndex == index;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryStart.withAlpha(isDark ? 30 : 15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive
                    ? AppColors.primaryStart
                    : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? AppColors.primaryStart
                    : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
