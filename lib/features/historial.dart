import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/asistencia.dart';
import '../core/historial.dart';
import '../core/iconos.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import 'alumnos.dart';

final _mes = DateFormat("MMMM 'de' yyyy", 'es');

String _tituloMes(DateTime d) {
  final s = _mes.format(d);
  return s[0].toUpperCase() + s.substring(1);
}

/// Historial de pases de lista: cada día de reunión con su asistencia, del
/// más reciente al más antiguo. Al tocar un día se ve quién fue y quién no.
class PantallaHistorial extends ConsumerWidget {
  const PantallaHistorial({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listas = ref.watch(todasLasListasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de listas')),
      body: listas.when(
        loading: () => const Cargando(),
        error: (e, _) => Vacio(
          icono: PhosphorIconsBold.cloudSlash,
          texto: mensajeDeError(e),
        ),
        data: (todas) {
          final dias = diasDeLista(todas);
          if (dias.isEmpty) {
            return const Vacio(
              icono: PhosphorIconsBold.clockCounterClockwise,
              texto:
                  'Aquí aparecerá cada día en que se pase lista, con quién '
                  'asistió y quién faltó.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: dias.length,
            itemBuilder: (context, i) {
              final dia = dias[i];
              // Un título por mes, antes del primer día de ese mes.
              final nuevoMes =
                  i == 0 ||
                  dias[i - 1].fecha.month != dia.fecha.month ||
                  dias[i - 1].fecha.year != dia.fecha.year;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (nuevoMes) TituloSeccion(_tituloMes(dia.fecha)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TarjetaDia(dia),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TarjetaDia extends StatelessWidget {
  const _TarjetaDia(this.dia);

  final DiaDeLista dia;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => abrir(context, _PantallaDia(dia.fecha)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fechaLarga(dia.fecha), style: titulo(17)),
                  const SizedBox(height: 4),
                  Text(
                    '${dia.presentes} de ${dia.anotados} presentes'
                    '${dia.ausentes > 0 ? ' · ${dia.ausentes == 1 ? 'faltó 1' : 'faltaron ${dia.ausentes}'}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${dia.conBiblia} con Biblia',
                      if (dia.ofrenda > 0) 'Ofrenda ${dinero(dia.ofrenda)}',
                      dia.listas.length == 1
                          ? '1 grupo'
                          : '${dia.listas.length} grupos',
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
            PildoraPorcentaje(dia.porcentaje),
            const SizedBox(width: 4),
            const Icon(PhosphorIconsBold.caretRight),
          ],
        ),
      ),
    ),
  );
}

/// Un día de reunión: cada grupo con sus muchachos, presentes y ausentes.
class _PantallaDia extends ConsumerWidget {
  const _PantallaDia(this.fecha);

  final DateTime fecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se lee del flujo en vivo: si alguien corrige la lista, aquí cambia.
    final dias = diasDeLista(ref.watch(todasLasListasProvider).value ?? []);
    final dia = dias.where((d) => d.fecha == fecha).firstOrNull;
    final alumnos = {
      for (final a in ref.watch(alumnosProvider).value ?? const <Alumno>[])
        a.id: a,
    };
    final grupos = {
      for (final g
          in ref.watch(todosLosGruposProvider).value ?? const <Grupo>[])
        g.id: g,
    };

    return Scaffold(
      appBar: AppBar(title: Text(fechaLargaConAnio(fecha))),
      body: dia == null
          ? const Vacio(
              icono: PhosphorIconsBold.clockCounterClockwise,
              texto: 'Ya no hay listas de este día.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        _Dato('${dia.presentes}', 'Presentes', Colores.verde),
                        _Dato('${dia.ausentes}', 'Faltaron', Colores.rojo),
                        _Dato('${dia.conBiblia}', 'Con Biblia', Colores.azul),
                        _Dato(dinero(dia.ofrenda), 'Ofrenda', Colores.azul),
                      ],
                    ),
                  ),
                ),
                for (final lista
                    in [...dia.listas]..sort(
                      (a, b) => (grupos[a.grupoId]?.nombre ?? '').compareTo(
                        grupos[b.grupoId]?.nombre ?? '',
                      ),
                    ))
                  ..._grupo(context, lista, grupos[lista.grupoId], alumnos),
              ],
            ),
    );
  }

  List<Widget> _grupo(
    BuildContext context,
    Lista lista,
    Grupo? grupo,
    Map<String, Alumno> alumnos,
  ) {
    String nombre(String id) => alumnos[id]?.nombre ?? 'Muchacho borrado';
    // Primero los presentes; dentro de cada parte, por nombre.
    final ids = lista.registros.keys.toList()
      ..sort((a, b) {
        final pa = lista.registros[a]!.presente ? 0 : 1;
        final pb = lista.registros[b]!.presente ? 0 : 1;
        return pa != pb
            ? pa - pb
            : nombre(a).toLowerCase().compareTo(nombre(b).toLowerCase());
      });
    return [
      TituloSeccion(grupo?.nombre ?? 'Grupo de otro periodo'),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final id in ids)
              _FilaAsistencia(
                alumno: alumnos[id],
                nombre: nombre(id),
                registro: lista.registros[id]!,
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          '${lista.presentes} de ${lista.registros.length} presentes'
          '${lista.tomadaPorNombre.isEmpty ? '' : ' · tomó ${lista.tomadaPorNombre}'}',
          style: const TextStyle(fontSize: 12.5, color: Colores.textoSuave),
        ),
      ),
    ];
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.valor, this.etiqueta, this.color);

  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(valor, style: titulo(22, color: color)),
        ),
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 12, color: Colores.textoSuave),
        ),
      ],
    ),
  );
}

class _FilaAsistencia extends StatelessWidget {
  const _FilaAsistencia({
    required this.alumno,
    required this.nombre,
    required this.registro,
  });

  /// Null si el muchacho ya fue borrado del capítulo.
  final Alumno? alumno;
  final String nombre;
  final Registro registro;

  @override
  Widget build(BuildContext context) {
    final a = alumno;
    final detalles = [
      if (registro.biblia) 'Biblia',
      if (registro.monto > 0)
        'Ofrenda ${dinero(registro.monto)}'
      else if (registro.ofrenda)
        'Ofrenda',
    ];
    return ListTile(
      leading: a == null
          ? FotoPersona(nombre, null)
          : FotoAlumno(a, heroe: 'historial-${a.id}'),
      title: Text(
        nombre,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: registro.presente ? Colores.tinta : Colores.textoSuave,
        ),
      ),
      subtitle: Text(
        registro.presente
            ? (detalles.isEmpty ? 'Presente' : detalles.join(' · '))
            : 'Faltó',
      ),
      trailing: Semantics(
        label: registro.presente ? 'Presente' : 'Faltó',
        child: Icon(
          registro.presente
              ? PhosphorIconsFill.checkCircle
              : PhosphorIconsFill.xCircle,
          color: registro.presente ? Colores.verde : Colores.rojo,
          size: 26,
        ),
      ),
      onTap: a == null
          ? null
          : () => abrir(
              context,
              PantallaPerfilAlumno(a.id, heroe: 'historial-${a.id}'),
            ),
    );
  }
}
