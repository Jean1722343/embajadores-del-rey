import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import '../core/asistencia.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import '../widgets/movimiento.dart';
import 'evidencias.dart';

/// Pase de lista de un grupo en una reunión. Cada toque se guarda al
/// instante y los demás consejeros lo ven en vivo.
class PantallaPaseLista extends ConsumerWidget {
  const PantallaPaseLista({
    super.key,
    required this.reunion,
    required this.grupo,
  });

  final Reunion reunion;
  final Grupo grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref
        .watch(listaProvider((reunionId: reunion.id, grupoId: grupo.id)))
        .value;
    final alumnos = alumnosDeGrupo(ref.watch(alumnosActivosProvider), grupo);
    final registros = lista?.registros ?? const <String, Registro>{};
    final presentes = alumnos
        .where((a) => registros[a.id]?.presente ?? false)
        .length;

    // Guarda los cambios y, de paso, deja como ausentes a los que aún no
    // tienen registro, para que la falta cuente en su porcentaje.
    void guardar(Map<String, Registro> cambios) {
      final despues = {...registros, ...cambios};
      final llegaron = alumnos
          .where((a) => despues[a.id]?.presente ?? false)
          .length;
      // Grupo completo: se celebra una vez, al completarse.
      if (alumnos.length > 1 &&
          llegaron == alumnos.length &&
          presentes < alumnos.length) {
        celebrar(context);
        avisar(context, '¡Grupo completo!');
      }
      ref
          .read(repoProvider)
          .marcar(
            capId: ref.read(capIdProvider)!,
            reunion: reunion,
            grupoId: grupo.id,
            miNombre: ref.read(miNombreProvider),
            registros: {
              for (final a in alumnos)
                if (!registros.containsKey(a.id)) a.id: const Registro(),
              ...cambios,
            },
          );
    }

    return Scaffold(
      body: Column(
        children: [
          Encabezado(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        PhosphorIconsBold.arrowLeft,
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    Expanded(
                      child: Text(
                        fechaLarga(reunion.fecha),
                        style: const TextStyle(
                          color: Colores.sobreAzul,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tomar foto de evidencia',
                      icon: const Icon(
                        PhosphorIconsBold.camera,
                        color: Colores.oro,
                      ),
                      onPressed: () => agregarEvidencia(
                        context,
                        ref,
                        reunionId: reunion.id,
                        grupoId: grupo.id,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(grupo.nombre, style: titulo(30, color: Colores.blanco)),
                const SizedBox(height: 14),
                MarcadorPresentes(
                  presentes: presentes,
                  total: alumnos.length,
                  alMarcarTodos: alumnos.isEmpty
                      ? null
                      : () => guardar({
                          for (final a in alumnos)
                            a.id: (registros[a.id] ?? const Registro()).copiar(
                              presente: true,
                            ),
                        }),
                ),
                const SizedBox(height: 10),
                Text(
                  lista == null
                      ? 'Toca o desliza a cada muchacho que llegó'
                      : 'Última marca: ${lista.tomadaPorNombre}'
                            '${lista.ofrendaTotal > 0 ? ' · ofrenda ${dinero(lista.ofrendaTotal)}' : ''}',
                  style: const TextStyle(color: Colores.sobreAzul),
                ),
              ],
            ),
          ),
          Expanded(
            child: alumnos.isEmpty
                ? const Vacio(
                    icono: PhosphorIconsBold.usersThree,
                    texto:
                        'Todavía no hay muchachos con los grados de este '
                        'grupo. Agrégalos en la pestaña Muchachos.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
                    itemCount: alumnos.length,
                    itemBuilder: (context, i) {
                      final a = alumnos[i];
                      final fila = FilaLista(
                        alumno: a,
                        registro: registros[a.id] ?? const Registro(),
                        alCambiar: (nuevo) => guardar({a.id: nuevo}),
                      );
                      // Solo los primeros entran escalonados; el resto
                      // aparece normal al desplazarse.
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: i < 9 ? Entrada(orden: i, child: fila) : fila,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Contador grande de presentes con su barra y el botón «Todos». Está
/// pensado para ir dentro de un bloque azul.
class MarcadorPresentes extends StatelessWidget {
  const MarcadorPresentes({
    super.key,
    required this.presentes,
    required this.total,
    this.alMarcarTodos,
  });

  final int presentes;
  final int total;
  final VoidCallback? alMarcarTodos;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CifraAnimada(
            presentes,
            estilo: titulo(
              52,
              color: Colores.oro,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 9),
            child: Text(
              'de $total presentes',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colores.blanco,
              ),
            ),
          ),
          const Spacer(),
          if (alMarcarTodos != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  alMarcarTodos!();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(PhosphorIconsBold.checks, size: 18),
                label: const Text('Todos'),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      BarraAvance(
        total == 0 ? 0 : presentes / total,
        fondo: const Color(0x40FFFFFF),
      ),
    ],
  );
}

/// Pregunta cuánto ofrendó un muchacho. Devuelve la cantidad (cero para
/// quitar la ofrenda) o null si se canceló.
Future<double?> pedirOfrenda(
  BuildContext context, {
  required String nombre,
  double actual = 0,
}) {
  final campo = TextEditingController(
    text: actual > 0 ? actual.toStringAsFixed(actual % 1 == 0 ? 0 : 2) : '',
  );
  double leer() => double.tryParse(campo.text.replaceAll(',', '.')) ?? 0;
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(c).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ofrenda', style: titulo(26)),
            Text(nombre, style: const TextStyle(color: Colores.textoSuave)),
            const SizedBox(height: 14),
            // Cantidades frecuentes: un toque y listo.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cantidad in const [5.0, 10.0, 20.0, 50.0, 100.0])
                  ActionChip(
                    label: Text(dinero(cantidad)),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(c, cantidad);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: campo,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Otra cantidad',
                prefixText: r'$ ',
              ),
              onSubmitted: (_) => Navigator.pop(c, leer()),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(c, leer()),
              child: const Text('Guardar'),
            ),
            if (actual > 0)
              TextButton(
                onPressed: () => Navigator.pop(c, 0.0),
                child: const Text('Quitar la ofrenda'),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Fila de un muchacho en el pase de lista. Se marca con un toque o
/// deslizando: a la derecha presente, a la izquierda ausente.
class FilaLista extends StatelessWidget {
  const FilaLista({
    super.key,
    required this.alumno,
    required this.registro,
    required this.alCambiar,
  });

  final Alumno alumno;
  final Registro registro;
  final ValueChanged<Registro> alCambiar;

  void _poner(bool presente) {
    if (presente == registro.presente) return;
    HapticFeedback.selectionClick();
    // Al quitar la presencia se limpian también Biblia y ofrenda.
    alCambiar(presente ? registro.copiar(presente: true) : const Registro());
  }

  @override
  Widget build(BuildContext context) {
    final presente = registro.presente;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Dismissible(
        key: ValueKey('fila-${alumno.id}'),
        // Nunca se descarta: el deslizamiento solo marca.
        confirmDismiss: (direccion) async {
          _poner(direccion == DismissDirection.startToEnd);
          return false;
        },
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.22,
          DismissDirection.endToStart: 0.22,
        },
        background: const _FondoDeslizar(
          texto: 'Presente',
          icono: PhosphorIconsBold.check,
          color: Colores.oro,
          alineacion: Alignment.centerLeft,
        ),
        secondaryBackground: const _FondoDeslizar(
          texto: 'Ausente',
          icono: PhosphorIconsBold.x,
          color: Colores.nube,
          alineacion: Alignment.centerRight,
        ),
        child: Pulsable(
          alTocar: () => _poner(!presente),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: presente ? Colores.azul : Colores.blanco,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                // Filete de oro al marcar: la fila se distingue también
                // sobre fondo azul (tutorial).
                color: presente ? Colores.oro : Colores.borde,
                width: presente ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                FotoAlumno(alumno, radio: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alumno.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: presente ? Colores.blanco : Colores.tinta,
                        ),
                      ),
                      Text(
                        alumno.grado.nombre,
                        style: TextStyle(
                          fontSize: 13,
                          color: presente
                              ? Colores.sobreAzul
                              : Colores.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                _Extra(
                  icono: PhosphorIconsBold.bookOpenText,
                  etiqueta: 'Biblia',
                  activo: registro.biblia,
                  habilitado: presente,
                  alTocar: () =>
                      alCambiar(registro.copiar(biblia: !registro.biblia)),
                ),
                _Extra(
                  icono: PhosphorIconsBold.handHeart,
                  // Con cantidad anotada, la casilla muestra cuánto dio.
                  etiqueta: registro.monto > 0
                      ? dinero(registro.monto)
                      : 'Ofrenda',
                  activo: registro.ofrenda,
                  habilitado: presente,
                  alTocar: () async {
                    final cantidad = await pedirOfrenda(
                      context,
                      nombre: alumno.nombre,
                      actual: registro.monto,
                    );
                    if (cantidad != null) {
                      alCambiar(registro.conOfrenda(cantidad));
                    }
                  },
                ),
                const SizedBox(width: 6),
                _Sello(presente),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FondoDeslizar extends StatelessWidget {
  const _FondoDeslizar({
    required this.texto,
    required this.icono,
    required this.color,
    required this.alineacion,
  });

  final String texto;
  final IconData icono;
  final Color color;
  final Alignment alineacion;

  @override
  Widget build(BuildContext context) {
    const tinta = Colores.tinta;
    return Container(
      color: color,
      alignment: alineacion,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: tinta),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(color: tinta, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Marca de presente: el sello de oro se estampa con un pequeño rebote.
class _Sello extends StatelessWidget {
  const _Sello(this.presente);

  final bool presente;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 42,
    height: 42,
    child: AnimatedSwitcher(
      duration: sinMovimiento(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 120),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animacion) => ScaleTransition(
        scale: Tween(begin: 0.35, end: 1.0).animate(animacion),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animacion,
            curve: const Interval(0, 0.5),
          ),
          child: child,
        ),
      ),
      child: presente
          ? Container(
              key: const ValueKey(true),
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colores.oro,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsBold.check,
                color: Colores.tinta,
                size: 24,
                semanticLabel: 'Presente',
              ),
            )
          : Container(
              key: const ValueKey(false),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colores.borde, width: 2.5),
              ),
              child: Semantics(label: 'Ausente'),
            ),
    ),
  );
}

/// Casilla pequeña de Biblia u ofrenda; solo se usa si el muchacho vino.
class _Extra extends StatelessWidget {
  const _Extra({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.habilitado,
    required this.alTocar,
  });

  final IconData icono;
  final String etiqueta;
  final bool activo;
  final bool habilitado;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final encendido = activo && habilitado;
    // Deshabilitada: el muchacho no vino (fila blanca). Habilitada: la fila
    // es azul; encendida se rellena de oro.
    final color = !habilitado
        ? Colores.textoApagado
        : activo
        ? Colores.tinta
        : Colores.blanco;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: habilitado
            ? () {
                HapticFeedback.selectionClick();
                alTocar();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: encendido ? Colores.oro : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: habilitado && !activo
                  ? const Color(0x66FFFFFF)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              AnimatedScale(
                scale: encendido ? 1.12 : 1,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Icon(icono, size: 21, color: color),
              ),
              const SizedBox(height: 1),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
