import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import '../core/tema.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import '../widgets/movimiento.dart';

/// Lo que ve quien todavía no pertenece a ningún capítulo.
class PantallaSinCapitulo extends ConsumerWidget {
  const PantallaSinCapitulo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(perfilProvider).value?.nombre ?? '';
    return Scaffold(
      body: BloqueAzul(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/emblema/escudo_4_embajador.png',
                      height: 120,
                      cacheHeight: 360,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Bienvenido${nombre.isEmpty ? '' : ', ${nombre.split(' ').first}'}',
                      textAlign: TextAlign.center,
                      style: titulo(30, color: Colores.blanco),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Si tu líder te mandó un código, úsalo para entrar a tu '
                      'capítulo. Si tú diriges el capítulo, créalo aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: Colores.sobreAzul,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Entrada(
                      orden: 1,
                      child: BotonOro(
                        texto: 'Tengo un código',
                        icono: PhosphorIconsBold.key,
                        alTocar: () => abrir(context, const PantallaCodigo()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Entrada(
                      orden: 2,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            abrir(context, const PantallaCrearCapitulo()),
                        icon: const Icon(PhosphorIconsBold.buildings),
                        label: const Text('Crear mi capítulo'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.read(repoProvider).salir(),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso cuando el capítulo abierto ya no está disponible para el usuario.
class PantallaSinAcceso extends ConsumerWidget {
  const PantallaSinAcceso(this.motivo, {super.key});

  final String motivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(PhosphorIconsBold.lock, size: 56, color: Colores.azul),
            const SizedBox(height: 12),
            Text(
              motivo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => abrir(context, const PantallaCodigo()),
              child: const Text('Entrar con otro código'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => abrir(context, const PantallaCrearCapitulo()),
              child: const Text('Crear un capítulo'),
            ),
            TextButton(
              onPressed: () => ref.read(repoProvider).salir(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    ),
  );
}

class PantallaCodigo extends ConsumerStatefulWidget {
  const PantallaCodigo({super.key});
  @override
  ConsumerState<PantallaCodigo> createState() => _PantallaCodigoState();
}

class _PantallaCodigoState extends ConsumerState<PantallaCodigo> {
  final _codigo = TextEditingController();
  bool _ocupado = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() => _ocupado = true);
    final nombre = ref.read(perfilProvider).value?.nombre ?? 'Consejero';
    final ok = await intentar(
      context,
      () => ref.read(repoProvider).unirseConCodigo(_codigo.text, nombre),
    );
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (ok) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Código de invitación')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Escribe el código de 6 caracteres que te mandó el líder de tu '
          'capítulo.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codigo,
          autofocus: true,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          ],
          style: const TextStyle(
            fontSize: 28,
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
          ),
          decoration: const InputDecoration(hintText: '······'),
          onSubmitted: (_) => _entrar(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _ocupado ? null : _entrar,
          child: const Text('Entrar al capítulo'),
        ),
      ],
    ),
  );
}

class PantallaCrearCapitulo extends ConsumerStatefulWidget {
  const PantallaCrearCapitulo({super.key});
  @override
  ConsumerState<PantallaCrearCapitulo> createState() =>
      _PantallaCrearCapituloState();
}

class _PantallaCrearCapituloState extends ConsumerState<PantallaCrearCapitulo> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _iglesia = TextEditingController();
  final _ciudad = TextEditingController();
  final _estado = TextEditingController();
  bool _permiso = false;
  bool _ocupado = false;

  @override
  void dispose() {
    for (final c in [_nombre, _iglesia, _ciudad, _estado]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    if (!_permiso) {
      avisar(context, 'Marca la casilla del permiso de los padres.');
      return;
    }
    setState(() => _ocupado = true);
    final ok = await intentar(
      context,
      () => ref
          .read(repoProvider)
          .crearCapitulo(
            miNombre: ref.read(perfilProvider).value?.nombre ?? 'Líder',
            nombre: _nombre.text,
            iglesia: _iglesia.text,
            ciudad: _ciudad.text,
            estado: _estado.text,
          ),
    );
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (ok) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  String? _requerido(String? v) =>
      (v ?? '').trim().isEmpty ? 'Este dato hace falta' : null;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nuevo capítulo')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Quedarás como líder del capítulo: podrás invitar consejeros, '
            'armar los grupos y dar de alta a los muchachos.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Nombre del capítulo',
              helperText: 'Por lo general, el nombre de un misionero',
            ),
            validator: _requerido,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _iglesia,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Iglesia'),
            validator: _requerido,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ciudad,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ciudad'),
            validator: _requerido,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _estado,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Estado'),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _permiso,
            onChanged: (v) => setState(() => _permiso = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Aquí se guardan datos y fotos de menores. Me comprometo a '
              'contar con el permiso de sus padres o tutores.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _ocupado ? null : _crear,
            child: const Text('Crear capítulo'),
          ),
        ],
      ),
    ),
  );
}
