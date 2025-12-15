using Microsoft.AspNetCore.Mvc;
using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using System.Text;

namespace Vaper_Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ComprobantesController : ControllerBase
    {
        private readonly Cloudinary _cloudinary;

        public ComprobantesController(Cloudinary cloudinary)
        {
            _cloudinary = cloudinary;
        }

        [HttpPost]
        public async Task<IActionResult> SubirComprobante([FromBody] ComprobanteRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.imagenBase64))
                {
                    return BadRequest(new { message = "La imagen es requerida" });
                }

                // Convertir base64 a bytes
                byte[] imageBytes = Convert.FromBase64String(request.imagenBase64);

                // Crear un stream desde los bytes
                using (var stream = new MemoryStream(imageBytes))
                {
                    // Configurar parámetros de carga
                    var uploadParams = new ImageUploadParams()
                    {
                        File = new FileDescription(request.nombreArchivo ?? "comprobante.jpg", stream),
                        Folder = "comprobantes", // Carpeta en Cloudinary
                        PublicId = $"comprobante_{Guid.NewGuid()}", // ID único
                        Overwrite = false
                        // ResourceType se establece automáticamente como Image, no se puede asignar
                    };

                    // Subir a Cloudinary
                    var uploadResult = await _cloudinary.UploadAsync(uploadParams);

                    if (uploadResult.StatusCode == System.Net.HttpStatusCode.OK)
                    {
                        return Ok(new { 
                            url = uploadResult.SecureUrl.ToString(),
                            publicId = uploadResult.PublicId
                        });
                    }
                    else
                    {
                        return StatusCode(500, new { message = "Error al subir la imagen a Cloudinary" });
                    }
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"Error: {ex.Message}" });
            }
        }
    }

    // Clase para recibir el request
    public class ComprobanteRequest
    {
        public string nombreArchivo { get; set; } = string.Empty;
        public string imagenBase64 { get; set; } = string.Empty;
    }
}




