import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/carrito_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/change_password_screen.dart';
import '../screens/cliente/perfil_screen.dart';
import '../screens/cliente/mis_pedidos_screen.dart';

class AppMenu extends StatelessWidget {
  const AppMenu({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar Sesión')),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final authProvider = context.read<AuthProvider>();
      final carritoProvider = context.read<CarritoProvider>();

      await authProvider.logout();
      carritoProvider.limpiarCarrito();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(Icons.menu, color: Colors.white),
      color: Colors.black, // Fondo del menú
      itemBuilder: (context) => [
        PopupMenuItem(
          child: const Row(children: [Icon(Icons.person, color: Colors.white), SizedBox(width: 8), Text('Mi Perfil', style: TextStyle(color: Colors.white))]),
          onTap: () {
            Future.delayed(Duration.zero, () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              );
            });
          },
        ),
        PopupMenuItem(
          child: const Row(children: [Icon(Icons.shopping_bag, color: Colors.white), SizedBox(width: 8), Text('Mis Pedidos', style: TextStyle(color: Colors.white))]),
          onTap: () {
            Future.delayed(Duration.zero, () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MisPedidosScreen()),
              );
            });
          },
        ),
        PopupMenuItem(
          child: const Row(children: [Icon(Icons.lock, color: Colors.white), SizedBox(width: 8), Text('Cambiar Contraseña', style: TextStyle(color: Colors.white))]),
          onTap: () {
            Future.delayed(Duration.zero, () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            });
          },
        ),
        PopupMenuItem(
          onTap: () {
            Future.delayed(Duration.zero, () {
              _cerrarSesion(context);
            });
          },
          child: const Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 8), Text('Cerrar Sesión', style: TextStyle(color: Colors.red))]),
        ),
      ],
    );
  }
}
