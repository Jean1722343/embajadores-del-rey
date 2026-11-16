import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import 'package:url_launcher/url_launcher.dart';

import '../core/asistencia.dart';
import '../core/cumpleanos.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/actualizacion.dart';
import '../services/proveedores.dart';
import '../services/repo.dart';
import '../widgets/comunes.dart';
import '../widgets/movimiento.dart';
import 'admin.dart';
import 'alumnos.dart';
import 'pase_lista.dart';

String _muchachos(int n) => n == 1 ? '1 muchacho' : '$n muchachos';

/// Inicio: la reunión del día, los grupos para pasar lista y las alertas.
class PantallaInicio extends ConsumerStatefulWidget {
  const PantallaInicio({super.key});
  @override
  ConsumerState<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends ConsumerState<PantallaInicio> {
  DateTime _dia = DateTime.now();

  bool get _esHoy => idDeFecha(_dia) == idDeFecha(DateTime.now());

  Future<void> _elegirDia(Periodo periodo) async {
    final hoy = DateTime.now();
    final elegido = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: periodo.inicio.isBefore(hoy) ? periodo.inicio : hoy,
      lastDate: hoy,
      helpText: 'Fecha de la reunión',
    );
    if (elegido != null) setState(() => _dia = elegido);
  }

  Future<void> _abrirLista(Periodo periodo, Grupo grupo) async {
    final capId = ref.read(capIdProvider)!;
    final id = await ref
        .read(repoProvider)
        .asegurarReunion(capId, periodo.id, _dia);
    if (!mounted) return;
    abrir(
      context,
      PantallaPaseLista(
        reunion: Reunion(
          id: id,
          fecha: DateTime(_dia.year, _dia.month, _dia.day, 12),
          titulo: '',
          periodoId: periodo.id,
        ),
        grupo: grupo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capitulo = ref.watch(capituloProvider).value;
    final periodo = ref.watch(periodoActivoProvider);
    final periodosListos = ref.watch(periodosProvider).hasValue;

    return Scaffold(
      body: Column(
        children: [
          Encabezado(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Sobre una ficha blanca: el escudo es azul y sin ella
                    // se perdería contra el bloque azul.
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colores.blanco,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/emblema/escudo_4_embajador.png',
                        cacheHeight: 110,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        [
                          capitulo?.nombre ?? '',
                          capitulo?.iglesia ?? '',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colores.sobreAzul,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // La fecha cambia con un fundido al elegir otro día.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: curvaLlegada,
                  layoutBuilder: (actual, previos) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previos, ?actual],
                  ),
                  child: Text(
                    fechaLarga(_dia),
                    key: ValueKey(idDeFecha(_dia)),
                    style: titulo(32, color: Colores.blanco),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        periodo == null
                            ? 'Sin periodo activo'
                            : '${_esHoy ? 'Reunión de hoy' : 'Reunión pasada'}'
                                  ' · ${periodo.nombre}',
                        style: const TextStyle(color: Colores.sobreAzul),
                      ),
                    ),
                    if (periodo != null)
                      TextButton.icon(
                        onPressed: () => _elegirDia(periodo),
                        style: TextButton.styleFrom(
                          foregroundColor: Colores.tinta,
                          backgroundColor: Colores.oro,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(
                          PhosphorIconsBold.calendarCheck,
                          size: 18,
                        ),
                        label: const Text('Otra fecha'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Se ve siempre, haya o no periodo activo.
          if (ref.watch(actualizacionProvider).value case final nueva?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _AvisoActualizacion(nueva),
            ),
          Expanded(
            child: !periodosListos
                ? const Cargando()
                : periodo == null
                ? Vacio(
                    icono: PhosphorIconsBold.calendarX,
                    texto:
                        'Para empezar, crea el periodo (por ejemplo el '
                        'semestre) y arma los grupos.',
                    boton: 'Crear periodo',
                    alTocar: () => abrir(context, const PantallaPeriodos()),
                  )
                : _contenido(periodo),
          ),
        ],
      ),
    );
  }

  Widget _contenido(Periodo periodo) {
    final grupos = ref.watch(gruposProvider).value ?? const <Grupo>[];
    final activos = ref.watch(alumnosActivosProvider);
    final resumenes = ref.watch(resumenesPeriodoProvider);
    final uid = ref.watch(sesionProvider).value?.uid;

    // Primero los grupos del consejero.
    final ordenados = [...grupos]
      ..sort((a, b) {
        final ma = a.consejeroIds.contains(uid) ? 0 : 1;
        final mb = b.consejeroIds.contains(uid) ? 0 : 1;
        return ma != mb ? ma - mb : a.nombre.compareTo(b.nombre);
      });

    final sinGrupo = activos
        .where((a) => !grupos.any((g) => g.grados.contains(a.grado)))
        .length;

    final enAlerta =
        activos
            .where(
              (a) => (resumenes[a.id]?.faltasSeguidas ?? 0) >= faltasParaAlerta,
            )
            .toList()
          ..sort(
            (a, b) => resumenes[b.id]!.faltasSeguidas.compareTo(
              resumenes[a.id]!.faltasSeguidas,
            ),
          );

    final cumples = proximosCumples(activos, DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const TituloSeccion('Pasar lista'),
        if (grupos.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Este periodo aún no tiene grupos.'),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => abrir(context, const PantallaGrupos()),
                    child: const Text('Armar grupos'),
                  ),
                ],
              ),
            ),
          ),
        for (final (i, g) in ordenados.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Entrada(
              orden: i,
              child: _TarjetaGrupo(
                grupo: g,
                reunionId: idDeFecha(_dia),
                alumnoIds: {for (final a in alumnosDeGrupo(activos, g)) a.id},
                esMio: g.consejeroIds.contains(uid),
                alTocar: () => _abrirLista(periodo, g),
              ),
            ),
          ),
        if (sinGrupo > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              sinGrupo == 1
                  ? 'Hay 1 muchacho cuyo grado no está en ningún grupo.'
                  : 'Hay $sinGrupo muchachos cuyo grado no está en ningún '
                        'grupo.',
              style: const TextStyle(
                color: Colores.ambar,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (cumples.isNotEmpty) ...[
          const TituloSeccion('Cumpleaños'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final c in cumples)
                  ListTile(
                    tileColor: c.esHoy
                        ? Colores.oro.withValues(alpha: .18)
                        : null,
                    leading: FotoAlumno(
                      c.alumno,
                      heroe: 'cumple-${c.alumno.id}',
                    ),
                    title: Text(
                      c.alumno.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      c.esHoy
                          ? '¡Hoy cumple ${c.edad} años!'
                          : c.faltan == 1
                          ? 'Mañana cumple ${c.edad} años'
                          : '${fechaLarga(c.fecha)} · cumple ${c.edad}',
                    ),
                    trailing: Icon(
                      c.esHoy ? PhosphorIconsFill.cake : PhosphorIconsBold.cake,
                      color: c.esHoy ? Colores.azul : Colores.textoApagado,
                    ),
                    onTap: () => abrir(
                      context,
                      PantallaPerfilAlumno(
                        c.alumno.id,
                        heroe: 'cumple-${c.alumno.id}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (enAlerta.isNotEmpty) ...[
          const TituloSeccion('Faltas seguidas'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final a in enAlerta)
                  ListTile(
                    leading: FotoAlumno(a, heroe: 'alerta-${a.id}'),
                    title: Text(
                      a.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${resumenes[a.id]!.faltasSeguidas} reuniones sin venir',
                    ),
                    trailing: const Icon(PhosphorIconsBold.caretRight),
                    onTap: () => abrir(
                      context,
                      PantallaPerfilAlumno(a.id, heroe: 'alerta-${a.id}'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Aviso de que hay una versión más nueva de la app, con el botón para
/// descargarla. Al abrir el archivo descargado, Android la instala encima
/// de la actual sin perder la sesión ni los datos.
class _AvisoActualizacion extends StatelessWidget {
  const _AvisoActualizacion(this.nueva);

  final Actualizacion nueva;

  @override
  Widget build(BuildContext context) => Card(
    color: Colores.oro.withValues(alpha: .2),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsBold.arrowCircleUp, color: Colores.azul),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hay una versión nueva (${nueva.version})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Descárgala y ábrela para instalarla encima de esta. No se '
            'pierde nada: tu sesión y los datos se quedan.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(nueva.url),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(PhosphorIconsBold.downloadSimple),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    ),
  );
}

class _TarjetaGrupo extends ConsumerWidget {
  const _TarjetaGrupo({
    required this.grupo,
    required this.reunionId,
    required this.alumnoIds,
    required this.esMio,
    required this.alTocar,
  });

  final Grupo grupo;
  final String reunionId;

  /// Muchachos que hoy pertenecen al grupo.
  final Set<String> alumnoIds;
  final bool esMio;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref
        .watch(listaProvider((reunionId: reunionId, grupoId: grupo.id)))
        .value;
    final total = alumnoIds.length;
    // Solo cuentan los que siguen en el grupo: si un muchacho se graduó
    // después de pasar lista, su marca no debe inflar la cuenta.
    final presentes =
        lista?.registros.entries
            .where((e) => e.value.presente && alumnoIds.contains(e.key))
            .length ??
        0;
    final completo = lista != null && total > 0 && presentes == total;
    return Pulsable(
      alTocar: alTocar,
      child: Tarjeta(
        destacada: esMio,
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(grupo.nombre, style: titulo(20))),
                if (esMio)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colores.oro,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Tu grupo',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colores.tinta,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(PhosphorIconsBold.caretRight, color: Colores.acento),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              grupo.grados.map((g) => g.nombre).join(' · '),
              style: const TextStyle(color: Colores.textoSuave),
            ),
            const SizedBox(height: 14),
            BarraAvance(
              total == 0 ? 0 : presentes / total,
              color: completo ? Colores.verde : Colores.azul,
            ),
            const SizedBox(height: 8),
            Text(
              lista == null
                  ? 'Sin pasar lista · ${_muchachos(total)}'
                  : '$presentes de $total presentes · tomó '
                        '${lista.tomadaPorNombre}',
              style: TextStyle(
                color: lista == null
                    ? Colores.textoSuave
                    : completo
                    ? Colores.verde
                    : Colores.azul,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
