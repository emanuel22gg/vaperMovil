import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import 'api_service.dart';

/// Servicio para manejar imágenes y comprobantes
class ImagenService {
  static final ImagePicker _picker = ImagePicker();

  /// Seleccionar imagen desde galería o cámara
  static Future<XFile?> seleccionarImagen({bool desdeCamara = false}) async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: desdeCamara ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      return imagen;
    } catch (e) {
      debugPrint('❌ ImagenService: Error al seleccionar imagen: $e');
      return null;
    }
  }

  /// Seleccionar archivo (para web)
  static Future<FilePickerResult?> seleccionarArchivo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      return result;
    } catch (e) {
      debugPrint('❌ ImagenService: Error al seleccionar archivo: $e');
      return null;
    }
  }

  /// Convertir PlatformFile a base64 (para web)
  static Future<String?> archivoABase64(PlatformFile archivo) async {
    try {
      if (archivo.bytes != null) {
        return base64Encode(archivo.bytes!);
      }
      return null;
    } catch (e) {
      debugPrint('❌ ImagenService: Error al convertir archivo a base64: $e');
      return null;
    }
  }

  /// Convertir imagen a base64 (para enviar a la API)
  static Future<String?> imagenABase64(String rutaImagen) async {
    try {
      final file = File(rutaImagen);
      if (!await file.exists()) {
        debugPrint('❌ ImagenService: El archivo no existe: $rutaImagen');
        return null;
      }
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('❌ ImagenService: Error al convertir imagen a base64: $e');
      return null;
    }
  }

  /// Subir comprobante a la API
  /// Acepta ruta de archivo (móvil) o nombre de archivo (web)
  static Future<String?> subirComprobante(String rutaOArchivo) async {
    try {
      String? base64Image;
      String fileName;

      // Intentar convertir desde ruta de archivo (móvil)
      try {
        base64Image = await imagenABase64(rutaOArchivo);
        fileName = rutaOArchivo.split('/').last;
      } catch (e) {
        // Si falla, asumimos que es un nombre de archivo de web
        // En este caso, el archivo debe ser manejado de otra manera
        debugPrint('⚠️ ImagenService: No se pudo leer como archivo, puede ser web');
        return null;
      }

      if (base64Image == null) {
        throw Exception('No se pudo convertir la imagen a base64');
      }

      // Enviar a la API
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/Comprobantes'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nombreArchivo': fileName,
          'imagenBase64': base64Image,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return responseData['url'] as String?;
      } else {
        debugPrint('❌ ImagenService: Error ${response.statusCode}: ${response.body}');
        throw Exception('Error al subir comprobante: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ ImagenService: Error al subir comprobante: $e');
      return null;
    }
  }

  /// Subir comprobante desde PlatformFile (para web)
  static Future<String?> subirComprobanteWeb(PlatformFile archivo) async {
    try {
      final base64Image = await archivoABase64(archivo);
      if (base64Image == null) {
        throw Exception('No se pudo convertir el archivo a base64');
      }

      final fileName = archivo.name;

      // Enviar a la API
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/Comprobantes'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nombreArchivo': fileName,
          'imagenBase64': base64Image,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return responseData['url'] as String?;
      } else {
        debugPrint('❌ ImagenService: Error ${response.statusCode}: ${response.body}');
        throw Exception('Error al subir comprobante: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ ImagenService: Error al subir comprobante web: $e');
      return null;
    }
  }
}

