import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/carrito_provider.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import 'mis_pedidos_screen.dart';
import '../../utils/responsive.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width > Responsive.tabletBreakpoint;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header con degradado y Avatar
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      child: Text(
                        user?.nombre.isNotEmpty == true
                            ? user!.nombre[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 70),

            // Nombre y Email
            Text(
              user?.nombre ?? 'Usuario',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              user?.email ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Información Detallada
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.pagePadding(width),
              ),
              child: ConstrainedBox(
                constraints: Responsive.maxWidthConstraint(maxWidth: 600),
                child: Column(
                  children: [
                    _buildInfoCard(
                      context,
                      icon: Icons.person_outline,
                      title: 'Nombre Completo',
                      value: user?.nombre ?? 'No especificado',
                    ),
                    _buildInfoCard(
                      context,
                      icon: Icons.phone_android_outlined,
                      title: 'Teléfono',
                      value: user?.telefono ?? 'No especificado',
                    ),
                    _buildInfoCard(
                      context,
                      icon: Icons.location_on_outlined,
                      title: 'Dirección',
                      value: user?.direccion ?? 'No especificada',
                    ),
                    _buildInfoCard(
                      context,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Rol de Usuario',
                      value: user?.rol ?? 'Cliente',
                    ),
                    const SizedBox(height: 24),

                    // Acciones
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildActionTile(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      title: 'Mis Pedidos',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MisPedidosScreen()),
                        );
                      },
                    ),
                    _buildActionTile(
                      context,
                      icon: Icons.lock_outline,
                      title: 'Cambiar Contraseña',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                        );
                      },
                    ),
                    _buildActionTile(
                      context,
                      icon: Icons.logout,
                      title: 'Cerrar Sesión',
                      titleColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: () => _cerrarSesion(context),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required IconData icon, required String title, required String value}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      Color? titleColor,
      Color? iconColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authProvider = context.read<AuthProvider>();
      final carritoProvider = context.read<CarritoProvider>();

      await authProvider.logout();
      carritoProvider.limpiarCarrito();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
