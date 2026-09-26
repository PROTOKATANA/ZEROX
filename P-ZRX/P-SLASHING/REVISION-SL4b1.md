# REVISIÓN SL-4b1 — firmante seguro portado a `zx-post` con identidad RAT-1

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 00:04). **Ejecutor:** DeepSeek, 22:53–00:00.
Evidencia: `resultados-SL4b1/` (informe, definiciones faltantes, parche de 10 archivos, `MIGRACION.sha256`,
registros de coste y de la suite, con huellas). **Veredicto: SUPERADO.** **Migración: en espera** hasta que
W06d5 migre (regla del traspaso: nada a `crates/` mientras W06d5 siga vivo).

## Comprobado por el director (lectura del código de la zona)

- `Firmante::firmar` (FIR-01, FIR-04, FIR-05): comprueba la clave contra `sol.public_key` antes de tocar el
  registro; `Registro::resolver` escribe y hace `sync_all` antes de devolver `Nueva` (el índice en memoria
  solo cambia tras el `sync_all`); firma solo después; verifica el sello sobre una copia. La abstención por
  pérdida es un **resultado** (`AbstenidoPorPerdida`), no un error de E/S.
- Identidad RAT-1 con `consensus_branch_id`, dominio `ZXRFIRM/ticket-rat1/cbid-c-gd-07`, esquema v2.
- Los tres tests nuevos con `#[ignore]` llevan motivo (dos entradas de proceso hijo, un banco de coste).
- Parche limitado a `zx-post` (10 archivos); `Cargo.toml`/`Cargo.lock` intactos; suite de la zona 789/0/5.

## Resultado

V2 durabilidad con proceso hijo abortado entre reserva y firma **20/20**; V3 falla cerrado ante cola a ceros,
cola parcial y bit cambiado; V5 identidad del firmante ⟺ `incident_id_evidencia` (12/12, seis campos más tres
ajenos, evidencia aplicada de verdad en el motor); V6 reemisión idéntica, conflicto sin sello, bloque que
pasa la puerta conjunta.

## Decisiones sobre sus faltas de definición

- **DF-1** (`ProductoFirmado::Bloque(BloqueDag, Resultado)`): ratificada.
- **DF-9** (borde de la abstención): el código antiguo usa `slot <= abstener_hasta` con
  `abstener_hasta = slot_perdida + S_max` (último slot abstenido); **mi V4 estaba desfasada en uno**. Se
  ratifica el borde inclusivo (un slot más conservador). SL-4b2 V6 se corrige en consecuencia.
- Resto (DF-2…DF-8): lecturas mínimas, ratificadas.

## Medida

`firmar` con `fsync` (n = 2 000, disco de la zona, btrfs, **con los nodos de W06d5 cargando la máquina**):
mediana **3,697 ms**, p99 **4,636 ms**; el prototipo midió 0,81 ms en reposo (FIR-14). Es el 0,2 % de un slot
de 1,66 s: no cambia la decisión de no usar `fdatasync`. Se repetirá sin carga en W07b si hace falta.

## Interacción con SL-4c

`tests/firmante_identidad_evidencia.rs` llama a `validar_forma_tx_v4` con la firma actual y espera
`ErrCbidAjeno`; SL-4c cambia las dos cosas. Se adaptará al migrar SL-4c (orden de rebase).

## Migración (2026-09-27 ≈ 00:42, tras `e2eee98` de W06d5)

Por parche (`git apply -p1`, 10 rutas, todas en `crates/zx-post/`); base de la raíz idéntica a `ws.orig` en los
tres archivos modificados; `MIGRACION.sha256` 10/10 en la raíz; `crates/zx-post` idéntico a `ws/crates/zx-post`.
Sin cambios en `Cargo.*` ni `testdata/`. La suite conjunta con W06d5 la ejecuta el paso 0 de la siguiente orden
de código.
