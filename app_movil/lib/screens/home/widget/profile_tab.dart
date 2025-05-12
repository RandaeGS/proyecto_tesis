import 'package:app_movil/screens/home/widget/profile_option_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_services/auth_provider.dart';
import '../../../utils/dialogs.dart';
import 'center_info_card.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userCenter = authProvider.userCenter;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título con estilo
            const Text(
              'Mi Perfil',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Gestione su información personal',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Tarjeta de perfil
            _buildProfileCard(user),

            const SizedBox(height: 24),

            // Información del centro
            if (userCenter != null) ...[
              _buildSectionTitle('Mi Centro'),
              const SizedBox(height: 16),
              CenterInfoCard(userCenter: userCenter),
              const SizedBox(height: 24),
            ],

            // Opciones de usuario
            _buildSectionTitle('Opciones'),
            const SizedBox(height: 16),

            // Cambiar contraseña
            ProfileOptionItem(
              icon: Icons.lock_rounded,
              title: 'Cambiar Contraseña',
              color: Colors.blue,
              onTap: () {
                // Por implementar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Funcionalidad en desarrollo'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),

            // Preferencias
            ProfileOptionItem(
              icon: Icons.settings_rounded,
              title: 'Preferencias',
              color: Colors.green,
              onTap: () {
                // Por implementar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Funcionalidad en desarrollo'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),

            // Información
            ProfileOptionItem(
              icon: Icons.info_rounded,
              title: 'Acerca de la Aplicación',
              color: Colors.purple,
              onTap: () {
                DialogUtils.showSystemInfo(context);
              },
            ),

            // Cerrar sesión
            ProfileOptionItem(
              icon: Icons.logout_rounded,
              title: 'Cerrar Sesión',
              color: Colors.red,
              onTap: () => DialogUtils.showLogoutConfirmation(context),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(dynamic user) {
    final Color primaryColor = const Color(0xFF2c6bed);
    final Color secondaryColor = const Color(0xFF60a3f5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name ?? 'Usuario',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? 'usuario@example.com',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}