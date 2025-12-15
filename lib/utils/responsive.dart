import 'package:flutter/material.dart';

/// Utilidades simples para hacer layout responsivo sin repetir lógica.
class Responsive {
  static const double tabletBreakpoint = 720;
  static const double desktopBreakpoint = 1100;

  /// Número de columnas sugerido para grids.
  static int gridCount(
    double width, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    if (width >= desktopBreakpoint) return desktop;
    if (width >= tabletBreakpoint) return tablet;
    return mobile;
  }

  /// Padding horizontal escalable.
  static double pagePadding(double width) {
    if (width >= desktopBreakpoint) return 28;
    if (width >= tabletBreakpoint) return 20;
    return 16;
  }

  /// Limita el ancho máximo para centrar contenido en pantallas amplias.
  static BoxConstraints maxWidthConstraint({double maxWidth = 1200}) {
    return BoxConstraints(maxWidth: maxWidth);
  }
}

