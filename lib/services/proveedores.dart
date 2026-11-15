import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/asistencia.dart';
import '../core/grados.dart';
import '../models/modelos.dart';
import 'repo.dart';

final repoProvider = Provider<Repo>(
  (ref) => Repo(FirebaseFirestore.instance, FirebaseAuth.instance),
);

final sesionProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final perfilProvider = StreamProvider<Perfil?>((ref) {
  final u = ref.watch(sesionProvider).value;
  if (u == null) return Stream.value(null);
  return ref.watch(repoProvider).perfil(u.uid);
});

/// Capítulo que el usuario tiene abierto.
final capIdProvider = Provider<String?>((ref) {
  final p = ref.watch(perfilProvider).value;
  if (p == null) return null;
  if (p.capituloActual != null && p.capitulos.contains(p.capituloActual)) {
    return p.capituloActual;
  }
  return p.capitulos.isEmpty ? null : p.capitulos.first;
});

final capituloProvider = StreamProvider<Capitulo?>((ref) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(null);
  return ref.watch(repoProvider).capitulo(capId);
});

/// Datos de cualquier capítulo del usuario, para el selector de capítulos.
final capituloPorIdProvider = StreamProvider.family<Capitulo?, String>(
  (ref, capId) => ref.watch(repoProvider).capitulo(capId),
);

final yoProvider = StreamProvider<Miembro?>((ref) {
  final capId = ref.watch(capIdProvider);
  final u = ref.watch(sesionProvider).value;
  if (capId == null || u == null) return Stream.value(null);
  return ref.watch(repoProvider).miembro(capId, u.uid);
});

final esLiderProvider = Provider<bool>(
  (ref) => ref.watch(yoProvider).value?.esLider ?? false,
);

final miNombreProvider = Provider<String>(
  (ref) =>
      ref.watch(yoProvider).value?.nombre ??
      ref.watch(perfilProvider).value?.nombre ??
      '',
);

final miembrosProvider = StreamProvider<List<Miembro>>((ref) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(const []);
  return ref.watch(repoProvider).miembros(capId);
});

final invitacionesProvider = StreamProvider<List<Invitacion>>((ref) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(const []);
  return ref.watch(repoProvider).invitaciones(capId);
});

final periodosProvider = StreamProvider<List<Periodo>>((ref) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(const []);
  return ref.watch(repoProvider).periodos(capId);
});

final periodoActivoProvider = Provider<Periodo?>((ref) {
  final lista = ref.watch(periodosProvider).value ?? const [];
  for (final p in lista) {
    if (p.activo) return p;
  }
  return null;
});

/// Grupos del periodo activo.
final gruposProvider = StreamProvider<List<Grupo>>((ref) {
  final capId = ref.watch(capIdProvider);
  final periodo = ref.watch(periodoActivoProvider);
  if (capId == null || periodo == null) return Stream.value(const []);
  return ref.watch(repoProvider).grupos(capId, periodo.id);
});

final alumnosProvider = StreamProvider<List<Alumno>>((ref) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(const []);
  return ref.watch(repoProvider).alumnos(capId);
});

final alumnosActivosProvider = Provider<List<Alumno>>(
  (ref) => (ref.watch(alumnosProvider).value ?? const [])
      .where((a) => a.activo)
      .toList(),
);

/// Muchachos activos que pertenecen a un grupo, según su grado.
List<Alumno> alumnosDeGrupo(List<Alumno> activos, Grupo g) =>
    activos.where((a) => g.grados.contains(a.grado)).toList();

/// Reuniones del periodo activo, de la más reciente a la más antigua.
final reunionesProvider = StreamProvider<List<Reunion>>((ref) {
  final capId = ref.watch(capIdProvider);
  final periodo = ref.watch(periodoActivoProvider);
  if (capId == null || periodo == null) return Stream.value(const []);
  return ref.watch(repoProvider).reuniones(capId, periodo.id);
});

typedef ClaveLista = ({String reunionId, String grupoId});

final listaProvider = StreamProvider.family<Lista?, ClaveLista>((ref, c) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(null);
  return ref.watch(repoProvider).lista(capId, c.reunionId, c.grupoId);
});

typedef Rango = ({DateTime desde, DateTime hasta});

final listasProvider = StreamProvider.family<List<Lista>, Rango>((ref, r) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(const []);
  return ref.watch(repoProvider).listasEntre(capId, r.desde, r.hasta);
});

/// Rango del periodo activo (todo el día final incluido).
final rangoPeriodoProvider = Provider<Rango?>((ref) {
  final p = ref.watch(periodoActivoProvider);
  if (p == null) return null;
  return (
    desde: DateTime(p.inicio.year, p.inicio.month, p.inicio.day),
    hasta: DateTime(p.fin.year, p.fin.month, p.fin.day, 23, 59, 59),
  );
});

/// Resumen de asistencia por muchacho a partir de un conjunto de listas.
Map<String, ResumenAsistencia> resumirPorAlumno(
  List<Lista> listas, {
  DateTime? desde,
}) {
  final pases = <String, List<Pase>>{};
  for (final l in listas) {
    if (desde != null && l.fecha.isBefore(desde)) continue;
    l.registros.forEach((alumnoId, registro) {
      (pases[alumnoId] ??= []).add(Pase(l.fecha, registro));
    });
  }
  return pases.map((id, p) => MapEntry(id, resumir(p)));
}

/// Resumen por muchacho en el periodo activo.
final resumenesPeriodoProvider = Provider<Map<String, ResumenAsistencia>>((
  ref,
) {
  final rango = ref.watch(rangoPeriodoProvider);
  if (rango == null) return const {};
  final listas = ref.watch(listasProvider(rango)).value ?? const [];
  return resumirPorAlumno(listas);
});

typedef ClaveAvance = ({String alumnoId, Grado objetivo});

final avanceProvider = StreamProvider.family<Avance, ClaveAvance>((ref, c) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(Avance.vacio(c.objetivo));
  return ref.watch(repoProvider).avance(capId, c.alumnoId, c.objetivo);
});

final evidenciasProvider = StreamProvider.family<List<Evidencia>, String?>((
  ref,
  reunionId,
) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(const []);
  return ref.watch(repoProvider).evidencias(capId, reunionId: reunionId);
});

/// Foto en tamaño completo de una evidencia (se pide solo al abrirla).
final fotoEvidenciaProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  evidenciaId,
) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Future.value(null);
  return ref.watch(repoProvider).fotoDeEvidencia(capId, evidenciaId);
});

final movimientosProvider = StreamProvider<List<Movimiento>>((ref) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(const []);
  return ref.watch(repoProvider).movimientos(capId);
});

final todasLasListasProvider = StreamProvider<List<Lista>>((ref) {
  final capId = ref.watch(capIdProvider);
  if (capId == null) return Stream.value(const []);
  return ref.watch(repoProvider).todasLasListas(capId);
});

final todosLosCapitulosProvider = StreamProvider<List<Capitulo>>(
  (ref) => ref.watch(repoProvider).todosLosCapitulos(),
);
