import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../core/asistencia.dart';
import '../core/grados.dart';
import '../models/modelos.dart';
import 'fotos.dart';

typedef Col = CollectionReference<Map<String, dynamic>>;

/// Perfil del usuario: a qué capítulos pertenece y cuál tiene abierto.
class Perfil {
  const Perfil({
    required this.uid,
    required this.nombre,
    required this.capitulos,
    required this.capituloActual,
    required this.superAdmin,
    this.foto,
  });

  final String uid;
  final String nombre;

  /// Foto de perfil pequeña del usuario.
  final Uint8List? foto;
  final List<String> capitulos;
  final String? capituloActual;
  final bool superAdmin;

  factory Perfil.desde(Doc d) {
    final m = d.data() ?? {};
    return Perfil(
      uid: d.id,
      nombre: m['nombre'] ?? '',
      capitulos: List<String>.from(m['capitulos'] as List? ?? const []),
      capituloActual: m['capituloActual'],
      superAdmin: m['superAdmin'] == true,
      foto: m['foto'] is Blob ? (m['foto'] as Blob).bytes : null,
    );
  }
}

/// Error con un mensaje que se le puede mostrar tal cual al usuario.
class ErrorDeUso implements Exception {
  const ErrorDeUso(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

String idDeFecha(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Acceso a Firestore y Auth. Las fotos también se guardan en Firestore,
/// ya reducidas, para no depender de un servicio de pago.
class Repo {
  Repo(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _usuario =>
      _db.collection('usuarios').doc(uid);
  DocumentReference<Map<String, dynamic>> _cap(String capId) =>
      _db.collection('capitulos').doc(capId);
  Col _sub(String capId, String nombre) => _cap(capId).collection(nombre);

  // ---------- Sesión ----------

  Future<void> entrarConGoogle() =>
      _auth.signInWithProvider(GoogleAuthProvider());

  Future<void> entrarConCorreo(String correo, String clave) =>
      _auth.signInWithEmailAndPassword(email: correo.trim(), password: clave);

  Future<void> registrarConCorreo(
    String nombre,
    String correo,
    String clave,
  ) async {
    // El perfil se crea en cuanto hay sesión; se le deja el nombre listo.
    _nombrePendiente = nombre.trim();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: clave,
    );
    await cred.user?.updateDisplayName(nombre.trim());
  }

  String? _nombrePendiente;

  Future<void> recuperarClave(String correo) =>
      _auth.sendPasswordResetEmail(email: correo.trim());

  Future<void> salir() => _auth.signOut();

  /// Crea el perfil la primera vez que alguien entra.
  Future<void> asegurarPerfil() async {
    final u = _auth.currentUser!;
    final doc = await _usuario.get();
    if (doc.exists && (doc.data()?['nombre'] ?? '') != '') return;
    await _usuario.set({
      'nombre':
          _nombrePendiente ??
          u.displayName ??
          u.email?.split('@').first ??
          'Consejero',
      'correo': u.email,
      if (!doc.exists) 'capitulos': <String>[],
    }, SetOptions(merge: true));
  }

  Stream<Perfil?> perfil(String uid) => _db
      .collection('usuarios')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? Perfil.desde(d) : null);

  Future<void> cambiarCapitulo(String capId) =>
      _usuario.update({'capituloActual': capId});

  /// Correo con el que entró el usuario.
  String get miCorreo => _auth.currentUser?.email ?? '';

  /// Cambia el nombre y, si se da, la foto del usuario. Se copia a su ficha
  /// en cada capítulo para que el resto del equipo lo vea. No espera al
  /// servidor: sin señal queda en cola y se sincroniza después.
  void guardarMiPerfil({
    required String nombre,
    Uint8List? foto,
    required List<String> capitulos,
  }) {
    final datos = <String, dynamic>{
      'nombre': nombre.trim(),
      if (foto != null) 'foto': Blob(foto),
    };
    _usuario.set(datos, SetOptions(merge: true)).ignore();
    _auth.currentUser?.updateDisplayName(nombre.trim()).ignore();
    for (final capId in capitulos) {
      // Un capítulo suspendido o del que ya no es miembro rechaza el cambio;
      // no debe impedir que se guarde en los demás.
      _sub(capId, 'miembros').doc(uid).update(datos).ignore();
    }
  }

  /// Quita un capítulo de la lista del usuario, sin tocar el capítulo.
  Future<void> olvidarCapitulo(String capId) => _usuario.update({
    'capitulos': FieldValue.arrayRemove([capId]),
    'capituloActual': FieldValue.delete(),
  });

  /// El usuario deja de ser miembro de un capítulo.
  Future<void> abandonarCapitulo(String capId) async {
    await _exigirConexion();
    await _sub(capId, 'miembros').doc(uid).delete();
    await olvidarCapitulo(capId);
  }

  /// Salir de un capítulo o borrarlo no debe quedarse en cola sin señal y
  /// ocurrir más tarde por sorpresa: se comprueba antes que hay servidor.
  Future<void> _exigirConexion() async {
    try {
      await _usuario
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const ErrorDeUso('Necesitas conexión a internet para hacer esto.');
    }
  }

  // ---------- Capítulos y acceso ----------

  Future<void> crearCapitulo({
    required String miNombre,
    required String nombre,
    required String iglesia,
    required String ciudad,
    required String estado,
  }) async {
    final ref = _db.collection('capitulos').doc();
    final lote = _db.batch()
      ..set(ref, {
        'nombre': nombre.trim(),
        'iglesia': iglesia.trim(),
        'ciudad': ciudad.trim(),
        'estado': estado.trim(),
        'creadoPor': uid,
        'creadoEn': FieldValue.serverTimestamp(),
        'suspendido': false,
      })
      ..set(ref.collection('miembros').doc(uid), {
        'nombre': miNombre,
        'rol': Rol.lider.id,
        'activo': true,
        'desde': FieldValue.serverTimestamp(),
      })
      ..set(_usuario, {
        'capitulos': FieldValue.arrayUnion([ref.id]),
        'capituloActual': ref.id,
      }, SetOptions(merge: true));
    await lote.commit();
  }

  /// Entra a un capítulo con un código de invitación.
  Future<void> unirseConCodigo(String codigo, String miNombre) async {
    final limpio = codigo.trim().toUpperCase();
    if (limpio.isEmpty) throw const ErrorDeUso('Escribe el código.');
    final doc = await _db.collection('invitaciones').doc(limpio).get();
    if (!doc.exists) throw const ErrorDeUso('Ese código no existe.');
    final inv = Invitacion.desde(doc);
    if (!inv.vigente) {
      throw const ErrorDeUso(
        'Ese código ya venció. Pide uno nuevo a tu líder.',
      );
    }
    final miembro = _sub(inv.capituloId, 'miembros').doc(uid);
    final ya = await miembro.get().then((d) => d.exists, onError: (_) => false);
    if (!ya) {
      await miembro.set({
        'nombre': miNombre,
        'rol': inv.rol.id,
        'activo': true,
        'codigoUsado': limpio,
        'desde': FieldValue.serverTimestamp(),
      });
    }
    await _usuario.set({
      'capitulos': FieldValue.arrayUnion([inv.capituloId]),
      'capituloActual': inv.capituloId,
    }, SetOptions(merge: true));
  }

  Stream<Capitulo?> capitulo(String capId) =>
      _cap(capId).snapshots().map((d) => d.exists ? Capitulo.desde(d) : null);

  Future<void> editarCapitulo(String capId, Map<String, dynamic> datos) =>
      _cap(capId).update(datos);

  Stream<Miembro?> miembro(String capId, String uid) => _sub(
    capId,
    'miembros',
  ).doc(uid).snapshots().map((d) => d.exists ? Miembro.desde(d) : null);

  Stream<List<Miembro>> miembros(String capId) =>
      _sub(capId, 'miembros').snapshots().map(
        (s) =>
            s.docs.map(Miembro.desde).toList()
              ..sort((a, b) => a.nombre.compareTo(b.nombre)),
      );

  Future<void> cambiarMiembro(
    String capId,
    String uid, {
    Rol? rol,
    bool? activo,
  }) => _sub(
    capId,
    'miembros',
  ).doc(uid).update({'rol': ?rol?.id, 'activo': ?activo});

  static const _letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Genera un código de 6 caracteres válido por [dias] días.
  Future<String> crearInvitacion(String capId, Rol rol, {int dias = 7}) async {
    final azar = Random.secure();
    final codigo = List.generate(
      6,
      (_) => _letras[azar.nextInt(_letras.length)],
    ).join();
    await _db.collection('invitaciones').doc(codigo).set({
      'capituloId': capId,
      'rol': rol.id,
      'activa': true,
      'creadaPor': uid,
      'creadaEn': FieldValue.serverTimestamp(),
      'expiraEn': Timestamp.fromDate(DateTime.now().add(Duration(days: dias))),
    });
    return codigo;
  }

  Stream<List<Invitacion>> invitaciones(String capId) => _db
      .collection('invitaciones')
      .where('capituloId', isEqualTo: capId)
      .snapshots()
      .map(
        (s) => s.docs.map(Invitacion.desde).where((i) => i.vigente).toList(),
      );

  Future<void> anularInvitacion(String codigo) =>
      _db.collection('invitaciones').doc(codigo).update({'activa': false});

  // ---------- Periodos y grupos ----------

  Stream<List<Periodo>> periodos(String capId) =>
      _sub(capId, 'periodos').snapshots().map(
        (s) =>
            s.docs.map(Periodo.desde).toList()
              ..sort((a, b) => b.inicio.compareTo(a.inicio)),
      );

  /// Guarda un periodo; si queda activo, desactiva los demás.
  Future<void> guardarPeriodo(
    String capId,
    Periodo p,
    List<Periodo> existentes,
  ) async {
    final col = _sub(capId, 'periodos');
    final ref = p.id.isEmpty ? col.doc() : col.doc(p.id);
    final lote = _db.batch()..set(ref, p.aMapa());
    if (p.activo) {
      for (final otro in existentes) {
        if (otro.id != ref.id && otro.activo) {
          lote.update(col.doc(otro.id), {'activo': false});
        }
      }
    }
    await lote.commit();
  }

  Stream<List<Grupo>> grupos(String capId, String periodoId) =>
      _sub(capId, 'grupos')
          .where('periodoId', isEqualTo: periodoId)
          .snapshots()
          .map(
            (s) =>
                s.docs.map(Grupo.desde).toList()
                  ..sort((a, b) => a.nombre.compareTo(b.nombre)),
          );

  Future<void> guardarGrupo(String capId, Grupo g) {
    final col = _sub(capId, 'grupos');
    return (g.id.isEmpty ? col.doc() : col.doc(g.id)).set(g.aMapa());
  }

  Future<void> borrarGrupo(String capId, String id) =>
      _sub(capId, 'grupos').doc(id).delete();

  // ---------- Muchachos ----------

  Stream<List<Alumno>> alumnos(String capId) =>
      _sub(capId, 'alumnos').snapshots().map(
        (s) => s.docs.map(Alumno.desde).toList()
          ..sort(
            (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
          ),
      );

  /// Guarda al muchacho y devuelve su id.
  Future<String> guardarAlumno(String capId, Alumno a) async {
    final col = _sub(capId, 'alumnos');
    final ref = a.id.isEmpty ? col.doc() : col.doc(a.id);
    // Sin esperar al servidor: sin señal queda en cola y se sincroniza después.
    ref.set(a.aMapa(), SetOptions(merge: true));
    return ref.id;
  }

  Future<void> darDeBaja(String capId, String alumnoId, bool activo) =>
      _sub(capId, 'alumnos').doc(alumnoId).update({'activo': activo});

  Future<void> borrarAlumno(String capId, String alumnoId) =>
      _sub(capId, 'alumnos').doc(alumnoId).delete();

  /// Guarda la foto de perfil (ya reducida) dentro del documento.
  void guardarFotoAlumno(String capId, String alumnoId, Uint8List foto) {
    _sub(
      capId,
      'alumnos',
    ).doc(alumnoId).set({'foto': Blob(foto)}, SetOptions(merge: true));
  }

  // ---------- Avance de grado ----------

  Col _avances(String capId, String alumnoId) =>
      _sub(capId, 'alumnos').doc(alumnoId).collection('avances');

  Stream<Avance> avance(String capId, String alumnoId, Grado objetivo) =>
      _avances(capId, alumnoId)
          .doc(objetivo.id)
          .snapshots()
          .map((d) => d.exists ? Avance.desde(d) : Avance.vacio(objetivo));

  Future<void> firmarMeta(
    String capId,
    String alumnoId,
    Grado objetivo,
    Meta meta,
    bool cumplida,
    String miNombre,
  ) => _avances(capId, alumnoId).doc(objetivo.id).set({
    'metas': {
      meta.id: cumplida
          ? {
              'cumplida': true,
              'firmadaPor': uid,
              'nombre': miNombre,
              'fecha': Timestamp.now(),
            }
          : FieldValue.delete(),
    },
  }, SetOptions(merge: true));

  /// Marca o desmarca un requisito del manual. No espera al servidor.
  void marcarRequisito(
    String capId,
    String alumnoId,
    Grado objetivo,
    String clave,
    bool hecho,
  ) {
    _avances(capId, alumnoId).doc(objetivo.id).set({
      'hechos': {clave: hecho ? true : FieldValue.delete()},
    }, SetOptions(merge: true));
  }

  /// Pasa al muchacho al grado [objetivo] y registra la fecha de graduación.
  Future<void> graduar(String capId, String alumnoId, Grado objetivo) {
    final ahora = Timestamp.now();
    final lote = _db.batch()
      ..set(_avances(capId, alumnoId).doc(objetivo.id), {
        'fechaGraduacion': ahora,
        'graduadoPor': uid,
      }, SetOptions(merge: true))
      ..update(_sub(capId, 'alumnos').doc(alumnoId), {
        'grado': objetivo.id,
        'fechaIngresoGrado': ahora,
      });
    return lote.commit();
  }

  // ---------- Reuniones y listas ----------

  Stream<List<Reunion>> reuniones(String capId, String periodoId) =>
      _sub(capId, 'reuniones')
          .where('periodoId', isEqualTo: periodoId)
          .snapshots()
          .map(
            (s) =>
                s.docs.map(Reunion.desde).toList()
                  ..sort((a, b) => b.fecha.compareTo(a.fecha)),
          );

  /// Crea (o reutiliza) la reunión de un día. El id es la fecha, así que dos
  /// consejeros que la abran a la vez, incluso sin señal, caen en la misma.
  Future<String> asegurarReunion(
    String capId,
    String periodoId,
    DateTime dia, {
    String titulo = '',
  }) async {
    final id = idDeFecha(dia);
    _sub(capId, 'reuniones').doc(id).set({
      'fecha': Timestamp.fromDate(DateTime(dia.year, dia.month, dia.day, 12)),
      'periodoId': periodoId,
      if (titulo.isNotEmpty) 'titulo': titulo,
    }, SetOptions(merge: true));
    return id;
  }

  Future<void> titularReunion(String capId, String id, String titulo) =>
      _sub(capId, 'reuniones').doc(id).update({'titulo': titulo.trim()});

  Stream<Lista?> lista(String capId, String reunionId, String grupoId) =>
      _sub(capId, 'listas')
          .doc(Lista.idDe(reunionId, grupoId))
          .snapshots()
          .map((d) => d.exists ? Lista.desde(d) : null);

  /// Listas con fecha entre [desde] y [hasta], para reportes y porcentajes.
  Stream<List<Lista>> listasEntre(
    String capId,
    DateTime desde,
    DateTime hasta,
  ) => _sub(capId, 'listas')
      .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
      .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta))
      .snapshots()
      .map((s) => s.docs.map(Lista.desde).toList());

  /// Guarda los registros indicados. Solo toca a esos muchachos, así que dos
  /// consejeros pueden pasar la misma lista a la vez sin pisarse. No espera
  /// al servidor: sin señal queda en cola y se sincroniza después.
  void marcar({
    required String capId,
    required Reunion reunion,
    required String grupoId,
    required Map<String, Registro> registros,
    required String miNombre,
  }) {
    _sub(capId, 'listas').doc(Lista.idDe(reunion.id, grupoId)).set({
      'reunionId': reunion.id,
      'grupoId': grupoId,
      'periodoId': reunion.periodoId,
      'fecha': Timestamp.fromDate(reunion.fecha),
      'tomadaPor': uid,
      'tomadaPorNombre': miNombre,
      'actualizadaEn': FieldValue.serverTimestamp(),
      'registros': {for (final e in registros.entries) e.key: e.value.aMapa()},
    }, SetOptions(merge: true));
  }

  // ---------- Evidencias ----------

  Stream<List<Evidencia>> evidencias(String capId, {String? reunionId}) {
    Query<Map<String, dynamic>> q = _sub(capId, 'evidencias');
    if (reunionId != null) q = q.where('reunionId', isEqualTo: reunionId);
    return q.snapshots().map(
      (s) =>
          s.docs.map(Evidencia.desde).toList()
            ..sort((a, b) => b.fecha.compareTo(a.fecha)),
    );
  }

  /// Guarda una evidencia: la miniatura va en el documento de la galería
  /// y la foto grande en `fotos/{id}`, que solo se lee al abrirla. No
  /// espera al servidor: sin señal queda en cola y se sube después.
  void guardarEvidencia({
    required String capId,
    required String reunionId,
    String? grupoId,
    required FotoPreparada foto,
    required String descripcion,
    required String miNombre,
  }) {
    final doc = _sub(capId, 'evidencias').doc();
    _db.batch()
      ..set(_sub(capId, 'fotos').doc(doc.id), {
        'bytes': Blob(foto.grande),
        'subidaPor': uid,
      })
      ..set(doc, {
        'reunionId': reunionId,
        'grupoId': grupoId,
        'miniatura': Blob(foto.miniatura),
        'descripcion': descripcion.trim(),
        'subidaPor': uid,
        'subidaPorNombre': miNombre,
        'fecha': Timestamp.now(),
      })
      ..commit();
  }

  /// La foto en tamaño completo de una evidencia.
  Future<Uint8List?> fotoDeEvidencia(String capId, String evidenciaId) async {
    final d = await _sub(capId, 'fotos').doc(evidenciaId).get();
    final b = d.data()?['bytes'];
    return b is Blob ? b.bytes : null;
  }

  /// Cambia el día de la actividad de una foto ya subida.
  Future<void> cambiarDiaEvidencia(String capId, String id, DateTime dia) =>
      _sub(capId, 'evidencias').doc(id).update({'reunionId': idDeFecha(dia)});

  Future<void> borrarEvidencia(String capId, Evidencia e) =>
      (_db.batch()
            ..delete(_sub(capId, 'evidencias').doc(e.id))
            ..delete(_sub(capId, 'fotos').doc(e.id)))
          .commit();

  // ---------- Caja ----------

  Stream<List<Movimiento>> movimientos(String capId) =>
      _sub(capId, 'movimientos').snapshots().map(
        (s) =>
            s.docs.map(Movimiento.desde).toList()
              ..sort((a, b) => b.fecha.compareTo(a.fecha)),
      );

  /// Todas las listas del capítulo, para sumar las ofrendas de la caja.
  Stream<List<Lista>> todasLasListas(String capId) => _sub(
    capId,
    'listas',
  ).snapshots().map((s) => s.docs.map(Lista.desde).toList());

  /// Registra una entrada o salida de dinero. No espera al servidor.
  void registrarMovimiento({
    required String capId,
    required bool esIngreso,
    required double monto,
    required String concepto,
    required DateTime fecha,
    required String miNombre,
  }) {
    _sub(capId, 'movimientos').doc().set({
      'tipo': esIngreso ? 'ingreso' : 'egreso',
      'monto': monto,
      'concepto': concepto.trim(),
      'fecha': Timestamp.fromDate(fecha),
      'registradoPor': uid,
      'registradoPorNombre': miNombre,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> borrarMovimiento(String capId, String id) =>
      _sub(capId, 'movimientos').doc(id).delete();

  // ---------- Empezar de nuevo ----------

  /// Borra todo el contenido del capítulo (muchachos con sus avances,
  /// listas, reuniones, fotos, caja, grupos y periodos). Conserva el capítulo y
  /// sus miembros. Solo lo permite la regla al líder.
  Future<void> reiniciarCapitulo(String capId) async {
    await _borrarEnLotes(await _contenido(capId));
  }

  /// Borra el capítulo completo: su contenido, sus códigos de invitación,
  /// sus miembros y el capítulo mismo. Solo lo permite la regla al líder.
  Future<void> borrarCapitulo(String capId) async {
    await _exigirConexion();
    final refs = await _contenido(capId);
    final codigos = await _db
        .collection('invitaciones')
        .where('capituloId', isEqualTo: capId)
        .get();
    refs.addAll(codigos.docs.map((d) => d.reference));
    final miembros = await _sub(capId, 'miembros').get();
    refs.addAll(
      miembros.docs.where((d) => d.id != uid).map((d) => d.reference),
    );
    await _borrarEnLotes(refs);
    // Al final y juntos: la ficha del líder y el capítulo. La regla revisa
    // el permiso con lo que había antes del lote, cuando aún era líder.
    await (_db.batch()
          ..delete(_sub(capId, 'miembros').doc(uid))
          ..delete(_cap(capId)))
        .commit();
    await olvidarCapitulo(capId);
  }

  Future<void> _borrarEnLotes(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    // Firestore admite hasta 500 operaciones por lote.
    for (var i = 0; i < refs.length; i += 400) {
      final lote = _db.batch();
      for (final r in refs.skip(i).take(400)) {
        lote.delete(r);
      }
      await lote.commit();
    }
  }

  /// Referencias a todo el contenido de un capítulo (sin sus miembros).
  Future<List<DocumentReference<Map<String, dynamic>>>> _contenido(
    String capId,
  ) async {
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    final alumnos = await _sub(capId, 'alumnos').get();
    for (final a in alumnos.docs) {
      final avances = await a.reference.collection('avances').get();
      refs.addAll(avances.docs.map((d) => d.reference));
      refs.add(a.reference);
    }
    for (final nombre in const [
      'listas',
      'reuniones',
      'evidencias',
      'fotos',
      'movimientos',
      'grupos',
      'periodos',
    ]) {
      final docs = await _sub(capId, nombre).get();
      refs.addAll(docs.docs.map((d) => d.reference));
    }
    return refs;
  }

  // ---------- Super administrador ----------

  Stream<List<Capitulo>> todosLosCapitulos() => _db
      .collection('capitulos')
      .snapshots()
      .map(
        (s) =>
            s.docs.map(Capitulo.desde).toList()
              ..sort((a, b) => a.nombre.compareTo(b.nombre)),
      );

  Future<void> suspender(String capId, bool suspendido) =>
      _cap(capId).update({'suspendido': suspendido});
}
