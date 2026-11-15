import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/iconos.dart';

import '../core/tema.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import '../widgets/movimiento.dart';

/// Bienvenida e inicio de sesión.
class PantallaAcceso extends ConsumerStatefulWidget {
  const PantallaAcceso({super.key});
  @override
  ConsumerState<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends ConsumerState<PantallaAcceso> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _registrando = false;
  bool _ocupado = false;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _hacer(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    await intentar(context, accion);
    if (mounted) setState(() => _ocupado = false);
  }

  void _enviar() {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(repoProvider);
    _hacer(
      () => _registrando
          ? repo.registrarConCorreo(_nombre.text, _correo.text, _clave.text)
          : repo.entrarConCorreo(_correo.text, _clave.text),
    );
  }

  Future<void> _recuperar() async {
    if (!_correo.text.contains('@')) {
      avisar(context, 'Escribe tu correo arriba y vuelve a tocar aquí.');
      return;
    }
    final ok = await intentar(
      context,
      () => ref.read(repoProvider).recuperarClave(_correo.text),
    );
    if (ok && mounted) {
      avisar(context, 'Te enviamos un correo para cambiar tu contraseña.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BloqueAzul(
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, medidas) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: medidas.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/emblema/escudo_4_embajador.png',
                            height: 132,
                            cacheHeight: 400,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Embajadores del Rey',
                            textAlign: TextAlign.center,
                            style: titulo(34, color: Colores.blanco),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '«Somos embajadores en nombre de Cristo»'
                            ' · 2 Corintios 5:20',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.4,
                              color: Colores.sobreAzul,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // La hoja del formulario sube al entrar.
                    Entrada(
                      orden: 2,
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colores.blanco,
                          border: Border(
                            top: BorderSide(color: Colores.oro, width: 5),
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          24,
                          28,
                          24,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Theme(
                              data: temaBase,
                              child: Builder(builder: _formulario),
                            ),
                          ),
                        ),
                      ),
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

  Widget _formulario(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _registrando ? 'Crea tu cuenta' : 'Inicia sesión',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _ocupado
              ? null
              : () => _hacer(ref.read(repoProvider).entrarConGoogle),
          icon: const Icon(PhosphorIconsBold.googleLogo),
          label: const Text('Continuar con Google'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'o con tu correo',
                  style: TextStyle(color: Colores.textoSuave),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        // El campo del nombre se despliega al cambiar a registro.
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: curvaLlegada,
          alignment: Alignment.topCenter,
          child: _registrando
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Tu nombre'),
                    validator: (v) => (v ?? '').trim().length < 2
                        ? 'Escribe tu nombre'
                        : null,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        TextFormField(
          controller: _correo,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Correo'),
          validator: (v) =>
              (v ?? '').contains('@') ? null : 'Escribe un correo válido',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _clave,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Contraseña'),
          validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
          onFieldSubmitted: (_) => _enviar(),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _ocupado ? null : _enviar,
          child: Text(_registrando ? 'Crear cuenta' : 'Entrar'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => setState(() => _registrando = !_registrando),
          child: Text(
            _registrando ? 'Ya tengo cuenta' : 'No tengo cuenta: registrarme',
          ),
        ),
        if (!_registrando)
          TextButton(
            onPressed: _recuperar,
            child: const Text('Olvidé mi contraseña'),
          ),
      ],
    ),
  );
}
