import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/caja.dart';
import '../core/iconos.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/exportar.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import '../widgets/movimiento.dart';

/// Estado de la caja a partir de todas las listas y los movimientos.
final cajaProvider = Provider<EstadoCaja>((ref) {
  final listas = ref.watch(todasLasListasProvider).value ?? const <Lista>[];
  final movimientos =
      ref.watch(movimientosProvider).value ?? const <Movimiento>[];
  return calcularCaja(listas, movimientos);
});

/// Caja del capítulo: saldo, meter y sacar dinero, y el libro de todo lo
/// que ha entrado y salido.
class PantallaCaja extends ConsumerWidget {
  const PantallaCaja({super.key});

  void _abrirFormulario(BuildContext context, bool esIngreso) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HojaMovimiento(esIngreso: esIngreso),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caja = ref.watch(cajaProvider);
    final cargando =
        !ref.watch(todasLasListasProvider).hasValue ||
        !ref.watch(movimientosProvider).hasValue;
    final capitulo = ref.watch(capituloProvider).value?.nombre ?? '';

    return Scaffold(
      body: Column(
        children: [
          Encabezado(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Caja del capítulo',
                        style: TextStyle(
                          color: Colores.sobreAzul,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reporte en PDF',
                      icon: const Icon(PhosphorIconsBold.filePdf),
                      onPressed: caja.asientos.isEmpty
                          ? null
                          : () => intentar(
                              context,
                              () => compartirCajaPdf(caja, capitulo),
                            ),
                    ),
                    IconButton(
                      tooltip: 'Reporte en Excel',
                      icon: const Icon(PhosphorIconsBold.microsoftExcelLogo),
                      onPressed: caja.asientos.isEmpty
                          ? null
                          : () => intentar(
                              context,
                              () => compartirCajaExcel(caja, capitulo),
                            ),
                    ),
                  ],
                ),
                const Text(
                  'Saldo',
                  style: TextStyle(color: Colores.sobreAzul, fontSize: 13),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        // El saldo cuenta hasta su valor cuando cambia.
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: caja.saldo),
                          duration: sinMovimiento(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 700),
                          curve: curvaLlegada,
                          builder: (_, v, _) => Text(
                            dinero(v),
                            style:
                                titulo(
                                  46,
                                  color: caja.saldo < 0
                                      ? Colores.oro
                                      : Colores.blanco,
                                ).copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                    // Tendencia del saldo, movimiento por movimiento.
                    if (caja.asientos.length >= 2) ...[
                      const SizedBox(width: 14),
                      MiniGraficaSaldo(caja.historialSaldo),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Total('Ofrendas', caja.ofrendas),
                    _Total('Otros ingresos', caja.ingresos),
                    _Total('Salidas', caja.egresos),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: BotonOro(
                        texto: 'Meter dinero',
                        icono: PhosphorIconsBold.arrowDown,
                        alTocar: () => _abrirFormulario(context, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _abrirFormulario(context, false),
                        icon: const Icon(PhosphorIconsBold.arrowUp),
                        label: const Text('Sacar dinero'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: cargando
                ? const Cargando()
                : caja.asientos.isEmpty
                ? const Vacio(
                    icono: PhosphorIconsBold.piggyBank,
                    texto:
                        'Aquí se junta lo que ofrendan los muchachos al pasar '
                        'lista, y lo que entre o salga de la caja.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: caja.asientos.length + 1,
                    separatorBuilder: (_, i) =>
                        i == 0 ? const SizedBox.shrink() : const Divider(),
                    itemBuilder: (context, i) {
                      if (i == 0) return const TituloSeccion('Movimientos');
                      final asiento = caja.asientos[i - 1];
                      final fila = _FilaAsiento(asiento);
                      return i <= 9 ? Entrada(orden: i - 1, child: fila) : fila;
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.etiqueta, this.monto);

  final String etiqueta;
  final double monto;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dinero(monto),
          style: const TextStyle(
            fontFamily: Fuentes.titulos,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colores.blanco,
          ),
        ),
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 12, color: Colores.sobreAzul),
        ),
      ],
    ),
  );
}

class _FilaAsiento extends ConsumerWidget {
  const _FilaAsiento(this.asiento);

  final Asiento asiento;

  static const _iconos = {
    TipoAsiento.ofrenda: PhosphorIconsBold.handHeart,
    TipoAsiento.ingreso: PhosphorIconsBold.arrowDown,
    TipoAsiento.egreso: PhosphorIconsBold.arrowUp,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: CircleAvatar(
      backgroundColor: asiento.entra ? Colores.nube : const Color(0xFFFBE9E7),
      child: Icon(
        _iconos[asiento.tipo],
        size: 20,
        color: asiento.entra ? Colores.azul : Colores.rojo,
      ),
    ),
    title: Text(
      asiento.concepto,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      [
        fechaCorta(asiento.fecha),
        if (asiento.quien.isNotEmpty) asiento.quien,
      ].join(' · '),
    ),
    trailing: Text(
      '${asiento.entra ? '+' : '−'} ${dinero(asiento.monto)}',
      style: TextStyle(
        fontFamily: Fuentes.titulos,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: asiento.entra ? Colores.verde : Colores.rojo,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HojaDetalle(asiento),
    ),
  );
}

/// Detalle de un asiento: quién ofrendó cuánto, o los datos del movimiento
/// (que el líder puede borrar).
class _HojaDetalle extends ConsumerWidget {
  const _HojaDetalle(this.asiento);

  final Asiento asiento;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alumnos = {
      for (final a in ref.watch(alumnosProvider).value ?? const <Alumno>[])
        a.id: a,
    };
    // Lo que ofrendó cada muchacho ese día, de mayor a menor.
    final porMuchacho = <String, double>{};
    for (final l in asiento.listas) {
      l.registros.forEach((id, r) {
        if (r.monto > 0) {
          porMuchacho[id] = (porMuchacho[id] ?? 0) + r.monto;
        }
      });
    }
    final orden = porMuchacho.keys.toList()
      ..sort((a, b) => porMuchacho[b]!.compareTo(porMuchacho[a]!));
    final movimiento = asiento.movimiento;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${asiento.entra ? '+' : '−'} ${dinero(asiento.monto)}',
                    style: titulo(
                      34,
                      color: asiento.entra ? Colores.verde : Colores.rojo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    asiento.concepto,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      fechaLarga(asiento.fecha),
                      if (asiento.quien.isNotEmpty) 'registró ${asiento.quien}',
                    ].join(' · '),
                    style: const TextStyle(color: Colores.textoSuave),
                  ),
                ],
              ),
            ),
            if (orden.isNotEmpty)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final id in orden)
                      ListTile(
                        dense: true,
                        leading: alumnos[id] == null
                            ? const CircleAvatar(
                                backgroundColor: Colores.nube,
                                child: Icon(PhosphorIconsFill.user, size: 18),
                              )
                            : FotoAlumno(alumnos[id]!, radio: 18),
                        title: Text(alumnos[id]?.nombre ?? 'Muchacho borrado'),
                        trailing: Text(
                          dinero(porMuchacho[id]!),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (movimiento != null && ref.watch(esLiderProvider))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colores.rojo),
                  icon: const Icon(PhosphorIconsBold.trash),
                  label: const Text('Borrar este movimiento'),
                  onPressed: () async {
                    final si = await confirmar(
                      context,
                      titulo: 'Borrar movimiento',
                      texto:
                          'Se quita de la caja para todos y el saldo cambia. '
                          'Úsalo solo si se registró por error.',
                      aceptar: 'Borrar',
                    );
                    if (!si || !context.mounted) return;
                    final ok = await intentar(
                      context,
                      () => ref
                          .read(repoProvider)
                          .borrarMovimiento(
                            ref.read(capIdProvider)!,
                            movimiento.id,
                          ),
                    );
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                ),
              )
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Formulario para meter o sacar dinero.
class _HojaMovimiento extends ConsumerStatefulWidget {
  const _HojaMovimiento({required this.esIngreso});

  final bool esIngreso;

  @override
  ConsumerState<_HojaMovimiento> createState() => _HojaMovimientoState();
}

class _HojaMovimientoState extends ConsumerState<_HojaMovimiento> {
  final _monto = TextEditingController();
  final _concepto = TextEditingController();
  DateTime _fecha = DateTime.now();
  String? _error;

  static const _sugerenciasIngreso = [
    'Venta de comida',
    'Donación',
    'Actividad',
    'Cooperación',
    'Apoyo de la iglesia',
  ];
  static const _sugerenciasEgreso = [
    'Material',
    'Convivio',
    'Campamento',
    'Uniformes',
    'Premios',
    'Misiones',
  ];

  @override
  void dispose() {
    _monto.dispose();
    _concepto.dispose();
    super.dispose();
  }

  void _guardar() {
    final monto = double.tryParse(_monto.text.replaceAll(',', '.')) ?? 0;
    final saldo = ref.read(cajaProvider).saldo;
    String? error;
    if (monto <= 0) {
      error = 'Escribe la cantidad.';
    } else if (_concepto.text.trim().isEmpty) {
      error = widget.esIngreso
          ? 'Escribe cómo se consiguió.'
          : 'Escribe para qué se saca.';
    } else if (!widget.esIngreso && monto > saldo) {
      error = 'En caja solo hay ${dinero(saldo)}.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    HapticFeedback.mediumImpact();
    ref
        .read(repoProvider)
        .registrarMovimiento(
          capId: ref.read(capIdProvider)!,
          esIngreso: widget.esIngreso,
          monto: monto,
          concepto: _concepto.text,
          fecha: _fecha,
          miNombre: ref.read(miNombreProvider),
        );
    Navigator.pop(context);
    avisar(
      context,
      widget.esIngreso
          ? 'Entraron ${dinero(monto)} a la caja.'
          : 'Salieron ${dinero(monto)} de la caja.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ingreso = widget.esIngreso;
    return SafeArea(
      child: Padding(
        // La hoja sube con el teclado.
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ingreso ? 'Meter dinero' : 'Sacar dinero',
                style: titulo(26),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _monto,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: titulo(28),
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _concepto,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: ingreso
                      ? '¿Cómo se consiguió?'
                      : '¿Para qué se saca?',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final s
                      in ingreso ? _sugerenciasIngreso : _sugerenciasEgreso)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() => _concepto.text = s),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final hoy = DateTime.now();
                  final f = await showDatePicker(
                    context: context,
                    initialDate: _fecha,
                    firstDate: DateTime(hoy.year - 2),
                    lastDate: hoy,
                  );
                  if (f != null) setState(() => _fecha = f);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    suffixIcon: Icon(PhosphorIconsBold.calendarBlank, size: 20),
                  ),
                  child: Text(fechaCorta(_fecha)),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colores.rojo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _guardar,
                icon: Icon(
                  ingreso
                      ? PhosphorIconsBold.arrowDown
                      : PhosphorIconsBold.arrowUp,
                ),
                label: Text(ingreso ? 'Meter a la caja' : 'Sacar de la caja'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Línea pequeña con la tendencia del saldo, para ir junto a la cifra. Es
/// una sola serie: la cifra de al lado da el valor y esto solo la forma.
class MiniGraficaSaldo extends StatelessWidget {
  const MiniGraficaSaldo(this.valores, {super.key});

  final List<double> valores;

  @override
  Widget build(BuildContext context) {
    final sube = valores.last >= valores[valores.length - 2];
    return Semantics(
      label:
          'Tendencia del saldo en ${valores.length - 1} movimientos: '
          'el último ${sube ? 'lo subió' : 'lo bajó'}.',
      // La línea se traza de izquierda a derecha al aparecer.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: sinMovimiento(context)
            ? Duration.zero
            : const Duration(milliseconds: 900),
        curve: curvaLlegada,
        builder: (_, avance, _) => CustomPaint(
          size: const Size(124, 54),
          painter: _LineaSaldo(valores, avance),
        ),
      ),
    );
  }
}

class _LineaSaldo extends CustomPainter {
  const _LineaSaldo(this.valores, this.avance);

  final List<double> valores;
  final double avance;

  @override
  void paint(Canvas canvas, Size size) {
    const margen = 6.0;
    var minimo = valores.reduce((a, b) => a < b ? a : b);
    var maximo = valores.reduce((a, b) => a > b ? a : b);
    if (maximo == minimo) {
      maximo += 1;
      minimo -= 1;
    }
    final paso = (size.width - margen * 2) / (valores.length - 1);
    Offset punto(int i) => Offset(
      margen + paso * i,
      margen +
          (size.height - margen * 2) *
              (1 - (valores[i] - minimo) / (maximo - minimo)),
    );

    final linea = Path()..moveTo(punto(0).dx, punto(0).dy);
    for (var i = 1; i < valores.length; i++) {
      linea.lineTo(punto(i).dx, punto(i).dy);
    }
    final ultimo = punto(valores.length - 1);

    // Recorte que avanza para trazar la línea.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * avance, size.height));

    // Área tenue bajo la línea.
    final area = Path.from(linea)
      ..lineTo(ultimo.dx, size.height)
      ..lineTo(punto(0).dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = const Color(0x29F2B705));

    canvas.drawPath(
      linea,
      Paint()
        ..color = Colores.oro
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Punto del saldo actual, con anillo del color del fondo.
    if (avance > 0.98) {
      canvas.drawCircle(ultimo, 6, Paint()..color = Colores.azul);
      canvas.drawCircle(ultimo, 4, Paint()..color = Colores.oro);
    }
  }

  @override
  bool shouldRepaint(_LineaSaldo anterior) =>
      anterior.avance != avance || anterior.valores != valores;
}
