# REVISIÓN W06b (+ Corrección A) — `zx-storage`: bloques admitidos y repetición al reiniciar

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek (W06b 04:11–04:45;
Corrección A 04:46–05:03). Evidencia: `resultados-W06b/`.

**Veredicto: SUPERADO tras la Corrección A. Migrada** mediante el rebase W06b-R (su base precedía a
W05b3 y W06a, que tocaron `Cargo.toml` y la frontera).

## Comprobado por el director

- `ENTRADA-W06b.sha256` 4/4; base idéntica a la raíz de las 04:11.
- Lock: +17 paquetes, 0 versiones cambiadas, todos a la versión de `9681061` (`logs/lock-diff.txt`).
- `tests/matar_a_mitad.rs`: proceso hijo que admite con `sync = true` y recibe `SIGKILL` tras una espera
  pseudoaleatoria de semilla fija; 64 rondas, siempre prefijo exacto, y el test falla si todas mueren en
  el mismo punto (el `kill` no puede estar sincronizado con la escritura).
- Admisión atómica (`WriteBatch` bloque + registro), idempotencia por hash con comprobación **dentro**
  del cerrojo (el ejecutor corrigió una carrera propia y añadió 2 tests de concurrencia).
- **Hallazgo del director (Corrección A):** la integridad solo recalculaba el hash de la cabecera; un
  bit cambiado en el cuerpo (p. ej. la coinbase, sin firma) habría pasado y la repetición sin
  re-verificación (D-N03′) habría reconstruido otro estado en silencio. Causa: la letra de mi orden
  («integridad por hash»). Tras la corrección, `hash_canonico` recalcula `merkle_root(txids)` (PoW) y
  `body_commitment` sobre `(txid, auth_digest)` (PoST); `StorageError::CuerpoNoCoincide`; tests (a)–(d)
  detectan importe de coinbase PoW y PoST, campo de transacción y testigo PoST.

## Límite que queda (declarado y probado en su lado del almacén)

Los **testigos de un bloque PoW** no están comprometidos en su cabecera (el `txid` los excluye,
C-TX-01): el almacén no detecta su corrupción (test (e)). El ejecutor afirma que lo detectaría la
verificación de firmas del motor al repetir; **no está probado**: se añade como prueba obligatoria de
W06d1 (reinicio con un testigo PoW corrupto ⇒ el nodo se niega a arrancar con error explícito).

## Medidas (V7, release, 10 000 bloques dev, carga ajena)

Admisión 0,047 s en total (≈ 213 000 admisiones/s), apertura 0,043 s, repetición 0,025 s, tras la
Corrección A (antes 0,034 / 0,030 / 0,011 s). No incluyen la re-ejecución de estado de `zx-cadena`.

## Migración (05:30)

Rebase W06b-R (DeepSeek, 05:04–05:26): `crates/zx-storage` byte a byte igual al revisado; solo se
rehicieron `Cargo.toml` (miembro, `rocksdb =0.25.0`, `tempfile =3.24.0`), `ci/frontera-crates.sh`
(8 fronteras) y el lock (+17 paquetes, 0 versiones cambiadas). Suite completa con `--locked`:
**680 pasan, 0 fallan, 2 ignorados**; es también la **primera ejecución completa de la raíz con W05b3
y W06a juntas** (0 perdidos, 20 añadidos). `MIGRACION.sha256` (181 archivos) verificado en la raíz.
