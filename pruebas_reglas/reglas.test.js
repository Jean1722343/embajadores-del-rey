// Pruebas de las reglas de seguridad de Firestore contra el emulador.
// Se corren con: npm test (dentro de pruebas_reglas).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Bytes,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

let env;
const enDias = (n) => Timestamp.fromDate(new Date(Date.now() + n * 86400000));
const db = (uid) => env.authenticatedContext(uid).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-embajadores',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

// Capítulo A con líder y consejero; capítulo B con su propio líder.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const d = ctx.firestore();
    for (const u of ['liderA', 'consejeroA', 'liderB', 'nuevo', 'jefe']) {
      await setDoc(doc(d, 'usuarios', u), { nombre: u, capitulos: [] });
    }
    await updateDoc(doc(d, 'usuarios/jefe'), { superAdmin: true });
    for (const [cap, lider] of [['A', 'liderA'], ['B', 'liderB']]) {
      await setDoc(doc(d, 'capitulos', cap), {
        nombre: cap, creadoPor: lider, suspendido: false,
      });
      await setDoc(doc(d, `capitulos/${cap}/miembros/${lider}`), {
        nombre: lider, rol: 'lider', activo: true,
      });
    }
    await setDoc(doc(d, 'capitulos/A/miembros/consejeroA'), {
      nombre: 'consejeroA', rol: 'consejero', activo: true,
    });
    await setDoc(doc(d, 'capitulos/A/alumnos/juan'), { nombre: 'Juan' });
    await setDoc(doc(d, 'invitaciones/VIGENT'), {
      capituloId: 'A', rol: 'consejero', activa: true, expiraEn: enDias(7),
    });
    await setDoc(doc(d, 'invitaciones/VENCID'), {
      capituloId: 'A', rol: 'consejero', activa: true, expiraEn: enDias(-1),
    });
    await setDoc(doc(d, 'invitaciones/ANULAD'), {
      capituloId: 'A', rol: 'consejero', activa: false, expiraEn: enDias(7),
    });
  });
});

const miembro = (rol, codigo) => ({
  nombre: 'nuevo', rol, activo: true, ...(codigo && { codigoUsado: codigo }),
});

test('sin sesión no se lee nada', async () => {
  const d = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(d, 'capitulos/A')));
  await assertFails(getDoc(doc(d, 'capitulos/A/alumnos/juan')));
  await assertFails(getDoc(doc(d, 'invitaciones/VIGENT')));
});

test('los miembros leen a sus muchachos; los de otro capítulo no', async () => {
  await assertSucceeds(getDoc(doc(db('consejeroA'), 'capitulos/A/alumnos/juan')));
  await assertFails(getDoc(doc(db('liderB'), 'capitulos/A/alumnos/juan')));
  await assertFails(getDocs(collection(db('liderB'), 'capitulos/A/alumnos')));
  await assertFails(getDoc(doc(db('nuevo'), 'capitulos/A')));
});

test('cualquiera crea su capítulo y queda como líder en la misma operación', async () => {
  const d = db('nuevo');
  const lote = writeBatch(d);
  lote.set(doc(d, 'capitulos/C'), {
    nombre: 'C', creadoPor: 'nuevo', suspendido: false,
  });
  lote.set(doc(d, 'capitulos/C/miembros/nuevo'), miembro('lider'));
  await assertSucceeds(lote.commit());
});

test('nadie crea un capítulo a nombre de otro ni se hace líder de uno ajeno', async () => {
  const d = db('nuevo');
  await assertFails(setDoc(doc(d, 'capitulos/C'), {
    nombre: 'C', creadoPor: 'liderA', suspendido: false,
  }));
  await assertFails(setDoc(doc(d, 'capitulos/A/miembros/nuevo'), miembro('lider')));
  await assertFails(setDoc(doc(d, 'capitulos/A/miembros/nuevo'), miembro('consejero')));
});

test('con código vigente se entra, y solo con el rol del código', async () => {
  const d = db('nuevo');
  await assertSucceeds(getDoc(doc(d, 'invitaciones/VIGENT')));
  await assertFails(
    setDoc(doc(d, 'capitulos/A/miembros/nuevo'), miembro('lider', 'VIGENT')),
  );
  await assertFails(
    setDoc(doc(d, 'capitulos/B/miembros/nuevo'), miembro('consejero', 'VIGENT')),
  );
  await assertSucceeds(
    setDoc(doc(d, 'capitulos/A/miembros/nuevo'), miembro('consejero', 'VIGENT')),
  );
  await assertSucceeds(getDoc(doc(d, 'capitulos/A/alumnos/juan')));
});

test('un código vencido, anulado o inexistente no deja entrar', async () => {
  const d = db('nuevo');
  for (const codigo of ['VENCID', 'ANULAD', 'NOEXIS']) {
    await assertFails(
      setDoc(doc(d, 'capitulos/A/miembros/nuevo'), miembro('consejero', codigo)),
    );
  }
});

test('las invitaciones no se pueden listar desde fuera', async () => {
  await assertFails(getDocs(collection(db('nuevo'), 'invitaciones')));
  await assertFails(getDocs(query(
    collection(db('nuevo'), 'invitaciones'), where('capituloId', '==', 'A'),
  )));
  await assertSucceeds(getDocs(query(
    collection(db('liderA'), 'invitaciones'), where('capituloId', '==', 'A'),
  )));
});

test('cualquier miembro invita consejeros; solo el líder invita líderes', async () => {
  const inv = (cap, rol = 'consejero') => ({
    capituloId: cap, rol, activa: true, expiraEn: enDias(7),
  });
  await assertSucceeds(setDoc(doc(db('consejeroA'), 'invitaciones/NUEVA1'), inv('A')));
  await assertFails(setDoc(doc(db('consejeroA'), 'invitaciones/NUEVA4'), inv('A', 'lider')));
  await assertFails(setDoc(doc(db('liderB'), 'invitaciones/NUEVA2'), inv('A')));
  await assertSucceeds(setDoc(doc(db('liderA'), 'invitaciones/NUEVA3'), inv('A', 'lider')));
  await assertSucceeds(updateDoc(doc(db('consejeroA'), 'invitaciones/VIGENT'), { activa: false }));
  await assertFails(updateDoc(doc(db('consejeroA'), 'invitaciones/NUEVA1'), { rol: 'lider' }));
  await assertFails(deleteDoc(doc(db('consejeroA'), 'invitaciones/NUEVA1')));
});

test('el consejero pasa lista de cualquier grupo, firmando como él mismo', async () => {
  const d = db('consejeroA');
  const lista = (uid) => ({
    reunionId: '2027-01-09', grupoId: 'g1', tomadaPor: uid,
    registros: { juan: { presente: true, biblia: false, ofrenda: false } },
  });
  await assertSucceeds(setDoc(doc(d, 'capitulos/A/listas/2027-01-09_g1'), lista('consejeroA')));
  await assertFails(setDoc(doc(d, 'capitulos/A/listas/2027-01-09_g2'), lista('liderA')));
  await assertFails(setDoc(doc(db('liderB'), 'capitulos/A/listas/2027-01-09_g3'), lista('liderB')));
});

test('el consejero administra igual que el líder, pero no borra ni cambia roles', async () => {
  const d = db('consejeroA');
  await assertSucceeds(setDoc(doc(d, 'capitulos/A/grupos/g1'), { nombre: 'x' }));
  await assertSucceeds(setDoc(doc(d, 'capitulos/A/periodos/p1'), { nombre: 'x' }));
  await assertSucceeds(updateDoc(doc(d, 'capitulos/A/grupos/g1'), { nombre: 'y' }));
  await assertSucceeds(setDoc(doc(d, 'capitulos/A/alumnos/pedro'), { nombre: 'Pedro' }));
  await assertFails(deleteDoc(doc(d, 'capitulos/A/grupos/g1')));
  await assertFails(deleteDoc(doc(d, 'capitulos/A/periodos/p1')));
  await assertFails(deleteDoc(doc(d, 'capitulos/A/alumnos/juan')));
  await assertFails(updateDoc(doc(d, 'capitulos/A/miembros/consejeroA'), { rol: 'lider' }));
  await assertFails(updateDoc(doc(d, 'capitulos/A/miembros/liderA'), { activo: false }));
});

test('el líder puede borrar todo para empezar de nuevo', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'capitulos/A/grupos/g1'), { nombre: 'x' });
    await setDoc(doc(d, 'capitulos/A/periodos/p1'), { nombre: 'x' });
    await setDoc(doc(d, 'capitulos/A/listas/l1'), { tomadaPor: 'consejeroA' });
    await setDoc(doc(d, 'capitulos/A/reuniones/r1'), { titulo: '' });
    await setDoc(doc(d, 'capitulos/A/alumnos/juan/avances/paje'), { hechos: {} });
    await setDoc(doc(d, 'capitulos/A/fotos/f1'), { subidaPor: 'consejeroA' });
    await setDoc(doc(d, 'capitulos/A/evidencias/f1'), { subidaPor: 'consejeroA' });
  });
  const d = db('liderA');
  for (const ruta of ['grupos/g1', 'periodos/p1', 'listas/l1', 'reuniones/r1',
    'alumnos/juan/avances/paje', 'alumnos/juan', 'fotos/f1', 'evidencias/f1']) {
    await assertSucceeds(deleteDoc(doc(d, `capitulos/A/${ruta}`)));
  }
  await assertFails(deleteDoc(doc(db('liderB'), 'capitulos/A/miembros/consejeroA')));
});

test('un consejero sin acceso deja de ver el capítulo', async () => {
  await assertSucceeds(
    updateDoc(doc(db('liderA'), 'capitulos/A/miembros/consejeroA'), { activo: false }),
  );
  await assertFails(getDoc(doc(db('consejeroA'), 'capitulos/A/alumnos/juan')));
});

test('las evidencias las borra quien las subió o el líder', async () => {
  const ev = { reunionId: '2027-01-09', url: 'u', subidaPor: 'consejeroA' };
  await assertSucceeds(setDoc(doc(db('consejeroA'), 'capitulos/A/evidencias/e1'), ev));
  await assertFails(setDoc(doc(db('consejeroA'), 'capitulos/A/evidencias/e2'), {
    ...ev, subidaPor: 'liderA',
  }));
  await assertFails(deleteDoc(doc(db('liderB'), 'capitulos/A/evidencias/e1')));
  await assertSucceeds(deleteDoc(doc(db('liderA'), 'capitulos/A/evidencias/e1')));
});

test('nadie se nombra super administrador', async () => {
  await assertFails(updateDoc(doc(db('nuevo'), 'usuarios/nuevo'), { superAdmin: true }));
  await assertFails(setDoc(doc(db('otro'), 'usuarios/otro'), { nombre: 'x', superAdmin: true }));
  await assertSucceeds(setDoc(doc(db('otro'), 'usuarios/otro'), { nombre: 'x', capitulos: [] }));
  await assertFails(getDoc(doc(db('nuevo'), 'usuarios/liderA')));
});

test('solo el super administrador suspende, y la suspensión corta el acceso', async () => {
  await assertFails(updateDoc(doc(db('liderA'), 'capitulos/A'), { suspendido: true }));
  await assertFails(getDocs(collection(db('liderA'), 'capitulos')));
  await assertSucceeds(getDocs(collection(db('jefe'), 'capitulos')));
  await assertFails(updateDoc(doc(db('jefe'), 'capitulos/A'), { nombre: 'otro' }));
  await assertSucceeds(updateDoc(doc(db('jefe'), 'capitulos/A'), { suspendido: true }));
  await assertFails(getDoc(doc(db('consejeroA'), 'capitulos/A/alumnos/juan')));
  await assertFails(
    setDoc(doc(db('nuevo'), 'capitulos/A/miembros/nuevo'), miembro('consejero', 'VIGENT')),
  );
});

test('las fotos grandes las guarda y lee solo el capítulo, con tope de peso', async () => {
  const foto = (uid, kb) => ({
    subidaPor: uid, bytes: Bytes.fromUint8Array(new Uint8Array(kb * 1024)),
  });
  await assertSucceeds(setDoc(doc(db('consejeroA'), 'capitulos/A/fotos/e1'), foto('consejeroA', 200)));
  await assertFails(setDoc(doc(db('consejeroA'), 'capitulos/A/fotos/e2'), foto('consejeroA', 950)));
  await assertFails(setDoc(doc(db('consejeroA'), 'capitulos/A/fotos/e3'), foto('liderA', 10)));
  await assertFails(setDoc(doc(db('liderB'), 'capitulos/A/fotos/e4'), foto('liderB', 10)));
  await assertSucceeds(getDoc(doc(db('liderA'), 'capitulos/A/fotos/e1')));
  await assertFails(getDoc(doc(db('liderB'), 'capitulos/A/fotos/e1')));
  await assertSucceeds(deleteDoc(doc(db('consejeroA'), 'capitulos/A/fotos/e1')));
});

test('la caja: cualquier miembro registra a su nombre, nadie edita y solo el líder borra', async () => {
  const mov = (uid, extra = {}) => ({
    tipo: 'ingreso', monto: 150, concepto: 'Venta de tamales',
    registradoPor: uid, ...extra,
  });
  const c = db('consejeroA');
  await assertSucceeds(setDoc(doc(c, 'capitulos/A/movimientos/m1'), mov('consejeroA')));
  await assertSucceeds(setDoc(doc(c, 'capitulos/A/movimientos/m2'), mov('consejeroA', { tipo: 'egreso' })));
  await assertFails(setDoc(doc(c, 'capitulos/A/movimientos/m3'), mov('liderA')));
  await assertFails(setDoc(doc(c, 'capitulos/A/movimientos/m4'), mov('consejeroA', { monto: -5 })));
  await assertFails(setDoc(doc(c, 'capitulos/A/movimientos/m5'), mov('consejeroA', { concepto: '' })));
  await assertFails(setDoc(doc(c, 'capitulos/A/movimientos/m6'), mov('consejeroA', { tipo: 'regalo' })));
  await assertFails(updateDoc(doc(c, 'capitulos/A/movimientos/m1'), { monto: 9999 }));
  await assertFails(deleteDoc(doc(c, 'capitulos/A/movimientos/m1')));
  await assertFails(getDoc(doc(db('liderB'), 'capitulos/A/movimientos/m1')));
  await assertFails(setDoc(doc(db('liderB'), 'capitulos/A/movimientos/m7'), mov('liderB')));
  await assertSucceeds(deleteDoc(doc(db('liderA'), 'capitulos/A/movimientos/m1')));
});
