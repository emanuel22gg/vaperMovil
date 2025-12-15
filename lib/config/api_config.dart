/// Configuración de la API
class ApiConfig {
  static const String baseUrl = 'http://vaperapi.somee.com';

  // Endpoints de Usuarios/Auth
  static const String usuariosEndpoint = '/api/Usuarios';

  // Endpoints de Categorías
  static const String categoriasEndpoint = '/api/CategoriaProductoes';

  // Endpoints de Productos
  static const String productosEndpoint = '/api/Productoes';

  // Endpoints de Pedidos
  static const String pedidosEndpoint = '/api/VentaPedidos';
  static const String detallePedidosEndpoint = '/api/DetalleVentaPedidoes';

  // Endpoints de Estados
  static const String estadosEndpoint = '/api/Estadoes';

  // Endpoints de Imágenes
  static const String imagenesEndpoint = '/api/Imagenes';

  // Endpoints de Ubicación
  static const String departamentosEndpoint = '/api/Departamentos';
  static const String ciudadesEndpoint = '/api/Ciudades';

  // Configuración de WhatsApp
  static const String whatsappNumero = '573052359631'; // Número de WhatsApp de la empresa
  static const String whatsappMensaje = 'Hola, adjunto el comprobante de pago de mi pedido.';
}

