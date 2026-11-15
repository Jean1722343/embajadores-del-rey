import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Colores de la app: blanco de base, azul marino en bloques sólidos y oro
/// solo como acento. El escudo conserva su azul real original.
/// Todo es color plano: sin degradados ni brillos.
abstract final class Colores {
  /// Azul marino de los bloques, botones e iconos.
  static const azul = Color(0xFF12234F);

  /// Azul de las franjas sobre los bloques azules.
  static const azulFranja = Color(0xFF1B3068);

  /// Azul muy oscuro para el texto.
  static const tinta = Color(0xFF0B1634);

  static const blanco = Colors.white;

  /// Oro de los acentos: sello de presente, barras y avisos.
  static const oro = Color(0xFFF2B705);
  static const oroSuave = Color(0xFFFFF3C4);

  /// Acento para iconos y enlaces sobre blanco.
  static const acento = azul;

  /// Relleno claro para avatares y casillas, y filetes de las tarjetas.
  static const nube = Color(0xFFEDF0F7);
  static const borde = Color(0xFFD3D9E8);

  static const texto = tinta;

  /// Texto secundario: azul apagado en vez de gris.
  static const textoSuave = Color(0xFF51597A);
  static const textoApagado = Color(0xFF8F97B3);

  /// Texto secundario cuando el fondo es el bloque azul.
  static const sobreAzul = Color(0xFFCBD3EA);

  static const verde = Color(0xFF1B7F45);
  static const rojo = Color(0xFFC0392B);
  static const ambar = Color(0xFF9A5B00);
}

/// Familias incluidas en la app (assets/fuentes) para que carguen sin
/// internet: Bricolage para títulos y cifras, Figtree para el texto.
abstract final class Fuentes {
  static const titulos = 'Bricolage';
  static const texto = 'Figtree';
}

/// Estilo de título o cifra grande.
TextStyle titulo(double tamano, {Color color = Colores.tinta}) => TextStyle(
  fontFamily: Fuentes.titulos,
  fontSize: tamano,
  fontWeight: FontWeight.w800,
  height: 1.08,
  letterSpacing: -0.02 * tamano,
  color: color,
);

const _figtree700 = TextStyle(
  fontFamily: Fuentes.texto,
  fontSize: 16,
  fontWeight: FontWeight.w700,
);

ThemeData _tema({required bool sobreAzul}) {
  final fondo = sobreAzul ? Colores.azul : Colores.blanco;
  final tinta = sobreAzul ? Colores.blanco : Colores.tinta;
  final suave = sobreAzul ? Colores.sobreAzul : Colores.textoSuave;
  final filete = sobreAzul ? const Color(0x66FFFFFF) : Colores.borde;
  // Sobre blanco manda el azul; sobre azul, el oro.
  final fuerte = sobreAzul ? Colores.oro : Colores.azul;
  final sobreFuerte = sobreAzul ? Colores.tinta : Colores.blanco;

  final esquema = ColorScheme.fromSeed(
    seedColor: Colores.azul,
    brightness: sobreAzul ? Brightness.dark : Brightness.light,
    primary: fuerte,
    onPrimary: sobreFuerte,
    secondary: Colores.oro,
    onSecondary: Colores.tinta,
    surface: fondo,
    onSurface: tinta,
    onSurfaceVariant: suave,
    outline: filete,
    outlineVariant: filete,
    error: Colores.rojo,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: Fuentes.texto,
  );
  // Material separa las letras del texto de cuerpo; Figtree se lee mejor
  // con su espaciado natural.
  final texto = base.textTheme.apply(
    bodyColor: tinta,
    displayColor: tinta,
    letterSpacingFactor: 0,
  );
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return base.copyWith(
    scaffoldBackgroundColor: fondo,
    canvasColor: fondo,
    textTheme: texto.copyWith(
      headlineMedium: titulo(30, color: tinta),
      headlineSmall: titulo(25, color: tinta),
      titleLarge: titulo(21, color: tinta),
      bodyLarge: texto.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
      bodyMedium: texto.bodyMedium?.copyWith(fontSize: 14.5, height: 1.4),
      bodySmall: texto.bodySmall?.copyWith(color: suave),
    ),
    iconTheme: IconThemeData(color: sobreAzul ? Colores.blanco : Colores.azul),
    appBarTheme: AppBarTheme(
      backgroundColor: Colores.azul,
      foregroundColor: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colores.blanco),
      actionsIconTheme: const IconThemeData(color: Colores.blanco),
      titleTextStyle: titulo(22, color: Colores.blanco),
    ),
    cardTheme: CardThemeData(
      color: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colores.borde, width: 1.5),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colores.azul,
      textColor: Colores.tinta,
      subtitleTextStyle: TextStyle(
        fontFamily: Fuentes.texto,
        fontSize: 13.5,
        color: Colores.textoSuave,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: fuerte,
        foregroundColor: sobreFuerte,
        disabledBackgroundColor: sobreAzul
            ? const Color(0x33FFFFFF)
            : Colores.nube,
        disabledForegroundColor: sobreAzul
            ? const Color(0x99FFFFFF)
            : Colores.textoApagado,
        minimumSize: const Size.fromHeight(56),
        shape: forma,
        textStyle: _figtree700,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: sobreAzul ? Colores.blanco : Colores.azul,
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(
          color: sobreAzul ? const Color(0x99FFFFFF) : Colores.azul,
          width: 1.5,
        ),
        shape: forma,
        textStyle: _figtree700,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: sobreAzul ? Colores.oro : Colores.azul,
        textStyle: _figtree700.copyWith(fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colores.blanco,
      labelStyle: const TextStyle(color: Colores.textoSuave),
      floatingLabelStyle: const TextStyle(color: Colores.azul),
      hintStyle: const TextStyle(color: Colores.textoApagado),
      helperStyle: const TextStyle(color: Colores.textoSuave),
      prefixIconColor: Colores.textoSuave,
      suffixIconColor: Colores.azul,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colores.borde, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colores.azul, width: 2),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colores.azul,
      selectionColor: Color(0x66F2B705),
      selectionHandleColor: Colores.oro,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colores.blanco,
      selectedColor: Colores.azul,
      disabledColor: Colores.nube,
      checkmarkColor: Colores.blanco,
      side: const BorderSide(color: Colores.borde, width: 1.5),
      shape: const StadiumBorder(),
      // El color depende del estado: blanco cuando el chip está elegido
      // (fondo azul) y oscuro cuando no.
      labelStyle: TextStyle(
        fontFamily: Fuentes.texto,
        fontWeight: FontWeight.w600,
        color: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? Colores.blanco
              : estados.contains(WidgetState.disabled)
              ? Colores.textoApagado
              : Colores.tinta,
        ),
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: Fuentes.texto,
        fontWeight: FontWeight.w700,
        color: Colores.blanco,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: Colores.textoSuave, width: 1.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colores.oro,
      foregroundColor: Colores.tinta,
      elevation: 2,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      extendedTextStyle: _figtree700.copyWith(fontSize: 15),
    ),
    dividerTheme: const DividerThemeData(color: Colores.borde, space: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colores.borde),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colores.tinta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: _figtree700.copyWith(
        fontSize: 14.5,
        color: Colores.blanco,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: titulo(22),
      contentTextStyle: const TextStyle(
        fontFamily: Fuentes.texto,
        fontSize: 15,
        height: 1.4,
        color: Colores.textoSuave,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: Colores.blanco,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: fuerte),
  );
}

/// Tema general: fondo blanco, azul real y oro.
final temaBase = _tema(sobreAzul: false);

/// Tema para lo que va encima de un bloque azul: texto blanco, botón
/// principal en oro.
final temaSobreAzul = _tema(sobreAzul: true);

ThemeData temaEmbajadores() => temaBase;

/// Color del semáforo según el porcentaje de asistencia.
Color colorPorcentaje(double? p) {
  if (p == null) return Colores.textoSuave;
  if (p >= 75) return Colores.verde;
  if (p >= 50) return Colores.ambar;
  return Colores.rojo;
}
