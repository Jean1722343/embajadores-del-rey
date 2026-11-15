import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/exportar.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import 'alumnos.dart';

/// Porcentajes por muchacho y por grupo, con exportación a PDF y Excel.
class PantallaReportes extends ConsumerStatefulWidget {
  const PantallaReportes({super.key});
  @override
  ConsumerState<PantallaReportes> createState() => _PantallaReportesState();
}

class _PantallaReportesState extends ConsumerState<PantallaReportes> {
  /// Rango elegido a mano; si es null se usa el periodo activo.
  Rango? _rango;
  String? _grupoId;
  bool _exportando = false;

  Future<void> _elegirRango(Rango actual) async {
    final hoy = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoy.year - 5),
      lastDate: DateTime(hoy.year + 1),
      initialDateRange: DateTimeRange(start: actual.desde, end: actual.hasta),
      helpText: 'Fechas del reporte',
    );
    if (r == null) return;
    setState(
      () => _rango = (
        desde: DateTime(r.start.year, r.start.month, r.start.day),
        hasta: DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59),
      ),
    );
  }

  Future<void> _exportar(Future<void> Function() accion) async {
    setState(() => _exportando = true);
    await intentar(context, accion);
    if (mounted) setState(() => _exportando = false);
  }

  @override
  Widget build(BuildContext context) {
    final rango = _rango ?? ref.watch(rangoPeriodoProvider);
    if (rango == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reportes')),
        body: const Vacio(
          icono: PhosphorIconsFill.chartBar,
          texto:
              'Cuando haya un periodo activo, aquí verás los porcentajes '
              'de asistencia.',
        ),
      );
    }

    final grupos = ref.watch(gruposProvider).value ?? const <Grupo>[];
    final grupo = grupos.where((g) => g.id == _grupoId).firstOrNull;
    final listas = ref.watch(listasProvider(rango));
    final activos = ref.watch(alumnosActivosProvider);
    final alumnos = grupo == null ? activos : alumnosDeGrupo(activos, grupo);

    final reporte = Reporte(
      capitulo: ref.watch(capituloProvider).value?.nombre ?? '',
      titulo: grupo?.nombre ?? 'Todos los grupos',
      desde: rango.desde,
      hasta: rango.hasta,
      alumnos: alumnos,
      resumenes: resumirPorAlumno(listas.value ?? const []),
      listas: listas.value ?? const [],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            tooltip: 'Exportar a PDF',
            icon: const Icon(PhosphorIconsBold.filePdf),
            onPressed: _exportando || alumnos.isEmpty
                ? null
                : () => _exportar(() => compartirPdf(reporte)),
          ),
          IconButton(
            tooltip: 'Exportar a Excel',
            icon: const Icon(PhosphorIconsBold.microsoftExcelLogo),
            onPressed: _exportando || alumnos.isEmpty
                ? null
                : () => _exportar(() => compartirExcel(reporte)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                PhosphorIconsBold.calendar,
                color: Colores.acento,
              ),
              title: Text(
                '${fechaCorta(rango.desde)} – ${fechaCorta(rango.hasta)}',
              ),
              subtitle: Text(
                _rango == null ? 'Periodo activo' : 'Fechas elegidas',
              ),
              trailing: TextButton(
                onPressed: () => _elegirRango(rango),
                child: const Text('Cambiar'),
              ),
            ),
          ),
          if (grupos.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: grupo == null,
                      onSelected: (_) => setState(() => _grupoId = null),
                    ),
                  ),
                  for (final g in grupos)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(g.nombre),
                        selected: g.id == _grupoId,
                        onSelected: (_) => setState(() => _grupoId = g.id),
                      ),
                    ),
                ],
              ),
            ),
          if (listas.isLoading && !listas.hasValue)
            const Padding(padding: EdgeInsets.all(32), child: Cargando())
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Cifra('${reporte.dias.length}', 'Reuniones'),
                    _Cifra('${alumnos.length}', 'Muchachos'),
                    _Cifra(
                      reporte.promedio == null
                          ? '—'
                          : '${reporte.promedio!.round()} %',
                      'Promedio',
                      color: colorPorcentaje(reporte.promedio),
                    ),
                  ],
                ),
              ),
            ),
            const TituloSeccion('Por muchacho'),
            Card(
              child: Column(
                children: [
                  for (final a in alumnos)
                    ListTile(
                      leading: FotoAlumno(a, heroe: 'reporte-${a.id}'),
                      title: Text(a.nombre),
                      subtitle: Text(
                        reporte.de(a).reuniones == 0
                            ? 'Sin pases de lista'
                            : '${reporte.de(a).asistencias} de '
                                  '${reporte.de(a).reuniones} · '
                                  'Biblia ${reporte.de(a).biblias} · '
                                  'Ofrenda ${reporte.de(a).ofrendas}',
                      ),
                      trailing: PildoraPorcentaje(reporte.de(a).porcentaje),
                      onTap: () => abrir(
                        context,
                        PantallaPerfilAlumno(a.id, heroe: 'reporte-${a.id}'),
                      ),
                    ),
                  if (alumnos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay muchachos en este grupo.'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.valor, this.etiqueta, {this.color = Colores.texto});

  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(valor, style: titulo(28, color: color)),
      Text(etiqueta),
    ],
  );
}
