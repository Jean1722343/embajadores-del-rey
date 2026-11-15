import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/asistencia.dart';
import '../core/grados.dart';

typedef Doc = DocumentSnapshot<Map<String, dynamic>>;

DateTime? _fecha(dynamic v) => v is Timestamp ? v.toDate() : null;
Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);
Uint8List? _bytes(dynamic v) => v is Blob ? v.bytes : null;

enum Rol {
  lider('lider', 'Líder'),
  consejero('consejero', 'Consejero');

  const Rol(this.id, this.nombre);
  final String id;
  final String nombre;

  static Rol desdeId(String? id) => id == 'lider' ? Rol.lider : Rol.consejero;
}

class Capitulo {
  const Capitulo({
    required this.id,
    required this.nombre,
    required this.iglesia,
    required this.ciudad,
    required this.estado,
    required this.creadoPor,
    this.suspendido = false,
  });

  final String id;
  final String nombre;
  final String iglesia;
  final String ciudad;
  final String estado;
  final String creadoPor;
  final bool suspendido;

  factory Capitulo.desde(Doc d) {
    final m = d.data() ?? {};
    return Capitulo(
      id: d.id,
      nombre: m['nombre'] ?? '',
      iglesia: m['iglesia'] ?? '',
      ciudad: m['ciudad'] ?? '',
      estado: m['estado'] ?? '',
      creadoPor: m['creadoPor'] ?? '',
      suspendido: m['suspendido'] == true,
    );
  }
}

class Miembro {
  const Miembro({
    required this.uid,
    required this.nombre,
    required this.rol,
    required this.activo,
  });

  final String uid;
  final String nombre;
  final Rol rol;
  final bool activo;

  bool get esLider => rol == Rol.lider;

  factory Miembro.desde(Doc d) {
    final m = d.data() ?? {};
    return Miembro(
      uid: d.id,
      nombre: m['nombre'] ?? '',
      rol: Rol.desdeId(m['rol']),
      activo: m['activo'] == true,
    );
  }
}

class Invitacion {
  const Invitacion({
    required this.codigo,
    required this.capituloId,
    required this.rol,
    required this.expiraEn,
    required this.activa,
  });

  final String codigo;
  final String capituloId;
  final Rol rol;
  final DateTime expiraEn;
  final bool activa;

  bool get vigente => activa && expiraEn.isAfter(DateTime.now());

  factory Invitacion.desde(Doc d) {
    final m = d.data() ?? {};
    return Invitacion(
      codigo: d.id,
      capituloId: m['capituloId'] ?? '',
      rol: Rol.desdeId(m['rol']),
      expiraEn: _fecha(m['expiraEn']) ?? DateTime(2000),
      activa: m['activa'] == true,
    );
  }
}

class Periodo {
  const Periodo({
    required this.id,
    required this.nombre,
    required this.inicio,
    required this.fin,
    required this.activo,
  });

  final String id;
  final String nombre;
  final DateTime inicio;
  final DateTime fin;
  final bool activo;

  factory Periodo.desde(Doc d) {
    final m = d.data() ?? {};
    return Periodo(
      id: d.id,
      nombre: m['nombre'] ?? '',
      inicio: _fecha(m['inicio']) ?? DateTime.now(),
      fin: _fecha(m['fin']) ?? DateTime.now(),
      activo: m['activo'] == true,
    );
  }

  Map<String, dynamic> aMapa() => {
    'nombre': nombre,
    'inicio': _ts(inicio),
    'fin': _ts(fin),
    'activo': activo,
  };
}

/// Grupo de pase de lista: uno o varios grados juntos durante un periodo.
class Grupo {
  const Grupo({
    required this.id,
    required this.periodoId,
    required this.nombre,
    required this.grados,
    required this.consejeroIds,
  });

  final String id;
  final String periodoId;
  final String nombre;
  final List<Grado> grados;
  final List<String> consejeroIds;

  factory Grupo.desde(Doc d) {
    final m = d.data() ?? {};
    return Grupo(
      id: d.id,
      periodoId: m['periodoId'] ?? '',
      nombre: m['nombre'] ?? '',
      grados: [
        for (final g in (m['grados'] as List? ?? const []))
          Grado.desdeId(g as String?),
      ],
      consejeroIds: List<String>.from(m['consejeroIds'] as List? ?? const []),
    );
  }

  Map<String, dynamic> aMapa() => {
    'periodoId': periodoId,
    'nombre': nombre,
    'grados': [for (final g in grados) g.id],
    'consejeroIds': consejeroIds,
  };
}

class Alumno {
  const Alumno({
    required this.id,
    required this.nombre,
    required this.grado,
    required this.fechaIngresoGrado,
    this.fechaNac,
    this.tutorNombre = '',
    this.tutorTel = '',
    this.tutor2Nombre = '',
    this.tutor2Tel = '',
    this.domicilio = '',
    this.notas = '',
    this.foto,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final Grado grado;
  final DateTime fechaIngresoGrado;
  final DateTime? fechaNac;
  final String tutorNombre;
  final String tutorTel;

  /// Segundo contacto de la familia (el otro papá, un abuelo…).
  final String tutor2Nombre;
  final String tutor2Tel;
  final String domicilio;

  bool get tieneDatosDeFamilia => [
    tutorNombre,
    tutorTel,
    tutor2Nombre,
    tutor2Tel,
    domicilio,
  ].any((d) => d.isNotEmpty);
  final String notas;

  /// Foto de perfil pequeña, guardada dentro del propio documento.
  final Uint8List? foto;
  final bool activo;

  int? edad(DateTime hoy) {
    final n = fechaNac;
    if (n == null) return null;
    var e = hoy.year - n.year;
    if (hoy.month < n.month || (hoy.month == n.month && hoy.day < n.day)) e--;
    return e;
  }

  factory Alumno.desde(Doc d) {
    final m = d.data() ?? {};
    return Alumno(
      id: d.id,
      nombre: m['nombre'] ?? '',
      grado: Grado.desdeId(m['grado']),
      fechaIngresoGrado: _fecha(m['fechaIngresoGrado']) ?? DateTime.now(),
      fechaNac: _fecha(m['fechaNac']),
      tutorNombre: m['tutorNombre'] ?? '',
      tutorTel: m['tutorTel'] ?? '',
      tutor2Nombre: m['tutor2Nombre'] ?? '',
      tutor2Tel: m['tutor2Tel'] ?? '',
      domicilio: m['domicilio'] ?? '',
      notas: m['notas'] ?? '',
      foto: _bytes(m['foto']),
      activo: m['activo'] != false,
    );
  }

  Map<String, dynamic> aMapa() => {
    'nombre': nombre,
    'grado': grado.id,
    'fechaIngresoGrado': _ts(fechaIngresoGrado),
    'fechaNac': _ts(fechaNac),
    'tutorNombre': tutorNombre,
    'tutorTel': tutorTel,
    'tutor2Nombre': tutor2Nombre,
    'tutor2Tel': tutor2Tel,
    'domicilio': domicilio,
    'notas': notas,
    'foto': foto == null ? null : Blob(foto!),
    'activo': activo,
  };
}

/// Firma de una meta por un consejero.
class FirmaMeta {
  const FirmaMeta({required this.firmadaPor, required this.nombre, this.fecha});
  final String firmadaPor;
  final String nombre;
  final DateTime? fecha;
}

/// Avance de un muchacho hacia un grado: metas firmadas y graduación.
class Avance {
  const Avance({
    required this.grado,
    required this.metas,
    this.hechos = const {},
    this.fechaGraduacion,
  });

  final Grado grado;
  final Map<Meta, FirmaMeta> metas;

  /// Claves de los requisitos del manual ya cumplidos (ver Manual.clave…).
  final Set<String> hechos;
  final DateTime? fechaGraduacion;

  int get cumplidas => metas.length;

  factory Avance.vacio(Grado g) => Avance(grado: g, metas: const {});

  factory Avance.desde(Doc d) {
    final m = d.data() ?? {};
    final crudas = Map<String, dynamic>.from(m['metas'] as Map? ?? const {});
    final metas = <Meta, FirmaMeta>{};
    for (final meta in Meta.values) {
      final f = crudas[meta.id];
      if (f is Map && f['cumplida'] == true) {
        metas[meta] = FirmaMeta(
          firmadaPor: f['firmadaPor'] ?? '',
          nombre: f['nombre'] ?? '',
          fecha: _fecha(f['fecha']),
        );
      }
    }
    return Avance(
      grado: Grado.desdeId(d.id),
      metas: metas,
      hechos: {
        for (final e in (m['hechos'] as Map? ?? const {}).entries)
          if (e.value == true) e.key as String,
      },
      fechaGraduacion: _fecha(m['fechaGraduacion']),
    );
  }
}

class Reunion {
  const Reunion({
    required this.id,
    required this.fecha,
    required this.titulo,
    required this.periodoId,
  });

  final String id;
  final DateTime fecha;
  final String titulo;
  final String periodoId;

  factory Reunion.desde(Doc d) {
    final m = d.data() ?? {};
    return Reunion(
      id: d.id,
      fecha: _fecha(m['fecha']) ?? DateTime.now(),
      titulo: m['titulo'] ?? '',
      periodoId: m['periodoId'] ?? '',
    );
  }
}

/// Pase de lista de un grupo en una reunión.
class Lista {
  const Lista({
    required this.id,
    required this.reunionId,
    required this.grupoId,
    required this.periodoId,
    required this.fecha,
    required this.tomadaPor,
    required this.tomadaPorNombre,
    required this.registros,
  });

  final String id;
  final String reunionId;
  final String grupoId;
  final String periodoId;
  final DateTime fecha;
  final String tomadaPor;
  final String tomadaPorNombre;
  final Map<String, Registro> registros;

  int get presentes => registros.values.where((r) => r.presente).length;

  /// Total de ofrendas de esta lista, en pesos.
  double get ofrendaTotal =>
      registros.values.fold(0, (suma, r) => suma + r.monto);

  static String idDe(String reunionId, String grupoId) =>
      '${reunionId}_$grupoId';

  factory Lista.desde(Doc d) {
    final m = d.data() ?? {};
    final crudos = Map<String, dynamic>.from(
      m['registros'] as Map? ?? const {},
    );
    return Lista(
      id: d.id,
      reunionId: m['reunionId'] ?? '',
      grupoId: m['grupoId'] ?? '',
      periodoId: m['periodoId'] ?? '',
      fecha: _fecha(m['fecha']) ?? DateTime.now(),
      tomadaPor: m['tomadaPor'] ?? '',
      tomadaPorNombre: m['tomadaPorNombre'] ?? '',
      registros: {
        for (final e in crudos.entries)
          e.key: Registro.desdeMapa(
            e.value is Map ? Map<String, dynamic>.from(e.value as Map) : null,
          ),
      },
    );
  }
}

class Evidencia {
  const Evidencia({
    required this.id,
    required this.reunionId,
    required this.grupoId,
    required this.miniatura,
    required this.descripcion,
    required this.subidaPor,
    required this.subidaPorNombre,
    required this.fecha,
  });

  final String id;
  final String reunionId;
  final String? grupoId;

  /// Vista pequeña para la galería; la foto grande vive en `fotos/{id}`.
  final Uint8List? miniatura;
  final String descripcion;
  final String subidaPor;
  final String subidaPorNombre;
  final DateTime fecha;

  factory Evidencia.desde(Doc d) {
    final m = d.data() ?? {};
    return Evidencia(
      id: d.id,
      reunionId: m['reunionId'] ?? '',
      grupoId: m['grupoId'],
      miniatura: _bytes(m['miniatura']),
      descripcion: m['descripcion'] ?? '',
      subidaPor: m['subidaPor'] ?? '',
      subidaPorNombre: m['subidaPorNombre'] ?? '',
      fecha: _fecha(m['fecha']) ?? DateTime.now(),
    );
  }
}

/// Entrada o salida de dinero de la caja del capítulo (aparte de las
/// ofrendas, que salen de los pases de lista).
class Movimiento {
  const Movimiento({
    required this.id,
    required this.esIngreso,
    required this.monto,
    required this.concepto,
    required this.fecha,
    required this.registradoPor,
    required this.registradoPorNombre,
  });

  final String id;
  final bool esIngreso;

  /// Siempre positivo; [esIngreso] dice si entra o sale.
  final double monto;

  /// Cómo se consiguió (ingreso) o para qué se sacó (salida).
  final String concepto;
  final DateTime fecha;
  final String registradoPor;
  final String registradoPorNombre;

  factory Movimiento.desde(Doc d) {
    final m = d.data() ?? {};
    return Movimiento(
      id: d.id,
      esIngreso: m['tipo'] != 'egreso',
      monto: (m['monto'] as num?)?.toDouble() ?? 0,
      concepto: m['concepto'] ?? '',
      fecha: _fecha(m['fecha']) ?? DateTime.now(),
      registradoPor: m['registradoPor'] ?? '',
      registradoPorNombre: m['registradoPorNombre'] ?? '',
    );
  }
}
