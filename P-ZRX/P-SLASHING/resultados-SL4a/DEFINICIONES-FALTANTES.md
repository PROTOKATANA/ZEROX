# DEFINICIONES-FALTANTES — ORDEN-SL4a

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Fecha:** 2026-09-26.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/SL4a/`. Se registran **antes** de editar, como exige el
encargo. Cada una lleva la decisión tomada y su justificación; ninguna se resuelve en silencio.

## FD-1 · `incident_id`: el contrato y el oráculo no coinciden

- **Contrato** (`CONTRATO-EVIDENCIA-v0.md`, EV-10 y §1):
  `incident_id = H_d(dom_incidente, bytes_canónicos(identidad(H1)))`, con
  `dom_incidente = "ZZKEvpIncidente_"` en la tabla `TAGS_FIJAS` (SHA3-256 con dominio).
- **Oráculo ratificado SL-3b** (`P-TRANSICION/T01/src/Transicion.jl:974`) implementa
  `bytes2hex(sha256("ZZKEvpIncidente_" ‖ cbid ‖ "|" ‖ clave ‖ "|" ‖ sector ‖ "|" ‖ historia ‖ "|" ‖ chunk ‖ "|" ‖ slot))`,
  es decir **SHA-256 desnudo** (no SHA3-256) sobre la concatenación **decimal** separada por `|`.
  El comentario del propio oráculo lo declara «marcador determinista […] AMBIGUEDAD-SL3-5».
- **Impacto:** los vectores `T01 v0.4` y `T04 v0.5` escriben el `incident_id` en el campo `inc=`
  de la línea `GAR` (p. ej. `inc=98961681…@2`). Reproducir el vector *byte a byte* exige la fórmula
  del oráculo; cumplir el contrato exige `H_d`. Además, el oráculo indexa por el **entero abstracto**
  `clave`/`chunk`, que la cabecera real no permite recuperar (lleva `public_key` y `chunk` de 32 B).
- **Decisión:** el motor Rust implementa la fórmula del **contrato** (con bytes canónicos de la
  identidad real), porque es la única calculable desde una cabecera real; el arnés diferencial trata
  el `incident_id` como **opaco** y compara la parte estructural del campo `inc=` (número de
  incidentes y sus `@slot_falta`), no el hex. Se declara en `INFORME.md` y `PROGRESO.md`. Si el
  director quiere el hex exacto, hay que cambiar EV-10 a la fórmula del oráculo.

## FD-2 · `ErrCbidAjeno` frente a `ErrForma` (RAT-1)

- **RAT-1** dice que una evidencia con `consensus_branch_id` ajeno es «`ErrForma` (no es evidencia de
  esta red)».
- El **oráculo** y la **cobertura** usan una variante propia `ErrCbidAjeno` (descartada en la fusión
  sin invalidar el bloque), que es la que permite reproducir `cobertura-v0.4/0.5`.
- **Decisión:** se sigue el oráculo (`ErrCbidAjeno`), que es lo que el encargo exige reproducir; se
  documenta la correspondencia en `ErrorTransicion`/`INFORME.md`.

## FD-3 · `Plazo_slots` y `M_margen_slots` sin valor calibrado

- La orden (§2.2) pide «`Plazo_slots`, `M_margen_slots` con la desigualdad de RAT-3 comprobada como
  puerta», pero `REVISION-SL2b.md` **no fija** esos dos valores (lo dice `SL2/DEFINICIONES-FALTANTES-SL2b.md`
  G6: «`Plazo_slots` sigue sin valor», «No fija `Plazo_slots` ni `M_margen_slots` (SL-1)»).
- **Decisión:** `ParametrosTransicion` gana los campos; el perfil dev de los tests usa valores
  provisionales que cumplen la puerta `R_slots > Plazo_slots + M_margen_slots` (documentados en
  `INFORME.md`), y los diferenciales usan **los valores de cada vector**. No se inventa una
  calibración: queda declarada como pendiente de SL-2.

## FD-4 · `validar_forma_tx` no conoce el perfil de activación

- El contrato (EV-04) dice que la v4 deja de ser `ErrVersionInactiva` «cuando `C-EVP` se active», es
  decir cuando `evp` esté activo; pero `zx_core::validar_forma_tx` es **sin contexto** y no recibe
  perfil ni red.
- **Decisión:** se añade `validar_forma_tx_v4` (forma de la v4, sin activación) y el motor decide
  según `ParametrosTransicion::evp`; `validar_forma_tx` conserva su comportamiento previo
  (`ErrVersionInactiva` para v4) para no romper a los llamantes sin perfil.

## FD-5 · Formato de wire de v4 no especificado

- EV-02 habla de «la cabecera mínima de wire de la transacción (`n_in=0`, `n_out=0`, `n_wit=0`)»,
  pero **no define** cómo viajan por wire las dos cabeceras `PoAS_PoT_DAG` completas (el formato F-14
  no tiene un campo de extensión de v4). `wire.rs::tx_desde_bytes` rechaza hoy la v4.
- **Decisión:** se implementa la forma **tipada** (`ExtensionTx::Evidencia { h1, h2 }`) y la
  validación de forma; el códec de wire queda fuera de alcance en esta orden y se declara. El arnés
  construye las `Tx` directamente, como ya hacía.

## FD-6 · `cobertura-v0.4.txt` de T01 no está en la entrada congelada

- `ENTRADA-SL4a.sha256` incluye `vectores-transicion-v0.4.txt`, `vectores-estado-dag-v0.5.txt` y
  `cobertura-v0.5.txt`, pero **no** `cobertura-v0.4.txt`, aunque la orden §2.4 la menciona («si
  existe»). El fichero existe en `P-ZRX/P-TRANSICION/T01/resultados/cobertura-v0.4.txt`.
- **Decisión:** se usa el fichero existente como referencia de la tabla de cobertura de T01.

## FD-7 · No hay negativos v0.4 de T01

- La entrada congelada solo trae `vectores-transicion-v0.4.txt` (2795 casos) y los negativos siguen
  siendo `vectores-transicion-negativos-v0.2.txt`. Los casos de error de evidencia están en el
  fichero base v0.4.
- **Decisión:** el test `diferencial_t01` lee v0.4; `diferencial_t01_negativos` sigue leyendo los
  negativos v0.2 (sin cambios), tal como permite la entrada.
