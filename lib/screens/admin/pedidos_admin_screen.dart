import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../widgets/pedido_card.dart';
import '../../models/venta_pedido_model.dart';

import 'pedido_detalle_admin_screen.dart';
import 'crear_pedido_admin_screen.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import '../../utils/responsive.dart';

class PedidosAdminScreen extends StatefulWidget {
  const PedidosAdminScreen({super.key});

  @override
  State<PedidosAdminScreen> createState() => _PedidosAdminScreenState();
}

class _PedidosAdminScreenState extends State<PedidosAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filtroEstado = 'TODOS';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarDatos();
    });
    _searchController.addListener(_filtrarPedidos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final pedidoProvider = context.read<PedidoProvider>();
      
      // Cargamos uno después del otro para no saturar el servidor de Somee (que es limitado)
      // y evitar el error de "Semaphore timeout" en Windows
      await pedidoProvider.cargarPedidos();
      await pedidoProvider.cargarEstados();
    } catch (e) {
      debugPrint('Error cargando datos: $e');
    }
  }

  void _filtrarPedidos() {
    setState(() {});
  }

  List<VentaPedido> _getPedidosFiltrados() {
    final pedidoProvider = context.read<PedidoProvider>();
    var pedidos = pedidoProvider.pedidos.toList();

    if (_filtroEstado != 'TODOS') {
      pedidos = pedidos.where((p) {
        String nombreEstado = '';
        if (p.estado?.nombre != null) {
          nombreEstado = p.estado!.nombre;
        } else if (p.estadoId != null) {
          try {
            final estado = pedidoProvider.estados
                .firstWhere((e) => e.id == p.estadoId);
            nombreEstado = estado.nombre;
          } catch (_) {}
        }
        return nombreEstado == _filtroEstado;
      }).toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      pedidos = pedidos.where((p) =>
          (p.usuario?.nombre ?? '').toLowerCase().contains(query) ||
          (p.usuario?.email ?? '').toLowerCase().contains(query) ||
          p.id.toString().contains(query)).toList();
    }

    pedidos.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return pedidos;
  }

  void _verDetalle(int pedidoId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PedidoDetalleAdminScreen(pedidoId: pedidoId),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedidoProvider = context.watch<PedidoProvider>();
    final pedidosFiltrados = _getPedidosFiltrados();
    final width = MediaQuery.of(context).size.width;
    final paddingValue = Responsive.pagePadding(width);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Gestión de Pedidos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 22),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: Colors.black87, size: 20),
            ),
            onPressed: _cerrarSesion,
          ),
          PopupMenuButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert, color: Colors.black87, size: 20),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.password, size: 20),
                    SizedBox(width: 10),
                    Text('Cambiar Contraseña'),
                  ],
                ),
                onTap: () {
                  Future.delayed(Duration.zero, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter and Search Section
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: paddingValue,
              right: paddingValue,
              bottom: 16,
              top: 8,
            ),
            child: Column(
              children: [
                // Modern Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por folio, cliente o email...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 16),
                // Stylized Dropdown Filter
                DropdownButtonFormField<String>(
                  value: _filtroEstado,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Estado',
                    labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  dropdownColor: Colors.white,
                  items: [
                    const DropdownMenuItem(
                      value: 'TODOS',
                      child: Text('Todos los Estados'),
                    ),
                    ...pedidoProvider.estados
                        .where((e) {
                          final name = e.nombre.toLowerCase().trim();
                          return name == 'pendiente' || 
                                 name == 'entregado' || 
                                 name == 'anulada' || 
                                 name == 'anulado' || 
                                 name == 'cancelado';
                        })
                        .map((e) {
                          String label = e.nombre;
                          final name = e.nombre.toLowerCase().trim();
                          if (name == 'anulada' || name == 'anulado') label = 'Cancelado';
                          
                          return DropdownMenuItem(
                            value: e.nombre,
                            child: Text(label),
                          );
                        }),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _filtroEstado = v);
                  },
                ),
              ],
            ),
          ),
          // Orders Count Summary
          Padding(
            padding: EdgeInsets.symmetric(horizontal: paddingValue, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${pedidosFiltrados.length} pedidos encontrados',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: pedidoProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cargarDatos,
                    color: Colors.black,
                    child: pedidosFiltrados.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: paddingValue,
                              vertical: 8,
                            ),
                            itemCount: pedidosFiltrados.length,
                            itemBuilder: (context, index) {
                              final pedido = pedidosFiltrados[index];
                              return PedidoCard(
                                pedido: pedido,
                                onTap: () => _verDetalle(pedido.id!),
                                showCliente: true,
                                allowEstadoChange: true,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CrearPedidoAdminScreen(),
            ),
          );
          if (res == true) _cargarDatos();
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        label: const Text('NUEVO PEDIDO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        icon: const Icon(Icons.add),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay pedidos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? 'Aún no se han registrado pedidos en el sistema.'
                  : 'No encontramos pedidos que coincidan con tu búsqueda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
