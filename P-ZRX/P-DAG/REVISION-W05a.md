# Revisión del director — W05a (2026-09-26)

**Veredicto: SUPERADO y migrado a la raíz** (02:10). DeepSeek, 01:56–02:09.

Crate `zx-dag` (GHOSTDAG, padres contextuales, rango validado, vista causal, identidad de billete),
dependiente solo de `zx-core`. Oráculos antiguos reproducidos: GDR-v0.2 (28 DAGs, referencia y
kernel) y rusty-kaspa (180 comprobaciones). 371 tests en el workspace, 0 fallos; los 265 previos con
su nombre.

Revisado por el director: `comprobar_padres_contextual` aplica D-P08 en orden — sin padres ⇒
`CabeceraPostSinPadres` incondicional; si el padre seleccionado es el terminal, un solo padre; el
terminal nunca como padre extra; cualquier otro padre debe estar validado en el contexto. Tests
sustituidos (6) y retirados (2) justificados uno a uno; ningún test de lógica GHOSTDAG retirado.

**Obligaciones que pasan a otras órdenes:**
- **W06:** el contexto real (`ContextoDag`) no puede devolver `es_bloque_validado = true` para un
  bloque PoW; la regla de padres lo delega en él. Portar `FuenteIndiceAdmitidos` sobre el almacén.
- **W03/W05b:** recuperar el test retirado `un_testigo_invalido_puede_coincidir_con_el_compromiso`
  cuando exista `testigo::satisface`.

Base de DeepSeek idéntica a la raíz; `MIGRACION.sha256` (87 archivos) verificado en la raíz;
`Cargo.lock` solo añade `zx-dag`.
