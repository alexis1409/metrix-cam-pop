import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metrix CAM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content:
                      const Text('¿Estás seguro que deseas cerrar sesión?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (!context.mounted) return;
                await context.read<AuthProvider>().logout();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).primaryColor.withAlpha(25),
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Bienvenido!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.name ?? 'Usuario',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getRoleColor(user?.role).withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getRoleName(user?.role),
                  style: TextStyle(
                    color: _getRoleColor(user?.role),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Botón de Campañas
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/campanias');
                  },
                  icon: const Icon(Icons.campaign),
                  label: const Text('Mis Campañas'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'operativo':
        return 'Operativo';
      case 'agencia_admin':
        return 'Admin Agencia';
      case 'instalador':
        return 'Instalador';
      default:
        return 'Usuario';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'super_admin':
        return Colors.purple;
      case 'operativo':
        return Colors.blue;
      case 'agencia_admin':
        return Colors.teal;
      case 'instalador':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
