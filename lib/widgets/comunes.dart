import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/grados.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/repo.dart';
import 'movimiento.dart';

final _fechaLarga = DateFormat("EEEE d 'de' MMMM", 'es');
final _fechaCorta = DateFormat('d MMM yyyy', 'es');

String fechaLarga(DateTime d) {
  final s = _fechaLarga.format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String fechaCorta(DateTime d) => _fechaCorta.format(d);

/// Como [fechaLarga], pero con el año cuando no es el actual: una foto de
/// una actividad de hace años no debe confundirse con una de este.
String fechaLargaConAnio(DateTime d) => d.year == DateTime.now().year
    ? fechaLarga(d)
    : '${fechaLarga(d)} de ${d.year}';

final _pesos = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
final _pesosCerrados = NumberFormat.currency(
  locale: 'es_MX',
  symbol: r'$',
  decimalDigits: 0,
);

/// Cantidad en pesos: «$1,250» o «$12.50» si lleva centavos.
String dinero(num cantidad) => cantidad == cantidad.roundToDouble()
    ? _pesosCerrados.format(cantidad)
    : _pesos.format(cantidad);

/// Convierte cualquier error en una frase que el usuario entienda.
String mensajeDeError(Object e) {
  if (e is ErrorDeUso) return e.mensaje;
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'El correo o la contraseña no coinciden.';
      case 'email-already-in-use':
        return 'Ya hay una cuenta con ese correo. Inicia sesión.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'Ese correo no es válido.';
      case 'network-request-failed':
        return 'No hay conexión a internet.';
      case 'web-context-canceled':
      case 'canceled':
        return 'Se canceló el inicio de sesión.';
    }
    return e.message ?? 'No se pudo iniciar sesión.';
  }
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'No tienes permiso para hacer esto.';
      case 'unavailable':
        return 'No hay conexión. Inténtalo de nuevo cuando tengas señal.';
    }
    return e.message ?? 'Ocurrió un error.';
  }
  return 'Ocurrió un error. Inténtalo de nuevo.';
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Ejecuta una acción y muestra el error si falla. Devuelve si salió bien.
Future<bool> intentar(
  BuildContext context,
  Future<void> Function() accion,
) async {
  try {
    await accion();
    return true;
  } catch (e) {
    if (context.mounted) avisar(context, mensajeDeError(e));
    return false;
  }
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String aceptar = 'Aceptar',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(aceptar),
        ),
      ],
    ),
  );
  return r == true;
}

Future<T?> abrir<T>(BuildContext context, Widget pantalla) =>
    Navigator.of(context).push<T>(RutaEmbajadores<T>(pantalla));

class Cargando extends StatelessWidget {
  const Cargando({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Mensaje para pantallas sin datos, con una acción opcional.
class Vacio extends StatelessWidget {
  const Vacio({
    super.key,
    required this.icono,
    required this.texto,
    this.boton,
    this.alTocar,
  });

  final IconData icono;
  final String texto;
  final String? boton;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 56, color: Colores.textoApagado),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (boton != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: alTocar, child: Text(boton!)),
          ],
        ],
      ),
    ),
  );
}

/// Foto de una persona (un consejero, el propio usuario), o sus iniciales.
class FotoPersona extends StatelessWidget {
  const FotoPersona(this.nombre, this.foto, {super.key, this.radio = 22});

  final String nombre;
  final Uint8List? foto;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final iniciales = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radio,
      backgroundColor: Colores.nube,
      foregroundImage: foto == null ? null : MemoryImage(foto!),
      child: Text(
        iniciales,
        style: TextStyle(
          color: Colores.azul,
          fontFamily: Fuentes.titulos,
          fontWeight: FontWeight.w800,
          fontSize: radio * .72,
        ),
      ),
    );
  }
}

/// Foto del muchacho, o sus iniciales si no tiene.
class FotoAlumno extends StatelessWidget {
  const FotoAlumno(this.alumno, {super.key, this.radio = 22, this.heroe});

  final Alumno alumno;
  final double radio;

  /// Etiqueta para que la foto viaje de la lista al perfil. Debe ser única
  /// dentro de cada pantalla.
  final String? heroe;

  @override
  Widget build(BuildContext context) {
    final partes = alumno.nombre.trim().split(RegExp(r'\s+'));
    final iniciales = partes
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final foto = alumno.foto;
    final avatar = _avatar(iniciales, foto);
    return heroe == null ? avatar : Hero(tag: heroe!, child: avatar);
  }

  Widget _avatar(String iniciales, Uint8List? foto) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: Colores.nube,
      foregroundImage: foto == null ? null : MemoryImage(foto),
      child: Text(
        iniciales,
        style: TextStyle(
          color: Colores.azul,
          fontFamily: Fuentes.titulos,
          fontWeight: FontWeight.w800,
          fontSize: radio * .72,
        ),
      ),
    );
  }
}

/// Escudo del muchacho, armado hasta donde va su grado.
class InsigniaGrado extends StatelessWidget {
  const InsigniaGrado(this.grado, {super.key, this.alto = 64});

  final Grado grado;
  final double alto;

  @override
  Widget build(BuildContext context) =>
      EscudoArmable(etapa: grado.etapaEscudo, alto: alto);
}

/// Píldora con el porcentaje de asistencia en color de semáforo.
class PildoraPorcentaje extends StatelessWidget {
  const PildoraPorcentaje(this.porcentaje, {super.key});

  final double? porcentaje;

  @override
  Widget build(BuildContext context) {
    final color = colorPorcentaje(porcentaje);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        porcentaje == null ? '—' : '${porcentaje!.round()} %',
        style: TextStyle(
          fontFamily: Fuentes.titulos,
          color: color,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?accion,
      ],
    ),
  );
}
