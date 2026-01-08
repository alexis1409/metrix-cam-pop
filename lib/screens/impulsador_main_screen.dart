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
      bottomNavigationBar: SafeArea(
        child: _buildModernNavBar(),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final demostradorProvider = context.read<DemostradorProvider>();
                await demostradorProvider.loadAsignacionesHoy();
              },
              backgroundColor: AppColors.primaryStart,
              child: const Icon(Icons.refresh, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildModernNavBar() {
    final isDark = context.isDarkMode;
    final navBarHeight = 64.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(60)
                : Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          if (!isDark)
            BoxShadow(
              color: AppColors.primaryStart.withAlpha(10),
              blurRadius: 40,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: navBarHeight,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? AppColors.borderDark.withAlpha(50)
                  : AppColors.border.withAlpha(80),
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                  ? AppColors.primaryStart.withAlpha(25)
                  : AppColors.primaryStart.withAlpha(12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? AppColors.primaryStart
                  : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
              size: 24,
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? AppColors.primaryStart
                    : (isDark ? AppColors.textMutedDark : AppColors.textMuted),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
