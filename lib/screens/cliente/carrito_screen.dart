import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/carrito_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../models/detalle_pedido_model.dart';
import '../../models/venta_pedido_model.dart';
import '../../models/departamento_model.dart';
import '../../models/ciudad_model.dart';
import '../../services/producto_service.dart';
import '../../services/ubicacion_service.dart';
import '../../services/imagen_service.dart';
import '../../config/api_config.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/carrito_item_card.dart';
import '../../utils/responsive.dart';
import 'package:image_picker/image_picker.dart';

/// Pantalla del carrito de compras
class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _observacionesController = TextEditingController();
  bool _isEnviando = false;
  
  // Para los dropdowns de ubicación
  List<Departamento> _departamentos = [];
  List<Ciudad> _ciudades = [];
  Departamento? _departamentoSeleccionado;
  Ciudad? _ciudadSeleccionada;
  bool _isCargandoDepartamentos = false;
  bool _isCargandoCiudades = false;

  XFile? _comprobanteSeleccionado;

  @override
  void dispose() {
    _direccionController.dispose();
    _telefonoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  /// Cargar departamentos
  Future<void> _cargarDepartamentos() async {
    setState(() {
      _isCargandoDepartamentos = true;
    });

    try {
      final departamentos = await UbicacionService.getDepartamentos();
      setState(() {
        _departamentos = departamentos;
        _isCargandoDepartamentos = false;
      });
    } catch (e) {
      debugPrint('❌ Carrito: Error al cargar departamentos: $e');
      setState(() {
        _isCargandoDepartamentos = false;
      });
    }
  }

  /// Cargar ciudades cuando se selecciona un departamento
  Future<void> _cargarCiudades(int departamentoId) async {
    setState(() {
      _isCargandoCiudades = true;
      _ciudadSeleccionada = null; // Limpiar ciudad seleccionada
    });

    try {
      final ciudades = await UbicacionService.getCiudadesPorDepartamento(departamentoId);
      setState(() {
        _ciudades = ciudades;
        _isCargandoCiudades = false;
      });
    } catch (e) {
      debugPrint('❌ Carrito: Error al cargar ciudades: $e');
      setState(() {
        _isCargandoCiudades = false;
      });
    }
  }

  Future<String?> _seleccionarTipoEntrega() async {
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Método de Entrega',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Cómo prefieres recibir tus productos?',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _OptionTile(
              icon: Icons.store_rounded,
              title: 'Recoger en Punto Físico',
              subtitle: 'Retira tu pedido en nuestra tienda',
              color: Colors.blue,
              onTap: () => Navigator.of(context).pop('recoger'),
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.local_shipping_rounded,
              title: 'Envío a Domicilio',
              subtitle: 'Recibe tu pedido en tu dirección',
              color: Colors.green,
              onTap: () => Navigator.of(context).pop('domicilio'),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<String?> _seleccionarMetodoPago() async {
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Método de Pago',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona cómo deseas realizar el pago',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _OptionTile(
              icon: Icons.payments_rounded,
              title: 'Efectivo (Contraentrega)',
              subtitle: 'Paga cuando recibas tu pedido',
              color: Colors.green,
              onTap: () => Navigator.of(context).pop('efectivo'),
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.account_balance_rounded,
              title: 'Transferencia Bancaria',
              subtitle: 'Adjunta el comprobante vía WhatsApp',
              color: Colors.blue,
              onTap: () => Navigator.of(context).pop('transferencia'),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Abrir WhatsApp para enviar comprobante
  Future<void> _abrirWhatsApp() async {
    try {
      final carritoProvider = context.read<CarritoProvider>();
      final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
      
      final sb = StringBuffer();
      sb.writeln('*NUEVO PEDIDO (TRANSFERENCIA)*');
      sb.writeln('');
      sb.writeln('Hola, deseo confirmar mi pedido con los siguientes productos:');
      sb.writeln('');
      
      for (final item in carritoProvider.items) {
        sb.writeln('- ${item.producto.nombre} x${item.cantidad}');
        sb.writeln('  ${currencyFormat.format(item.subtotal)}');
      }
      
      sb.writeln('');
      sb.writeln('*TOTAL A PAGAR: ${currencyFormat.format(carritoProvider.precioTotal)}*');
      sb.writeln('');
      sb.writeln('Adjunto mi comprobante de pago:');

      final numero = ApiConfig.whatsappNumero;
      final mensaje = Uri.encodeComponent(sb.toString());
      final url = 'https://wa.me/$numero?text=$mensaje';
      
      final uri = Uri.parse(url);
      final waUri = Uri.parse('whatsapp://send?phone=$numero&text=$mensaje');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp no está instalado o no se puede abrir'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, String>?> _mostrarDialogoDomicilio(String metodoPago) async {
    _direccionController.clear();
    _telefonoController.clear();
    _observacionesController.clear();
    _departamentoSeleccionado = null;
    _ciudadSeleccionada = null;
    _ciudades = [];
    _comprobanteSeleccionado = null;

    await _cargarDepartamentos();

    if (!mounted) return null;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardHeight),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Datos de Entrega',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle(context, 'Información del Receptor'),
                  _buildPremiumTextField(
                    context: context,
                    controller: _direccionController,
                    label: 'Dirección de entrega *',
                    icon: Icons.home_rounded,
                    hint: 'Ej: Calle 123 #45-67',
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumTextField(
                    context: context,
                    controller: _telefonoController,
                    label: 'Teléfono de contacto *',
                    icon: Icons.phone_android_rounded,
                    hint: 'Tu número de celular',
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Ubicación'),
                  _isCargandoDepartamentos
                      ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      : _buildPremiumDropdown<Departamento>(
                          context: context,
                          label: 'Departamento *',
                          icon: Icons.map_rounded,
                          value: _departamentoSeleccionado,
                          items: _departamentos.map((d) => 
                            DropdownMenuItem(value: d, child: Text(d.nombre))
                          ).toList(),
                          onChanged: (d) async {
                            setDialogState(() {
                              _departamentoSeleccionado = d;
                              _ciudadSeleccionada = null;
                            });
                            if (d != null && d.id != null) {
                              await _cargarCiudades(d.id!);
                              setDialogState(() {});
                            }
                          },
                        ),
                  const SizedBox(height: 16),
                  _departamentoSeleccionado == null
                      ? _buildDisabledDropdown(context, 'Ciudad *', Icons.location_city_rounded, 'Selecciona un dpto. primero')
                      : _isCargandoCiudades
                          ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                          : _buildPremiumDropdown<Ciudad>(
                              context: context,
                              label: 'Ciudad *',
                              icon: Icons.location_city_rounded,
                              value: _ciudadSeleccionada,
                              items: _ciudades.map((c) => 
                                DropdownMenuItem(value: c, child: Text(c.nombre))
                              ).toList(),
                              onChanged: (c) {
                                setDialogState(() => _ciudadSeleccionada = c);
                              },
                            ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Detalles Adicionales'),
                  _buildPremiumTextField(
                    context: context,
                    controller: _observacionesController,
                    label: 'Observaciones (opcional)',
                    icon: Icons.notes_rounded,
                    hint: 'Indicaciones para el repartidor...',
                    maxLines: 2,
                  ),
                  
                  if (metodoPago == 'transferencia') ...[
                    const SizedBox(height: 24),
                    _buildTransferenciaInfo(context),
                  ],
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_validarCampos(context, metodoPago)) {
                          Navigator.of(context).pop({
                            'direccion': _direccionController.text.trim(),
                            'telefono': _telefonoController.text.trim(),
                            'ciudad': _ciudadSeleccionada!.nombre,
                            'departamento': _departamentoSeleccionado!.nombre,
                            'observaciones': _observacionesController.text.trim(),
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Confirmar Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return result;
  }

  bool _validarCampos(BuildContext context, String metodoPago) {
    if (_direccionController.text.trim().isEmpty) {
      _showSnackBar(context, 'La dirección es obligatoria');
      return false;
    }
    if (_telefonoController.text.trim().isEmpty) {
      _showSnackBar(context, 'El teléfono es obligatorio');
      return false;
    }
    if (_departamentoSeleccionado == null) {
      _showSnackBar(context, 'Selecciona un departamento');
      return false;
    }
    if (_ciudadSeleccionada == null) {
      _showSnackBar(context, 'Selecciona una ciudad');
      return false;
    }
    if (metodoPago == 'transferencia' && _comprobanteSeleccionado == null) {
      _showSnackBar(context, 'Debes adjuntar el comprobante de transferencia');
      return false;
    }
    return true;
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPremiumTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildPremiumDropdown<T>({
    required BuildContext context,
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildDisabledDropdown(BuildContext context, String label, IconData icon, String hint) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade100)),
      ),
      items: const [],
      onChanged: null,
      hint: Text(hint, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildTransferenciaInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text('Pago por Transferencia', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Por favor, adjunta el comprobante de tu transferencia para poder procesar tu pedido.',
            style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
          ),
          const SizedBox(height: 16),
          if (_comprobanteSeleccionado != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _comprobanteSeleccionado!.name,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () {
                      if (context.mounted) {
                        (context as Element).markNeedsBuild();
                      }
                      _comprobanteSeleccionado = null;
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final imagen = await ImagenService.seleccionarImagen();
                if (imagen != null) {
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                  }
                  _comprobanteSeleccionado = imagen;
                }
              },
              icon: Icon(_comprobanteSeleccionado == null ? Icons.upload_file : Icons.edit, color: Colors.white, size: 20),
              label: Text(_comprobanteSeleccionado == null ? 'Seleccionar Comprobante' : 'Cambiar Imagen', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarPedido() async {
    debugPrint('🚀🚀🚀 CARrito: MÉTODO _enviarPedido EJECUTADO 🚀🚀🚀');
    debugPrint('🚀 Carrito: Iniciando proceso de envío de pedido...');
    
    final carritoProvider = context.read<CarritoProvider>();
    final authProvider = context.read<AuthProvider>();
    final pedidoProvider = context.read<PedidoProvider>();

    debugPrint('🔵 Carrito: Carrito vacío: ${carritoProvider.isEmpty}');
    debugPrint('🔵 Carrito: Usuario ID: ${authProvider.currentUser?.id}');
    debugPrint('🔵 Carrito: Total: ${carritoProvider.precioTotal}');

    if (carritoProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (authProvider.currentUser?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario no autenticado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Paso 1: Seleccionar tipo de entrega
    debugPrint('🔵 Carrito: Mostrando diálogo de tipo de entrega...');
    final tipoEntrega = await _seleccionarTipoEntrega();
    debugPrint('🔵 Carrito: Tipo de entrega seleccionado: $tipoEntrega');
    if (tipoEntrega == null) {
      debugPrint('⚠️ Carrito: Usuario canceló selección de tipo de entrega');
      return;
    }

    String? metodoPago;
    Map<String, String>? datosEntrega;

    // Paso 2: Si es envío a domicilio, seleccionar método de pago
    if (tipoEntrega == 'domicilio') {
      debugPrint('🔵 Carrito: Mostrando diálogo de método de pago...');
      metodoPago = await _seleccionarMetodoPago();
      debugPrint('🔵 Carrito: Método de pago seleccionado: $metodoPago');
      if (metodoPago == null) {
        debugPrint('⚠️ Carrito: Usuario canceló selección de método de pago');
        return;
      }

      // Paso 3: Mostrar diálogo para datos de entrega
      debugPrint('🔵 Carrito: Mostrando diálogo de datos de entrega...');
      datosEntrega = await _mostrarDialogoDomicilio(metodoPago);
      debugPrint('🔵 Carrito: Datos de entrega: $datosEntrega');
      if (datosEntrega == null) {
        debugPrint('⚠️ Carrito: Usuario canceló diálogo de datos de entrega');
        return;
      }
    } else if (tipoEntrega == 'recoger') {
      // Para recoger en punto físico, no necesitamos método de pago ni datos de entrega
      debugPrint('🔵 Carrito: Tipo de entrega: Recoger en punto físico');
      metodoPago = null;
      datosEntrega = null;
    }

    setState(() {
      _isEnviando = true;
    });

    try {
      // Validar que el usuario esté autenticado
      if (authProvider.currentUser == null || authProvider.currentUser!.id == null) {
        throw Exception('Usuario no autenticado. Por favor, inicia sesión nuevamente.');
      }

      // Crear pedido según el formato que espera la API
      final ahora = DateTime.now();
      final subtotal = carritoProvider.precioTotal;
      final envio = tipoEntrega == 'domicilio' ? 5000.0 : 0.0; // Costo de envío si aplica
      final total = subtotal + envio;
      
      // Asegurar que fechaEntrega siempre tenga un valor (usar fechaCreacion si no hay)
      final fechaEntregaFinal = tipoEntrega == 'domicilio' 
          ? ahora.add(const Duration(days: 3)) 
          : ahora; // Si es recoger, usar la misma fecha
      
      // Asegurar que los estados estén cargados
      if (pedidoProvider.estados.isEmpty) {
        debugPrint('🔵 Carrito: Cargando estados antes de enviar pedido...');
        await pedidoProvider.cargarEstados();
      }

      // Obtener el ID del estado "Pendiente"
      final estadoPendienteId = pedidoProvider.obtenerEstadoPendienteId();
      if (estadoPendienteId == null) {
        throw Exception('No se pudo obtener el estado "Pendiente". Por favor, intenta nuevamente.');
      }

      debugPrint('🔵 Carrito: Validaciones previas:');
      debugPrint('  - UsuarioId: ${authProvider.currentUser!.id}');
      debugPrint('  - EstadoId: $estadoPendienteId (Pendiente)');
      debugPrint('  - Subtotal: $subtotal');
      debugPrint('  - Envío: $envio');
      debugPrint('  - Total: $total');
      debugPrint('  - Tipo entrega: $tipoEntrega');
      debugPrint('  - Método pago: $metodoPago');
      
      var pedido = VentaPedido(
        usuarioId: authProvider.currentUser!.id,
        estadoId: estadoPendienteId, // Pendiente
        fechaCreacion: ahora,
        fechaEntrega: fechaEntregaFinal,
        subtotal: subtotal,
        envio: envio,
        total: total,
        direccionEntrega: tipoEntrega == 'domicilio' && datosEntrega != null
            ? datosEntrega['direccion']
            : null,
        ciudadEntrega: tipoEntrega == 'domicilio' && datosEntrega != null
            ? datosEntrega['ciudad']
            : null,
        departamentoEntrega: tipoEntrega == 'domicilio' && datosEntrega != null
            ? datosEntrega['departamento']
            : null,
        metodoPago: metodoPago, // Puede ser null si es "recoger"
        // Campos adicionales para uso interno (no se envían a la API)
        tipoEntrega: tipoEntrega,
        telefonoContacto: tipoEntrega == 'domicilio' && datosEntrega != null
            ? datosEntrega['telefono']
            : authProvider.currentUser?.telefono,
        observaciones: tipoEntrega == 'domicilio' && datosEntrega != null && datosEntrega['observaciones']!.isNotEmpty
            ? datosEntrega['observaciones']
            : null,
        comprobanteUrl: null, // Se asignará si sube imagen
      );

      // Si es transferencia y hay un comprobante seleccionado, subirlo
      if (metodoPago == 'transferencia' && _comprobanteSeleccionado != null) {
        debugPrint('🔵 Carrito: Subiendo comprobante de transferencia...');
        final urlImagen = await ImagenService.subirImagenMultipart(_comprobanteSeleccionado!.path);
        
        if (urlImagen != null && urlImagen.isNotEmpty) {
          debugPrint('✅ Carrito: Comprobante subido, url: $urlImagen');
          pedido = pedido.copyWith(comprobanteUrl: urlImagen);
        } else {
          throw Exception('No se pudo subir el comprobante. Por favor intenta de nuevo.');
        }
      }

      // Crear detalles
      final detalles = carritoProvider.items.map((item) {
        return DetallePedido(
          productoId: item.producto.id,
          cantidad: item.cantidad,
          precioUnitario: item.producto.precio,
          subtotal: item.subtotal,
        );
      }).toList();

      debugPrint('🔵 Carrito: Creando pedido...');
      debugPrint('🔵 Carrito: Pedido JSON: ${pedido.toJson()}');
      debugPrint('🔵 Carrito: Detalles: ${detalles.length} items');
      
      final nuevoPedido = await pedidoProvider.crearPedido(pedido, detalles);

      debugPrint('🔵 Carrito: Pedido creado: ${nuevoPedido?.id}');
      debugPrint('🔵 Carrito: Error del provider: ${pedidoProvider.error}');
      debugPrint('🔵 Carrito: IsLoading: ${pedidoProvider.isLoading}');

      // Verificar si hay error
      if (pedidoProvider.error != null) {
        debugPrint('❌ Carrito: Error del provider: ${pedidoProvider.error}');
        if (mounted) {
          throw Exception(pedidoProvider.error);
        }
        return;
      }

      // Verificar si el pedido se creó
      if (nuevoPedido == null) {
        debugPrint('❌ Carrito: nuevoPedido es null');
        if (mounted) {
          throw Exception('No se pudo crear el pedido. ${pedidoProvider.error ?? "Error desconocido"}');
        }
        return;
      }

      // Si llegamos aquí, el pedido se creó exitosamente
      debugPrint('✅ Carrito: Pedido creado exitosamente con ID: ${nuevoPedido.id}');
      
      if (mounted) {
        carritoProvider.limpiarCarrito();
        _direccionController.clear();
        _telefonoController.clear();
        _observacionesController.clear();
        _departamentoSeleccionado = null;
        _ciudadSeleccionada = null;
        _ciudades = [];

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido enviado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Esperar un poco antes de cerrar para que el usuario vea el mensaje
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Carrito: Error al enviar pedido: $e');
      debugPrint('❌ Carrito: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar pedido: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEnviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carritoProvider = context.watch<CarritoProvider>();
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final width = MediaQuery.of(context).size.width;
    final paddingValue = Responsive.pagePadding(width);
    final horizontalPadding = EdgeInsets.symmetric(horizontal: paddingValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito de Compras'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: carritoProvider.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: Responsive.iconSize(context, 64),
                    color: Colors.grey,
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 16)),
                  Text(
                    'Tu carrito está vacío',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 20),
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 8)),
                  Text(
                    'Agrega productos para comenzar a comprar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: Responsive.maxWidthConstraint(),
                          child: ListView.builder(
                            padding: horizontalPadding.add(
                              EdgeInsets.only(
                                top: Responsive.scaleHeight(context, 20),
                                bottom: Responsive.scaleHeight(context, 140), // Espacio para la barra inferior
                              ),
                            ),
                            itemCount: carritoProvider.items.length,
                            itemBuilder: (context, index) {
                              final item = carritoProvider.items[index];
                              return CarritoItemCard(
                                item: item,
                                onIncrement: () {
                                  try {
                                    carritoProvider.actualizarCantidad(
                                      item.producto.id!,
                                      item.cantidad + 1,
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                onDecrement: () {
                                  if (item.cantidad > 1) {
                                    carritoProvider.actualizarCantidad(
                                      item.producto.id!,
                                      item.cantidad - 1,
                                    );
                                  } else {
                                    carritoProvider.eliminarProducto(
                                      item.producto.id!,
                                    );
                                  }
                                },
                                onDelete: () {
                                  carritoProvider.eliminarProducto(
                                    item.producto.id!,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Barra de Checkout Premium (Fixed positioned)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      paddingValue,
                      Responsive.scaleHeight(context, 24),
                      paddingValue,
                      paddingValue + MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: Responsive.maxWidthConstraint(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subtotal:',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 14),
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      '${carritoProvider.cantidadTotal} productos',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 12),
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  currencyFormat.format(carritoProvider.precioTotal),
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 26),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.scaleHeight(context, 24)),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isEnviando ? null : _enviarPedido,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: Responsive.scaleHeight(context, 16),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isEnviando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Continuar con el pedido',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(context, 16),
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          SizedBox(width: Responsive.scaleWidth(context, 8)),
                                          const Icon(Icons.arrow_forward_rounded, size: 20),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

