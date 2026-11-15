import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/grados.dart';
import '../core/iconos.dart';
import '../core/manual.dart';
import '../core/tema.dart';
import '../widgets/comunes.dart';
import '../widgets/movimiento.dart';

const _sitio = 'https://www.embajadoresdelreymex.org';

/// Página oficial de cada grado.
const _paginaDeGrado = {
  Grado.aspirante: '$_sitio/el-manual-y-sus-proyectos/1-aspirante',
  Grado.miembro: '$_sitio/el-manual-y-sus-proyectos/2-miembro',
  Grado.paje: '$_sitio/el-manual-y-sus-proyectos/3-paje',
  Grado.escudero: '$_sitio/el-manual-y-sus-proyectos/4-escudero',
  Grado.caballero: '$_sitio/el-manual-y-sus-proyectos/5-caballero',
  Grado.embajador: '$_sitio/el-manual-y-sus-proyectos/6-embajador',
  Grado.embajadorEnServicio:
      '$_sitio/el-manual-y-sus-proyectos/7-embajador-en-servicio',
  Grado.embajadorExtraordinario:
      '$_sitio/el-manual-y-sus-proyectos/8-embajador-extraordinario',
  Grado.embajadorPlenipotenciario:
      '$_sitio/el-manual-y-sus-proyectos/9-embajador-plenipotenciario',
};

/// Cuadernillo de trabajo que el sitio oficial ofrece para cada grado.
const _cuadernillo = {
  Grado.aspirante: 'https://mega.nz/file/PBUCCZBZ#8SycxQQX7hVL0YjcwXFbwQpw2R3nbt21-zPyiBiF_Mc',
  Grado.miembro: 'https://mega.nz/file/PBUCCZBZ#8SycxQQX7hVL0YjcwXFbwQpw2R3nbt21-zPyiBiF_Mc',
  Grado.paje: 'https://mega.nz/file/DFtD1IaQ#kQcbFJlPlxEqSIasNxTLRz-Ib6EPUDYOhdtfOPdyYE8',
  Grado.escudero: 'https://mega.nz/file/KZ8BmIqC#exKYI6lpl6juCjcOMelNz45L-d-UnOt57LgkwfDzfu0',
  Grado.caballero: 'https://mega.nz/file/KQ83nAyZ#npWjpF02Afe1PnoEeBjYbvGgDFQ6W_0ddTJxouYFuMY',
  Grado.embajador: 'https://mega.nz/file/zF8xCI6Z#4Wxt2mPCwT6fl2-mgIkRugZSvYLj8g9NH-OL-V6eHPk',
};

const _manualDelCapitulo =
    'https://drive.google.com/file/d/1xcvXUpOMul3y51e4Y-w1rZJ0cO_M4WLv/view';

Future<void> _abrirEnlace(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) {
    avisar(context, 'No se pudo abrir. Revisa tu conexión.');
  }
}

/// Biblioteca: lo esencial de la Orden y los requisitos de cada grado van
/// dentro de la app (funcionan sin internet); los cuadernillos y demás
/// material se abren desde su enlace oficial, para no ocupar espacio.
class PantallaBiblioteca extends StatelessWidget {
  const PantallaBiblioteca({super.key});

  @override
  Widget build(BuildContext context) {
    final grados = Grado.values.where((g) => g != Grado.nuevo).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const TituloSeccion('Lo esencial de la Orden'),
          const _Nota(
            PhosphorIconsBold.wifiSlash,
            'Esta parte va dentro de la app y se lee sin internet.',
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, tema) in _temas.indexed)
                  Entrada(
                    orden: i,
                    child: ListTile(
                      leading: Icon(tema.icono),
                      title: Text(
                        tema.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(tema.resumen),
                      trailing: const Icon(PhosphorIconsBold.caretRight),
                      onTap: () => abrir(context, _PantallaTema(tema)),
                    ),
                  ),
              ],
            ),
          ),
          const TituloSeccion('Grados y requisitos'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final g in grados)
                  ListTile(
                    leading: SizedBox(
                      width: 34,
                      child: EscudoArmable(etapa: g.etapaEscudo, alto: 40),
                    ),
                    title: Text(
                      g.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(_resumenDeGrado(g)),
                    trailing: const Icon(PhosphorIconsBold.caretRight),
                    onTap: () => abrir(context, _PantallaGrado(g)),
                  ),
              ],
            ),
          ),
          const TituloSeccion('Descargas opcionales'),
          const _Nota(
            PhosphorIconsBold.downloadSimple,
            'Se abren desde su enlace oficial y no ocupan espacio en la app; '
            'baja solo lo que necesites.',
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _Enlace(
                  icono: PhosphorIconsBold.books,
                  titulo: 'Manual del capítulo',
                  detalle: 'PDF en Google Drive',
                  url: _manualDelCapitulo,
                ),
                for (final e in _cuadernillo.entries)
                  // Aspirante y Miembro comparten cuadernillo.
                  if (e.key != Grado.miembro)
                    _Enlace(
                      icono: PhosphorIconsBold.downloadSimple,
                      titulo: e.key == Grado.aspirante
                          ? 'Cuadernillo de Aspirante y Miembro'
                          : 'Cuadernillo de ${e.key.nombre}',
                      detalle: 'Archivo en Mega',
                      url: e.value,
                    ),
              ],
            ),
          ),
          const TituloSeccion('En el sitio oficial'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: const [
                _Enlace(
                  icono: PhosphorIconsBold.musicNotes,
                  titulo: 'Himno y lema',
                  detalle: '«En los negocios del Rey»',
                  url: '$_sitio/himno-lema',
                ),
                _Enlace(
                  icono: PhosphorIconsBold.microphoneStage,
                  titulo: 'Coritario de alabanzas',
                  url: '$_sitio/coritario-de-alabanzas',
                ),
                _Enlace(
                  icono: PhosphorIconsBold.bookOpenText,
                  titulo: 'Libros de estudio misionero',
                  detalle: 'Lecturas recomendadas',
                  url: '$_sitio/libros-recomendados-de-estudio-misionero',
                ),
                _Enlace(
                  icono: PhosphorIconsBold.globeHemisphereWest,
                  titulo: 'Lista de misioneros',
                  url: '$_sitio/lista-de-misioneros-cnbm-unfbmm-unvbmm',
                ),
                _Enlace(
                  icono: PhosphorIconsBold.gameController,
                  titulo: 'Juegos para aprender',
                  url: '$_sitio/juegos-interactivos-para-aprender',
                ),
                _Enlace(
                  icono: PhosphorIconsBold.tent,
                  titulo: 'Campamento nacional',
                  url: '$_sitio/campamento-nacional',
                ),
                _Enlace(
                  icono: PhosphorIconsBold.identificationBadge,
                  titulo: 'Consejero de los Embajadores',
                  detalle: 'Requisitos y funciones',
                  url:
                      '$_sitio/el-manual-y-sus-proyectos/'
                      'consejero-de-los-embajadores-del-rey',
                ),
                _Enlace(
                  icono: PhosphorIconsBold.house,
                  titulo: 'Página principal',
                  detalle: 'embajadoresdelreymex.org',
                  url: _sitio,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _resumenDeGrado(Grado g) {
  final manual = Manual.para(g);
  final enMetas = manual.metas.values.fold(0, (n, lista) => n + lista.length);
  final total = manual.generales.length + enMetas;
  if (total == 0) return 'Ver en el sitio oficial';
  return enMetas > 0 ? '$total requisitos en cinco metas' : '$total requisitos';
}

class _Nota extends StatelessWidget {
  const _Nota(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: Colores.textoSuave),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 13.5, color: Colores.textoSuave),
          ),
        ),
      ],
    ),
  );
}

/// Renglón que abre un enlace oficial fuera de la app.
class _Enlace extends StatelessWidget {
  const _Enlace({
    required this.icono,
    required this.titulo,
    required this.url,
    this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String? detalle;
  final String url;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icono),
    title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: detalle == null ? null : Text(detalle!),
    trailing: const Icon(
      PhosphorIconsBold.arrowSquareOut,
      size: 20,
      color: Colores.textoSuave,
    ),
    onTap: () => _abrirEnlace(context, url),
  );
}

// ------------------------------------------------------------------ Temas

class _Tema {
  const _Tema({
    required this.icono,
    required this.titulo,
    required this.resumen,
    required this.parrafos,
    this.puntos = const [],
    this.url,
    this.conEmblema = false,
  });

  final IconData icono;
  final String titulo;
  final String resumen;
  final List<String> parrafos;

  /// Lista de puntos: (título, explicación).
  final List<(String, String)> puntos;

  /// Página oficial con el texto completo.
  final String? url;

  /// Muestra el escudo armable en lugar de la lista de puntos.
  final bool conEmblema;
}

// Resúmenes propios de lo que explica el sitio oficial; el texto completo
// está en la página enlazada de cada tema.
const _temas = [
  _Tema(
    icono: PhosphorIconsBold.info,
    titulo: '¿Qué es la Orden?',
    resumen: 'Para quién es y de dónde viene',
    parrafos: [
      'La Orden de los Embajadores del Rey es una organización misionera '
          'bautista para muchachos de 9 a 17 años. Busca darles educación '
          'misionera mundial, ayudarles a formar su carácter y que lleguen a '
          'ser embajadores de Cristo.',
      'Según el sitio oficial, el primer grupo nació en Kentucky en 1883 y '
          'la Unión Femenil Misionera organizó la Orden en 1908. En México, '
          'el primer capítulo se fundó el 4 de agosto de 1940 en la Primera '
          'Iglesia Bautista de Ciudad Juárez, Chihuahua.',
      'Cada grupo local se llama capítulo y suele llevar el nombre de un '
          'misionero.',
    ],
    url: '$_sitio/embajadores-del-rey-bienvenidos',
  ),
  _Tema(
    icono: PhosphorIconsBold.flag,
    titulo: 'El lema',
    resumen: '2 Corintios 5:20',
    parrafos: [
      'El lema de la Orden es 2 Corintios 5:20: somos embajadores en nombre '
          'de Cristo. Un embajador representa a su Rey donde quiera que va, '
          'y lleva su mensaje de reconciliación con Dios.',
      'Memorizarlo y explicarlo es de lo primero que se pide a un '
          'Aspirante.',
    ],
    url: '$_sitio/himno-lema',
  ),
  _Tema(
    icono: PhosphorIconsBold.handsPraying,
    titulo: 'El Pacto',
    resumen: 'El compromiso de cada embajador',
    parrafos: [
      'El Pacto es la promesa que hace el muchacho. Hay una versión para '
          'los aspirantes y otra de Paje en adelante; aquí van sus ideas '
          'principales. Para memorizarlo, usa el texto completo del sitio '
          'oficial o del manual.',
    ],
    puntos: [
      ('Fidelidad a Jesucristo', 'Seguir a Cristo, el Rey.'),
      ('Vida pura', 'Cuidar el cuerpo, la mente y lo que se dice.'),
      ('Decir la verdad', 'Guardar los labios de la mentira.'),
      ('Remediar la injusticia', 'Hacer el bien a quien lo necesita.'),
      ('Misiones', 'Estudiar las misiones, dar y contribuir al Reino.'),
    ],
    url: '$_sitio/el-manual-y-sus-proyectos',
  ),
  _Tema(
    icono: PhosphorIconsBold.star,
    titulo: 'Los cinco ideales',
    resumen: 'Lo que practica un embajador',
    parrafos: ['La Orden resume la vida del embajador en cinco ideales.'],
    puntos: [
      ('Oración', 'Hablar con Dios cada día.'),
      ('Estudio bíblico', 'Conocer la Palabra y memorizarla.'),
      ('Estudio misionero', 'Aprender de las misiones y los misioneros.'),
      ('Mayordomía', 'Administrar bien el tiempo, los dones y el dinero.'),
      ('Servicio', 'Servir con actos de caballero.'),
    ],
    url: '$_sitio/el-manual-y-sus-proyectos',
  ),
  _Tema(
    icono: PhosphorIconsBold.palette,
    titulo: 'Los colores',
    resumen: 'Azul Real, Blanco y Oro',
    parrafos: ['Cada color de la Orden recuerda una cualidad.'],
    puntos: [
      ('Azul Real', 'Lealtad a Cristo Rey, a la iglesia y a la Orden.'),
      ('Blanco', 'Pureza de cuerpo, de mente y de culto.'),
      ('Oro', 'Valor: el de Cristo, el del servicio y el de la mayordomía.'),
    ],
    url: '$_sitio/el-manual-y-sus-proyectos',
  ),
  _Tema(
    icono: PhosphorIconsBold.shieldChevron,
    titulo: 'El emblema',
    resumen: 'Qué significa cada pieza del escudo',
    parrafos: [
      'El emblema se gana por partes: cada grado agrega una pieza. Toca los '
          'grados para ver cómo se arma.',
    ],
    conEmblema: true,
    url: '$_sitio/el-manual-y-sus-proyectos',
  ),
  _Tema(
    icono: PhosphorIconsBold.musicNotes,
    titulo: 'El himno',
    resumen: '«En los negocios del Rey»',
    parrafos: [
      'El himno oficial de la Orden es «En los negocios del Rey». Está en '
          'el Himnario Bautista con el número 399 y en el Nuevo Himnario '
          'Popular con el 104.',
      'Para ser Miembro se pide conocerlo y memorizar al menos la primera '
          'estrofa y el coro. La letra está en el himnario y en el sitio '
          'oficial.',
    ],
    url: '$_sitio/himno-lema',
  ),
];

class _PantallaTema extends StatelessWidget {
  const _PantallaTema(this.tema);

  final _Tema tema;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tema.titulo)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        for (final p in tema.parrafos)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(p, style: const TextStyle(fontSize: 16, height: 1.5)),
          ),
        if (tema.conEmblema) const _EmblemaInteractivo(),
        for (final (i, (titulo, texto)) in tema.puntos.indexed)
          Entrada(
            orden: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Tarjeta(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: Colores.azul,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colores.blanco,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            texto,
                            style: const TextStyle(color: Colores.textoSuave),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (tema.url != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _abrirEnlace(context, tema.url!),
            icon: const Icon(PhosphorIconsBold.arrowSquareOut),
            label: const Text('Ver en el sitio oficial'),
          ),
        ],
      ],
    ),
  );
}

/// El escudo se arma al elegir cada grado, con el significado de la pieza.
class _EmblemaInteractivo extends StatefulWidget {
  const _EmblemaInteractivo();

  @override
  State<_EmblemaInteractivo> createState() => _EmblemaInteractivoState();
}

class _EmblemaInteractivoState extends State<_EmblemaInteractivo> {
  int _etapa = 4;

  static const _piezas = [
    ('Paje', 'El escudo', 'Fe: el muchacho es embajador de Cristo.'),
    ('Escudero', 'La franja E.R.', 'Laboriosidad en el trabajo del Rey.'),
    (
      'Caballero',
      'La corona de oro',
      'Servicio fiel. Sus cinco puntas recuerdan los puntos del Pacto y '
          'los cinco ideales.',
    ),
    ('Embajador', 'La rama de laurel', 'Las victorias ganadas para Cristo.'),
  ];

  @override
  Widget build(BuildContext context) {
    final (_, pieza, significado) = _piezas[_etapa - 1];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Tarjeta(
        destacada: true,
        child: Column(
          children: [
            EscudoArmable(etapa: _etapa, alto: 170),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final (i, (grado, _, _)) in _piezas.indexed)
                  ChoiceChip(
                    label: Text(grado),
                    selected: _etapa == i + 1,
                    onSelected: (_) => setState(() => _etapa = i + 1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Column(
                key: ValueKey(_etapa),
                children: [
                  Text(pieza, style: titulo(21)),
                  const SizedBox(height: 2),
                  Text(
                    significado,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colores.textoSuave),
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

// ------------------------------------------------------------------ Grado

/// Requisitos de un grado según el manual, para consulta.
class _PantallaGrado extends StatelessWidget {
  const _PantallaGrado(this.grado);

  final Grado grado;

  @override
  Widget build(BuildContext context) {
    final manual = Manual.para(grado);
    final calculados = grado.requisitosParaObtenerlo;
    return Scaffold(
      appBar: AppBar(title: Text(grado.nombre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Center(child: EscudoArmable(etapa: grado.etapaEscudo, alto: 130)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Para obtener el grado de ${grado.nombre}',
              style: const TextStyle(color: Colores.textoSuave),
            ),
          ),
          if (!calculados.sinControl) ...[
            const TituloSeccion('Lo que lleva la app'),
            Card(
              child: Column(
                children: [
                  if (calculados.reunionesConsecutivas != null)
                    _Requisito(
                      'Asistir a ${calculados.reunionesConsecutivas} '
                      'reuniones consecutivas del capítulo.',
                    ),
                  if (calculados.porcentajeMinimo != null)
                    _Requisito(
                      'Asistir al ${calculados.porcentajeMinimo} % de las '
                      'reuniones del capítulo.',
                    ),
                  if (calculados.mesesMinimos != null)
                    _Requisito(
                      'Llevar ${calculados.mesesMinimos} meses en el grado '
                      'anterior.',
                    ),
                  if (calculados.llevaMetas)
                    const _Requisito(
                      'Tener las cinco metas firmadas por el consejero.',
                    ),
                ],
              ),
            ),
          ],
          if (manual.generales.isNotEmpty) ...[
            const TituloSeccion('Requisitos'),
            Card(
              child: Column(
                children: [for (final r in manual.generales) _Requisito(r)],
              ),
            ),
          ],
          for (final m in Meta.values)
            if (manual.de(m).isNotEmpty) ...[
              TituloSeccion(m.nombre),
              Card(
                child: Column(
                  children: [for (final r in manual.de(m)) _Requisito(r)],
                ),
              ),
            ],
          const SizedBox(height: 20),
          if (_cuadernillo[grado] != null) ...[
            FilledButton.icon(
              onPressed: () => _abrirEnlace(context, _cuadernillo[grado]!),
              icon: const Icon(PhosphorIconsBold.downloadSimple),
              label: const Text('Descargar el cuadernillo'),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: () => _abrirEnlace(context, _paginaDeGrado[grado]!),
            icon: const Icon(PhosphorIconsBold.arrowSquareOut),
            label: const Text('Ver en el sitio oficial'),
          ),
        ],
      ),
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: CircleAvatar(radius: 3.5, backgroundColor: Colores.oro),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(texto, style: const TextStyle(fontSize: 15, height: 1.4)),
        ),
      ],
    ),
  );
}
