import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/iconos.dart';

import 'core/tema.dart' show temaEmbajadores;
import 'features/acceso.dart';
import 'features/principal.dart';
import 'features/sin_capitulo.dart';
import 'features/tutorial.dart';
import 'services/proveedores.dart';
import 'widgets/comunes.dart';
import 'widgets/movimiento.dart';

class AppEmbajadores extends StatelessWidget {
  const AppEmbajadores({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Embajadores del Rey',
    debugShowCheckedModeBanner: false,
    theme: temaEmbajadores(),
    locale: const Locale('es', 'MX'),
    supportedLocales: const [Locale('es', 'MX')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    // El fondo de la Orden va detrás de toda la app.
    builder: (_, child) => FondoOrden(child: child!),
    home: const Puerta(),
  );
}

/// Decide qué ve el usuario según su sesión y su capítulo. Al abrir la app
/// muestra la pantalla de carga hasta que termina su animación y ya se sabe
/// a dónde va; los cambios de estado (entrar, salir, crear capítulo) se
/// funden entre sí.
class Puerta extends ConsumerStatefulWidget {
  const Puerta({super.key});

  @override
  ConsumerState<Puerta> createState() => _PuertaState();
}

class _PuertaState extends ConsumerState<Puerta> {
  bool _introTerminada = false;
  bool _tutorialVisto = Preferencias.tutorialVisto;

  /// Pantalla que corresponde, o null mientras todavía se está cargando.
  Widget? _destino() {
    final sesion = ref.watch(sesionProvider);
    if (sesion.isLoading) return null;
    if (sesion.value == null) return const PantallaAcceso();

    final perfil = ref.watch(perfilProvider);
    if (perfil.isLoading && perfil.value == null) return null;
    if (perfil.value == null) return const _CrearPerfil();

    final capId = ref.watch(capIdProvider);
    if (capId == null) return const PantallaSinCapitulo();

    final yo = ref.watch(yoProvider);
    final capitulo = ref.watch(capituloProvider);
    if (yo.hasError || capitulo.hasError) {
      return const PantallaSinAcceso(
        'No se puede abrir este capítulo. Puede estar suspendido o ya no '
        'tienes acceso.',
      );
    }
    if (yo.value == null || capitulo.value == null) {
      if (yo.isLoading || capitulo.isLoading) return null;
      return const PantallaSinAcceso('Ya no formas parte de este capítulo.');
    }
    if (!yo.value!.activo) {
      return const PantallaSinAcceso(
        'Tu líder desactivó tu acceso a este capítulo.',
      );
    }
    return const PantallaPrincipal();
  }

  @override
  Widget build(BuildContext context) {
    final destino = _introTerminada ? _destino() : null;
    // Si se llama a _destino solo tras la intro, los proveedores no se
    // escucharían antes; se leen siempre para que carguen durante la intro.
    if (!_introTerminada) _destino();

    final Widget actual;
    if (!_introTerminada) {
      actual = PantallaArranque(
        alTerminar: () => setState(() => _introTerminada = true),
      );
    } else if (!_tutorialVisto) {
      // Solo la primera vez que se abre la app en este teléfono.
      actual = PantallaTutorial(
        alTerminar: () {
          Preferencias.marcarTutorialVisto();
          setState(() => _tutorialVisto = true);
        },
      );
    } else {
      actual = destino ?? const _Espera();
    }

    return AnimatedSwitcher(
      duration: sinMovimiento(context)
          ? Duration.zero
          : const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: curvaLlegada,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animacion) => FadeTransition(
        opacity: animacion,
        child: ScaleTransition(
          scale: Tween(begin: 1.04, end: 1.0).animate(animacion),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(actual.runtimeType), child: actual),
    );
  }
}

/// Espera breve después de la intro (por ejemplo, al cambiar de capítulo).
class _Espera extends StatelessWidget {
  const _Espera();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// La primera vez que alguien entra todavía no tiene perfil: se crea aquí.
class _CrearPerfil extends ConsumerStatefulWidget {
  const _CrearPerfil();
  @override
  ConsumerState<_CrearPerfil> createState() => _CrearPerfilState();
}

class _CrearPerfilState extends ConsumerState<_CrearPerfil> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _crear();
  }

  Future<void> _crear() async {
    setState(() => _error = null);
    try {
      await ref.read(repoProvider).asegurarPerfil();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _error == null
        ? const Center(child: CircularProgressIndicator())
        : Vacio(
            icono: PhosphorIconsBold.cloudSlash,
            texto: mensajeDeError(_error!),
            boton: 'Reintentar',
            alTocar: _crear,
          ),
  );
}
