import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/asistencia.dart';
import '../core/grados.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../widgets/movimiento.dart';
import 'pase_lista.dart';

/// Recuerda en el teléfono si ya se vio el tutorial.
abstract final class Preferencias {
  static const _clave = 'tutorial_visto';
  static bool tutorialVisto = true;

  static Future<void> cargar() async {
    final p = await SharedPreferences.getInstance();
    tutorialVisto = p.getBool(_clave) ?? false;
  }

  static Future<void> marcarTutorialVisto() async {
    tutorialVisto = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_clave, true);
  }
}

/// Tutorial de la primera vez. Son tres pasos y en cada uno se practica
/// con la app de verdad: pasar lista, armar el escudo e invitar al equipo.
class PantallaTutorial extends StatefulWidget {
  const PantallaTutorial({super.key, required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  State<PantallaTutorial> createState() => _PantallaTutorialState();
}

class _PantallaTutorialState extends State<PantallaTutorial> {
  final _paginas = PageController();
  int _paso = 0;

  /// Qué pasos ya practicó el usuario; habilita «Siguiente».
  final _hechos = [false, false, false];

  static const _total = 3;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _hecho(int paso) {
    if (!_hechos[paso]) setState(() => _hechos[paso] = true);
  }

  void _siguiente() {
    if (_paso == _total - 1) {
      widget.alTerminar();
      return;
    }
    _paginas.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: curvaLlegada,
    );
  }

  @override
  Widget build(BuildContext context) {
    final listo = _hechos[_paso];
    return Scaffold(
      body: BloqueAzul(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 10, 0),
                child: Row(
                  children: [
                    // Indicador de pasos: el actual se alarga.
                    for (var i = 0; i < _total; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 360),
                        curve: curvaLlegada,
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _paso ? 30 : 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: i <= _paso
                              ? Colores.oro
                              : const Color(0x55FFFFFF),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.alTerminar,
                      child: const Text('Saltar'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _paginas,
                  // Se avanza con el botón, para no brincar la práctica.
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _paso = i),
                  children: [
                    _PasoLista(alPracticar: () => _hecho(0)),
                    _PasoEscudo(alPracticar: () => _hecho(1)),
                    _PasoEquipo(alPracticar: () => _hecho(2)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: Text(
                        listo
                            ? '¡Eso es!'
                            : const [
                                'Inténtalo: toca a un muchacho',
                                'Inténtalo: toca «Subir de grado»',
                                'Inténtalo: genera un código',
                              ][_paso],
                        key: ValueKey('$_paso-$listo'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: listo ? Colores.oro : Colores.sobreAzul,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    BotonOro(
                      texto: _paso == _total - 1 ? 'Empezar' : 'Siguiente',
                      icono: _paso == _total - 1
                          ? PhosphorIconsBold.rocketLaunch
                          : PhosphorIconsBold.arrowRight,
                      alTocar: listo ? _siguiente : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marco común de cada paso: título, explicación y la zona de práctica.
class _Paso extends StatelessWidget {
  const _Paso({required this.titulo, required this.texto, required this.child});

  final String titulo;
  final String texto;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
    children: [
      Text(titulo, style: _estiloTituloPaso),
      const SizedBox(height: 10),
      Text(
        texto,
        style: const TextStyle(
          fontSize: 16,
          height: 1.45,
          color: Colores.sobreAzul,
        ),
      ),
      const SizedBox(height: 22),
      child,
    ],
  );
}

final _estiloTituloPaso = titulo(32, color: Colores.blanco);

// ------------------------------------------------------------ Paso 1: lista

class _PasoLista extends StatefulWidget {
  const _PasoLista({required this.alPracticar});

  final VoidCallback alPracticar;

  @override
  State<_PasoLista> createState() => _PasoListaState();
}

class _PasoListaState extends State<_PasoLista> {
  static final _muchachos = [
    for (final (i, (nombre, grado)) in const [
      ('Samuel Ortiz', Grado.paje),
      ('Mateo Luna', Grado.escudero),
      ('David Reyes', Grado.aspirante),
    ].indexed)
      Alumno(
        id: 'demo$i',
        nombre: nombre,
        grado: grado,
        fechaIngresoGrado: DateTime(2026),
      ),
  ];

  final _registros = <String, Registro>{};

  @override
  Widget build(BuildContext context) {
    final presentes = _registros.values.where((r) => r.presente).length;
    return _Paso(
      titulo: 'Pasa lista con un toque',
      texto:
          'Toca a cada muchacho que llegó, o deslízalo a la derecha. '
          'Luego marca si trajo su Biblia y su ofrenda.',
      child: Column(
        children: [
          MarcadorPresentes(presentes: presentes, total: _muchachos.length),
          const SizedBox(height: 18),
          for (final a in _muchachos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilaLista(
                alumno: a,
                registro: _registros[a.id] ?? const Registro(),
                alCambiar: (r) {
                  final antes = presentes;
                  setState(() => _registros[a.id] = r);
                  widget.alPracticar();
                  final ahora = _registros.values
                      .where((x) => x.presente)
                      .length;
                  if (ahora == _muchachos.length && antes < ahora) {
                    celebrar(context);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- Paso 2: escudo

class _PasoEscudo extends StatefulWidget {
  const _PasoEscudo({required this.alPracticar});

  final VoidCallback alPracticar;

  @override
  State<_PasoEscudo> createState() => _PasoEscudoState();
}

class _PasoEscudoState extends State<_PasoEscudo> {
  int _etapa = 0;

  static const _grados = [
    ('Aspirante', 'Todavía sin escudo'),
    ('Paje', 'Gana el escudo azul'),
    ('Escudero', 'Gana la franja E.R.'),
    ('Caballero', 'Gana la corona de oro'),
    ('Embajador', 'Gana la rama de laurel'),
  ];

  void _subir() {
    if (_etapa >= 4) {
      setState(() => _etapa = 0);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _etapa++);
    widget.alPracticar();
    if (_etapa == 4) celebrar(context);
  }

  @override
  Widget build(BuildContext context) {
    final (grado, premio) = _grados[_etapa];
    return _Paso(
      titulo: 'El escudo se gana grado por grado',
      texto:
          'La app lleva la asistencia (75 %), el tiempo en el grado y las '
          'cinco metas de cada muchacho. Al graduarlo, su escudo se completa.',
      child: Tarjeta(
        destacada: _etapa == 4,
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
        child: Column(
          children: [
            Pulsable(
              alTocar: _subir,
              child: EscudoArmable(etapa: _etapa, alto: 190),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: curvaLlegada,
              child: Column(
                key: ValueKey(_etapa),
                children: [
                  Text(grado, style: titulo(26, color: Colores.azul)),
                  const SizedBox(height: 2),
                  Text(
                    premio,
                    style: const TextStyle(color: Colores.textoSuave),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _subir,
              icon: Icon(
                _etapa >= 4
                    ? PhosphorIconsBold.arrowCounterClockwise
                    : PhosphorIconsBold.medal,
              ),
              label: Text(_etapa >= 4 ? 'Otra vez' : 'Subir de grado'),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- Paso 3: equipo

class _PasoEquipo extends StatefulWidget {
  const _PasoEquipo({required this.alPracticar});

  final VoidCallback alPracticar;

  @override
  State<_PasoEquipo> createState() => _PasoEquipoState();
}

class _PasoEquipoState extends State<_PasoEquipo> {
  static const _letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  String? _codigo;
  int _generacion = 0;

  void _generar() {
    final azar = Random();
    HapticFeedback.mediumImpact();
    setState(() {
      _generacion++;
      _codigo = List.generate(
        6,
        (_) => _letras[azar.nextInt(_letras.length)],
      ).join();
    });
    widget.alPracticar();
  }

  @override
  Widget build(BuildContext context) => _Paso(
    titulo: 'Tu capítulo, tu equipo',
    texto:
        'El líder crea el capítulo e invita a cada consejero con un '
        'código. Todos ven la misma lista al instante, y si alguien '
        'falta, otro consejero puede cubrir su grupo.',
    child: Column(
      children: [
        Tarjeta(
          destacada: _codigo != null,
          child: Column(
            children: [
              const Text(
                'Código de invitación de ejemplo',
                style: TextStyle(color: Colores.textoSuave),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Casilla(
                        _codigo?[i],
                        orden: i,
                        generacion: _generacion,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _generar,
                icon: const Icon(PhosphorIconsBold.key),
                label: Text(
                  _codigo == null ? 'Generar código' : 'Generar otro',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _Dato(
          PhosphorIconsBold.camera,
          'Toma fotos de los que llegaron y de las actividades.',
        ),
        const _Dato(
          PhosphorIconsBold.wifiSlash,
          'Sin señal también funciona: se sincroniza al volver.',
        ),
        const _Dato(
          PhosphorIconsBold.filePdf,
          'Saca la lista en PDF o Excel cuando la necesites.',
        ),
      ],
    ),
  );
}

/// Casilla de una letra del código; la letra cae con un pequeño retraso.
class _Casilla extends StatelessWidget {
  const _Casilla(this.letra, {required this.orden, required this.generacion});

  final String? letra;
  final int orden;

  /// Cambia con cada código nuevo para repetir la caída de las letras.
  final int generacion;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 54,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colores.nube,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colores.borde),
    ),
    child: letra == null
        ? const Text('·', style: TextStyle(color: Colores.textoApagado))
        : TweenAnimationBuilder<double>(
            key: ValueKey('$generacion-$orden'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 320 + orden * 70),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(
              opacity: v.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, -14 * (1 - v)),
                child: child,
              ),
            ),
            child: Text(letra!, style: titulo(26, color: Colores.azul)),
          ),
  );
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icono, color: Colores.oro, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(texto, style: const TextStyle(color: Colores.blanco)),
        ),
      ],
    ),
  );
}
