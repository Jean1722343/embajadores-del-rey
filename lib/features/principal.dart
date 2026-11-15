import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import '../core/tema.dart';
import '../widgets/movimiento.dart';
import 'admin.dart';
import 'alumnos.dart';
import 'evidencias.dart';
import 'inicio.dart';
import 'caja.dart';

/// Pantalla con la barra de navegación inferior.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});
  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indice = 0;

  /// Clave global: la pila de pestañas conserva su estado aunque la
  /// animación que la envuelve se reinicie.
  final _pila = GlobalKey();

  static const _pantallas = [
    PantallaInicio(),
    PantallaAlumnos(),
    PantallaCaja(),
    PantallaEvidencias(),
    PantallaAdmin(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    // IndexedStack conserva el estado de cada pestaña; la clave hace
    // que la entrada se repita cada vez que se cambia de pestaña.
    body: TweenAnimationBuilder<double>(
      key: ValueKey(_indice),
      tween: Tween(begin: 0, end: 1),
      duration: sinMovimiento(context)
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: curvaLlegada,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - v)),
          child: child,
        ),
      ),
      child: IndexedStack(key: _pila, index: _indice, children: _pantallas),
    ),
    bottomNavigationBar: _Barra(
      indice: _indice,
      alElegir: (i) {
        if (i == _indice) return;
        HapticFeedback.selectionClick();
        setState(() => _indice = i);
      },
    ),
  );
}

/// Barra inferior: blanca, con un filete de oro que se desliza sobre la
/// pestaña elegida.
class _Barra extends StatelessWidget {
  const _Barra({required this.indice, required this.alElegir});

  final int indice;
  final ValueChanged<int> alElegir;

  static const _pestanas = [
    (PhosphorIconsBold.listChecks, PhosphorIconsFill.listChecks, 'Lista'),
    (PhosphorIconsBold.usersThree, PhosphorIconsFill.usersThree, 'Muchachos'),
    (PhosphorIconsBold.wallet, PhosphorIconsFill.wallet, 'Caja'),
    (PhosphorIconsBold.images, PhosphorIconsFill.images, 'Fotos'),
    (
      PhosphorIconsBold.shieldChevron,
      PhosphorIconsFill.shieldChevron,
      'Capítulo',
    ),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colores.blanco,
      border: Border(top: BorderSide(color: Colores.borde, width: 1.5)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 66,
        child: LayoutBuilder(
          builder: (context, medidas) {
            final ancho = medidas.maxWidth / _pestanas.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: sinMovimiento(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 380),
                  curve: curvaLlegada,
                  left: ancho * indice + ancho / 2 - 20,
                  top: 0,
                  width: 40,
                  height: 4,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colores.oro,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (i, (icono, iconoActivo, texto))
                        in _pestanas.indexed)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == indice,
                          label: texto,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => alElegir(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  i == indice ? iconoActivo : icono,
                                  size: 23,
                                  color: i == indice
                                      ? Colores.azul
                                      : Colores.textoApagado,
                                ),
                                const SizedBox(height: 3),
                                ExcludeSemantics(
                                  child: Text(
                                    texto,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: i == indice
                                          ? Colores.azul
                                          : Colores.textoSuave,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
