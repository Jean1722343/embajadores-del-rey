import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/tema.dart';

/// Curva de llegada: arranca rápido y frena largo.
const curvaLlegada = Curves.easeOutExpo;

bool sinMovimiento(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

// ------------------------------------------------------------------ Fondo

/// Fondo general de la app: blanco.
class FondoOrden extends StatelessWidget {
  const FondoOrden({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Colores.blanco, child: child);
}

/// Bloque de azul real con las dos franjas diagonales del escudo. Lo que va
/// dentro usa el tema sobre azul: texto blanco y acentos en oro.
class BloqueAzul extends StatelessWidget {
  const BloqueAzul({super.key, required this.child, this.franjas = true});

  final Widget child;
  final bool franjas;

  @override
  Widget build(BuildContext context) => Theme(
    data: temaSobreAzul,
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colores.blanco),
      child: ColoredBox(
        color: Colores.azul,
        child: CustomPaint(
          painter: franjas ? const _Franjas() : null,
          child: child,
        ),
      ),
    ),
  );
}

/// Las franjas del escudo: una ancha y una delgada, en diagonal, pegadas
/// a la esquina superior derecha del bloque.
class _Franjas extends CustomPainter {
  const _Franjas();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..color = Colores.azulFranja;
    canvas.clipRect(Offset.zero & size);
    // Misma inclinación que la franja «E.R.» del escudo (unos 40 grados).
    const pendiente = 0.84;
    for (final (inicio, ancho) in [(0.46, 62.0), (0.46 + 0.0001, -1.0)]) {
      if (ancho < 0) continue;
      final x0 = size.width * inicio;
      final alto = size.height;
      canvas.drawPath(
        Path()
          ..moveTo(x0, alto)
          ..lineTo(x0 + ancho, alto)
          ..lineTo(x0 + ancho + alto / pendiente, 0)
          ..lineTo(x0 + alto / pendiente, 0)
          ..close(),
        pincel,
      );
      // Filete delgado paralelo, como el doble borde del escudo.
      canvas.drawPath(
        Path()
          ..moveTo(x0 + ancho + 18, alto)
          ..lineTo(x0 + ancho + 30, alto)
          ..lineTo(x0 + ancho + 30 + alto / pendiente, 0)
          ..lineTo(x0 + ancho + 18 + alto / pendiente, 0)
          ..close(),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_Franjas anterior) => false;
}

/// Ruta con la transición de la app: la pantalla nueva entra desde la
/// derecha frenando, mientras la anterior se hunde y se apaga un poco.
/// Salir es más rápido que entrar.
class RutaEmbajadores<T> extends PageRouteBuilder<T> {
  RutaEmbajadores(Widget pantalla)
    : super(
        pageBuilder: (_, _, _) => FondoOrden(child: pantalla),
        transitionDuration: const Duration(milliseconds: 460),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: _transicion,
      );

  static Widget _transicion(
    BuildContext context,
    Animation<double> animacion,
    Animation<double> secundaria,
    Widget child,
  ) {
    if (sinMovimiento(context)) {
      return FadeTransition(opacity: animacion, child: child);
    }
    final entra = CurvedAnimation(
      parent: animacion,
      curve: curvaLlegada,
      reverseCurve: Curves.easeInCubic,
    );
    final cubre = CurvedAnimation(parent: secundaria, curve: curvaLlegada);
    return SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(entra),
      child: DecoratedBoxTransition(
        decoration: DecorationTween(
          begin: const BoxDecoration(),
          end: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x40141840),
                blurRadius: 30,
                offset: Offset(-12, 0),
              ),
            ],
          ),
        ).animate(entra),
        // La pantalla que queda debajo retrocede.
        child: SlideTransition(
          position: Tween(
            begin: Offset.zero,
            end: const Offset(-0.22, 0),
          ).animate(cubre),
          child: FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.4).animate(cubre),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Superficies

/// Tarjeta blanca con filete. Con [destacada] el filete es azul. Dentro
/// siempre rige el tema general, aunque la tarjeta esté sobre azul.
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radio = 18,
    this.destacada = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;
  final bool destacada;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOut,
    padding: padding,
    decoration: BoxDecoration(
      color: Colores.blanco,
      borderRadius: BorderRadius.circular(radio),
      border: Border.all(
        color: destacada ? Colores.azul : Colores.borde,
        width: destacada ? 2 : 1.5,
      ),
    ),
    child: Theme(
      data: temaBase,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colores.tinta),
        child: child,
      ),
    ),
  );
}

/// Hace que su hijo ceda al tocarlo: se encoge un poco y regresa.
class Pulsable extends StatefulWidget {
  const Pulsable({super.key, required this.child, this.alTocar});

  final Widget child;
  final VoidCallback? alTocar;

  @override
  State<Pulsable> createState() => _PulsableState();
}

class _PulsableState extends State<Pulsable> {
  bool _abajo = false;

  void _poner(bool v) {
    if (_abajo != v) setState(() => _abajo = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _poner(true),
    onTapCancel: () => _poner(false),
    onTapUp: (_) => _poner(false),
    onTap: widget.alTocar == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            widget.alTocar!();
          },
    child: AnimatedScale(
      scale: _abajo ? 0.965 : 1,
      duration: Duration(milliseconds: _abajo ? 90 : 260),
      curve: _abajo ? Curves.easeOut : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

/// Botón en oro, para la acción principal sobre un bloque azul y para
/// los momentos de celebración.
class BotonOro extends StatelessWidget {
  const BotonOro({super.key, required this.texto, this.icono, this.alTocar});

  final String texto;
  final IconData? icono;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final activo = alTocar != null;
    return Pulsable(
      alTocar: alTocar,
      child: AnimatedOpacity(
        opacity: activo ? 1 : 0.38,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colores.oro,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(icono, color: Colores.tinta, size: 21),
                const SizedBox(width: 8),
              ],
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Colores.tinta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrada escalonada para los primeros elementos de una lista: suben y
/// aparecen uno tras otro. El retraso total está acotado.
class Entrada extends StatefulWidget {
  const Entrada({super.key, required this.child, this.orden = 0});

  final Widget child;
  final int orden;

  @override
  State<Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<Entrada> with SingleTickerProviderStateMixin {
  late final _control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void initState() {
    super.initState();
    final espera = Duration(milliseconds: 45 * widget.orden.clamp(0, 8));
    Future.delayed(espera, () {
      if (mounted) _control.forward();
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (sinMovimiento(context)) return widget.child;
    final curva = CurvedAnimation(parent: _control, curve: curvaLlegada);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _control, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(curva),
        child: widget.child,
      ),
    );
  }
}

/// Número que cuenta hasta su valor cuando cambia.
class CifraAnimada extends StatelessWidget {
  const CifraAnimada(
    this.valor, {
    super.key,
    required this.estilo,
    this.sufijo = '',
  });

  final num valor;
  final TextStyle estilo;
  final String sufijo;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: valor.toDouble()),
    duration: sinMovimiento(context)
        ? Duration.zero
        : const Duration(milliseconds: 620),
    curve: curvaLlegada,
    builder: (_, v, _) => Text('${v.round()}$sufijo', style: estilo),
  );
}

/// Barra de avance que se desliza a su valor.
class BarraAvance extends StatelessWidget {
  const BarraAvance(
    this.fraccion, {
    super.key,
    this.color = Colores.oro,
    this.fondo = Colores.nube,
    this.alto = 8,
  });

  final double fraccion;
  final Color color;
  final Color fondo;
  final double alto;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: fraccion.clamp(0, 1).toDouble()),
    duration: sinMovimiento(context)
        ? Duration.zero
        : const Duration(milliseconds: 620),
    curve: curvaLlegada,
    builder: (_, v, _) => ClipRRect(
      borderRadius: BorderRadius.circular(alto),
      child: SizedBox(
        height: alto,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: fondo),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(alto),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Encabezado de las pantallas principales: bloque azul con las franjas
/// y un filete de oro abajo, como un banderín.
class Encabezado extends StatelessWidget {
  const Encabezado({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BloqueAzul(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
      const ColoredBox(
        color: Colores.oro,
        child: SizedBox(height: 5, width: double.infinity),
      ),
    ],
  );
}

// ----------------------------------------------------------------- Escudo

const _etapas = [
  'assets/emblema/escudo_1_paje.png',
  'assets/emblema/escudo_2_escudero.png',
  'assets/emblema/escudo_3_caballero.png',
  'assets/emblema/escudo_4_embajador.png',
];

ImageProvider _imagenEtapa(int i) =>
    ResizeImage(AssetImage(_etapas[i]), height: 520);

/// Las imágenes de la pantalla de carga, para decodificarlas antes del
/// primer cuadro (ver main.dart).
final imagenesDeArranque = [
  for (var i = 0; i < _etapas.length; i++) _imagenEtapa(i),
];

/// Descubre a su hijo con un barrido en la diagonal de la franja del escudo,
/// de abajo a la izquierda hacia arriba a la derecha.
class _BarridoDiagonal extends CustomClipper<Path> {
  const _BarridoDiagonal(this.avance);

  final double avance;

  @override
  Path getClip(Size size) {
    final d = avance * (size.width + size.height);
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(d, size.height)
      ..lineTo(0, size.height - d)
      ..close();
  }

  @override
  bool shouldReclip(_BarridoDiagonal anterior) => anterior.avance != avance;
}

/// El escudo armado hasta cierta etapa (0 = aún sin escudo, 1 = escudo
/// azul, 2 = franja E.R., 3 = corona, 4 = laurel). Al cambiar la etapa,
/// la pieza nueva entra con el barrido diagonal.
class EscudoArmable extends StatelessWidget {
  const EscudoArmable({super.key, required this.etapa, this.alto = 120});

  final int etapa;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final rapido = sinMovimiento(context);
    return SizedBox(
      height: alto,
      width: alto * 0.8,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Silueta de lo que falta por ganar.
          Opacity(
            opacity: 0.16,
            child: Image(image: _imagenEtapa(0), fit: BoxFit.contain),
          ),
          for (var i = 0; i < _etapas.length; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(end: i < etapa ? 1.0 : 0.0),
              duration: rapido
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: curvaLlegada,
              builder: (_, v, child) => v == 0
                  ? const SizedBox.shrink()
                  : ClipPath(clipper: _BarridoDiagonal(v), child: child),
              child: Image(image: _imagenEtapa(i), fit: BoxFit.contain),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Celebración

/// Estallido de chispas de oro sobre toda la pantalla. Se usa cuando todo
/// el grupo llegó o cuando un muchacho se gradúa.
void celebrar(BuildContext context) {
  HapticFeedback.heavyImpact();
  if (sinMovimiento(context)) return;
  final capa = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1500),
        onEnd: entrada.remove,
        builder: (_, t, _) =>
            CustomPaint(painter: _Chispas(t), size: Size.infinite),
      ),
    ),
  );
  capa.insert(entrada);
}

class _Chispas extends CustomPainter {
  _Chispas(this.t);

  final double t;

  static final _semillas = () {
    final azar = math.Random(7);
    return [
      for (var i = 0; i < 70; i++)
        (
          angulo: azar.nextDouble() * math.pi * 2,
          fuerza: 0.35 + azar.nextDouble() * 0.75,
          tamano: 3.0 + azar.nextDouble() * 5,
          giro: azar.nextDouble() * 6,
          tono: azar.nextInt(3),
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final origen = Offset(size.width / 2, size.height * 0.34);
    final salida = Curves.easeOutCubic.transform(t);
    const tonos = [Colores.oro, Colores.azul, Color(0xFF6B73D6)];
    for (final s in _semillas) {
      final alcance = size.width * 0.75 * s.fuerza * salida;
      final p =
          origen +
          Offset(math.cos(s.angulo), math.sin(s.angulo)) * alcance +
          Offset(0, size.height * 0.45 * t * t);
      final pincel = Paint()
        ..color = tonos[s.tono].withValues(alpha: (1 - t * t).clamp(0, 1));
      canvas
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(s.giro + t * 5)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: s.tamano * 1.9,
              height: s.tamano,
            ),
            const Radius.circular(1.5),
          ),
          pincel,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_Chispas anterior) => anterior.t != t;
}

// ------------------------------------------------------------ Pantalla de carga

/// Pantalla de carga: el escudo se arma en sus cuatro etapas, como lo gana
/// un muchacho grado por grado (escudo, franja E.R., corona y laurel), y
/// después aparece el nombre. Avisa con [alTerminar] cuando acabó.
class PantallaArranque extends StatefulWidget {
  const PantallaArranque({super.key, this.alTerminar});

  final VoidCallback? alTerminar;

  @override
  State<PantallaArranque> createState() => _PantallaArranqueState();
}

class _PantallaArranqueState extends State<PantallaArranque>
    with SingleTickerProviderStateMixin {
  late final _control =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1700),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.alTerminar?.call();
      });

  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (sinMovimiento(context)) {
      _control.value = 1;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.alTerminar?.call(),
      );
    } else {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  Animation<double> _tramo(double inicio, double fin) => CurvedAnimation(
    parent: _control,
    curve: Interval(inicio, fin, curve: curvaLlegada),
  );

  Widget _etapa(int i) => Image(
    image: _imagenEtapa(i),
    height: 172,
    filterQuality: FilterQuality.medium,
  );

  @override
  Widget build(BuildContext context) {
    final nombre = _tramo(0.56, 0.9);
    final lema = _tramo(0.7, 1);
    final barridos = [
      for (var i = 1; i < _etapas.length; i++)
        _tramo(0.06 + (i - 1) * 0.17, 0.3 + (i - 1) * 0.17),
    ];
    return Scaffold(
      backgroundColor: Colores.blanco,
      body: SizedBox.expand(
        // El escudo queda en el centro exacto de la pantalla, donde lo deja
        // la pantalla de arranque de Android; el nombre va debajo.
        child: Stack(
          alignment: Alignment.center,
          children: [
            _etapa(0),
            for (var i = 1; i < _etapas.length; i++)
              AnimatedBuilder(
                animation: barridos[i - 1],
                builder: (_, child) => ClipPath(
                  clipper: _BarridoDiagonal(barridos[i - 1].value),
                  child: child,
                ),
                child: _etapa(i),
              ),
            Align(
              alignment: const Alignment(0, 0.42),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: nombre,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(nombre),
                      child: Text('Embajadores del Rey', style: titulo(28)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filete de oro que se traza desde el centro.
                  SizeTransition(
                    sizeFactor: nombre,
                    axis: Axis.horizontal,
                    child: Container(
                      width: 56,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colores.oro,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: lema,
                    child: const Text(
                      'Embajadores en nombre de Cristo',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Colores.textoSuave,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
