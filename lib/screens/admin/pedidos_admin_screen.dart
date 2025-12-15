import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../widgets/pedido_card.dart';
import 'pedido_detalle_admin_screen.dart';
import 'crear_pedido_admin_screen.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import '../../utils/responsive.dart';

/// Pantalla de pedidos (Administrador)
class PedidosAdminScreen extends StatefulWidget {
  const PedidosAdminScreen({super.key});

  @override
  State<PedidosAdminScreen> createState() => _PedidosAdminScreenState();
}

class _PedidosAdminScreenState extends State<PedidosAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _filtroEstado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatos();
    });
    _searchController.addListener(_filtrarPedidos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final pedidoProvider = context.read<PedidoProvider>();
    await Future.wait([
      pedidoProvider.cargarPedidos(),
      pedidoProvider.cargarEstados(),
    ]);
  }

  void _filtrarPedidos() {
    setState(() {});
  }

  List<dynamic> _getPedidosFiltrados() {
    final pedidoProvider = context.read<PedidoProvider>();
    var pedidos = pedidoProvider.pedidos;

    // Filtrar por estado
    if (_filtroEstado != null && _filtroEstado!.isNotEmpty) {
      pedidos = pedidos
          .where((p) => p.estado?.nombre == _filtroEstado)
          .toList();
    }

    // Filtrar por búsqueda
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      pedidos = pedidos
          .where((p) =>
              (p.usuario?.nombre ?? '').toLowerCase().contains(query) ||
              (p.usuario?.email ?? '').toLowerCase().contains(query) ||
              p.id.toString().contains(query))
          .toList();
    }

    return pedidos;
  }

  void _verDetalle(int pedidoId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PedidoDetalleAdminScreen(pedidoId: pedidoId),
      ),
    );
  }

  Future<void> _crearPedidoManual() async {
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CrearPedidoAdminScreen(),
      ),
    );

    // Si se creó un pedido, recargar la lista
    if (resultado == true && mounted) {
      _cargarDatos();
    }
  }

  Future<void> _cerrarSesion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedidoProvider = context.watch<PedidoProvider>();
    final authProvider = context.watch<AuthProvider>();
    final pedidosFiltrados = _getPedidosFiltrados();
    final width = MediaQuery.of(context).size.width;
    final paddingValue = Responsive.pagePadding(width);
    final horizontalPadding = EdgeInsets.symmetric(horizontal: paddingValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Pedidos'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Mi Perfil'),
                  ],
                ),
                onTap: () {
                  final navigator = Navigator.of(context);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Mi Perfil'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nombre: ${authProvider.currentUser?.nombre}'),
                          Text('Email: ${authProvider.currentUser?.email}'),
                          Text('Rol: ${authProvider.currentUser?.rol}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => navigator.pop(),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.lock),
                    SizedBox(width: 8),
                    Text('Cambiar Contraseña'),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),
              PopupMenuItem(
                onTap: _cerrarSesion,
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              paddingValue,
              paddingValue,
              paddingValue,
              12,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente o número de pedido...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _filtroEstado,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por estado',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos los estados'),
                    ),
                    ...pedidoProvider.estados.map((estado) {
                      return DropdownMenuItem(
                        value: estado.nombre,
                        child: Text(estado.nombre),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filtroEstado = value;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: pedidoProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : pedidoProvider.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error: ${pedidoProvider.error}',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _cargarDatos,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarDatos,
                        child: pedidosFiltrados.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No hay pedidos',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: horizontalPadding,
                                itemCount: pedidosFiltrados.length,
                                itemBuilder: (context, index) {
                                  final pedido = pedidosFiltrados[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: PedidoCard(
                                      pedido: pedido,
                                      onTap: () => _verDetalle(pedido.id!),
                                      showCliente: true,
                                      allowEstadoChange: true,
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearPedidoManual,
        backgroundColor: const Color(0xFFFF9800),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Crear Pedido',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

