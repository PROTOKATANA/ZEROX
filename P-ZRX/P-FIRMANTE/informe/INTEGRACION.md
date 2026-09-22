# INTEGRACIÓN — cómo entraría el firmante seguro en `crates/`

**Esto es una propuesta, no una integración hecha.** El encargo §7 lo pide así: «como propuesta:
no lo integres tú». `crates/` es de solo lectura para este encargo y no se ha tocado ni un byte.
Todo lo que sigue son rutas completas desde la raíz y citas a archivos abiertos.

---

## 1 · Qué falta hoy, comprobado abriendo los archivos

| Lo que hace falta | Estado real | Dónde se comprobó |
|---|---|---|
| Un **productor** de bloques DAG que selle cabeceras | **No existe.** No hay ningún sitio que calcule un `pre_hash` fuera de `zx-core` ni que firme un sello | `grep -rn "pre_hash" crates/ --include=*.rs` solo devuelve `crates/zx-core/**`; en `crates/zx-node/src/` no hay productor |
| Una función de **firma** con la clave del productor | **No existe.** `crates/zx-core/src/firma.rs` solo expone `verificar`; la clave privada (`SigningKey`) solo aparece en tests | `crates/zx-core/src/firma.rs`; `grep -rn "SigningKey" crates/` → solo en `#[cfg(test)]` (p. ej. `crates/zx-consensus/src/testigo.rs`) |
| Una **identidad de oportunidad** en código | **No existe.** `C-GD-07` está redactada en `SPEC.md` §11 y la unicidad de billete está en `zx-consensus` solo como color/validación, no como clave de registro | `SPEC.md` líneas 2315–2321; `crates/zx-consensus/src/ghostdag.rs` |
| Una **etiqueta de dominio pública** para la huella de identidad | **No existe y `h_d` es inalcanzable a propósito** | `crates/zx-core/src/hash.rs`: `h_d` es `pub(crate)`; lo único público es `sha3_256_publico`, sin dominio. Por eso el prototipo usa la huella con un **dominio local declarado** (`src/identidad.rs`) |
| Un lugar donde **vivir** la política de producción | **No existe.** `zx-consensus` es consensus-critical; la política de producción (C-GD-10) tampoco está cableada | `crates/zx-consensus/src/lib.rs` (lista de módulos); `ci/consenso-pendiente.txt` ya lista `ghostdag` entero como «sin integrar en zx-node» |

Conclusión: **el firmante seguro no se puede integrar hoy** porque no hay productor al que
engancharse. Lo que sigue es dónde iría cuando lo haya.

---

## 2 · Dónde viviría el código

**Propuesta: un módulo nuevo en `zx-consensus`, `crates/zx-consensus/src/firmante/`**, con los tres
ficheros del prototipo traducidos uno a uno:

```text
crates/zx-consensus/src/firmante/mod.rs        (la política: Firmante, Resultado, FirmanteError)
crates/zx-consensus/src/firmante/identidad.rs  (el trait IdentidadOportunidad + IdentidadTicket)
crates/zx-consensus/src/firmante/registro.rs   (el registro durable)
```

**Por qué `zx-consensus` y no otro:**

- **No** `zx-core`: ese crate es la raíz de tipos y preimagen canónica, y su invariante de diseño es
  que **no** tiene efectos de E/S (`crates/zx-core/src/lib.rs`: «La defensa es la ausencia de una
  firma invocable»). Un registro con `fsync` y `flock` rompería esa frontera.
- **No** `zx-node`: `zx-node` es cableado y es el único crate que ve las cuatro capas; si la política
  viviera ahí, no se podría probar la regla sin levantar el nodo. Los tests de contrato del
  prototipo son de biblioteca.
- **Sí** `zx-consensus`, junto a `bloque_dag.rs` y `ghostdag.rs`: el firmante es **política de
  producción** derivada de reglas que ya viven ahí (`C-GD-04`, `C-GD-07`, `C-GD-10`, `C-HDR-07`), y
  `bloque.rs`/`bloque_dag.rs` son sus vecinos naturales. Aviso de frontera: **no es consenso** — un
  verificador no debe ejecutarlo ni exigirlo—, así que el módulo tiene que llevar esa frontera
  escrita, como la lleva `crates/zx-consensus/src/ghostdag.rs` para lo suyo.

Si se prefiere no tocar `zx-consensus` hasta el encargo 04 (que es donde se integra GHOSTDAG de
verdad), la alternativa es un crate nuevo `crates/zx-firmante/` con dependencia a `zx-core`, y
moverlo después. El prototipo ya está aislado, así que el cambio es de ruta, no de código.

---

## 3 · La llamada que hay que añadir, y dónde

El punto exacto es **entre el ensamblado del candidato y la emisión del sello**, en el productor
que todavía no existe. La forma de la llamada es la del prototipo:

```rust
// En el productor, con el candidato ya ensamblado y su `past` resuelto:
let mut cabecera: DagBlockHeader = ...;          // prefirma completa (padres, cuerpo, PoT)
let identidad = Firmante::identidad(&cabecera);  // C-GD-07/R-FIN-11 hoy
match firmante.firmar(&mut cabecera, &clave_de_productor)? {
    Resultado::Sellado | Resultado::Reemitido => publicar(cabecera),   // solo aquí hay sello
    Resultado::AbstenidoPorConflicto { pre_hash_registrado } => {
        // Descartar el candidato. C-GD-10 (SPEC.md) obliga al productor a descartar de su cola lo
        // que produciría un bloque inválido; esto es lo mismo, en el otro extremo.
        registrar_abstencion(pre_hash_registrado);
    }
}
```

Tres decisiones que esta llamada obliga a tomar y que **no** decide este prototipo:

1. **Quién tiene la clave de firma.** Hoy no hay camino: `zx-core` no firma y `zx-wallet` no firma
   cabeceras. `SigningKey` entra en `zx-consensus` como dependencia normal (hoy es
   `dev-dependencies`, ver `crates/zx-consensus/Cargo.toml`), o se define una frontera
   `FirmadorDeSello` que reciba el `pre_hash` y devuelva los 64 bytes, para que la clave viva en el
   monedero y no en el crate de consenso. **La segunda es más limpia** y encaja con que
   `crates/zx-core/src/firma.rs` sea el único punto de **verificación**. `propuesto`.
2. **Quién arranca el registro y con qué `S_max_slots`.** El valor es del perfil vigente
   (`SPEC.md` §7.3), así que tiene que venir del mismo sitio del que el nodo saca `k`, los límites
   de padres y la ventana de reorg, no de una constante nueva. Hoy no existe ese objeto de
   parámetros en `zx-consensus` (`crates/zx-consensus/src/ghostdag.rs` usa `Parametros` con
   `s_max`; ahí es donde miraría primero). `propuesto`.
3. **Qué pasa con la abstención.** Durante la ventana, el productor no puede producir: hay que
   decidir si eso se registra en el log del nodo, si se expone por RPC y si el nodo arranca igual.
   `no determinado`.

---

## 4 · Tipos que faltan hoy, y qué habría que añadir

| Falta | Dónde iría | Por qué |
|---|---|---|
| `IdentidadOportunidad` (trait) y `IdentidadTicket` (enum) | `crates/zx-consensus/src/firmante/identidad.rs` | Tal cual el prototipo. La definición vigente, `C-GD-07`/R-FIN-11, es la variante por defecto |
| `Registro`, `RegistroError`, `Resolucion` | `crates/zx-consensus/src/firmante/registro.rs` | Tal cual, pero **ver §5.1**: el prototipo usa `libc` para `flock`, y `zx-consensus` hoy no depende de `libc` (`crates/zx-consensus/Cargo.toml`) |
| `Firmante`, `Resultado`, `FirmanteError` | `crates/zx-consensus/src/firmante/mod.rs` | Tal cual |
| Una función de **firma** de sello | `crates/zx-core/src/firma.rs` (junto a `verificar`) o un trait `FirmadorDeSello` en `zx-consensus` | Hoy no hay ninguna; el prototipo firma con `ed25519-zebra` directo, que es el mismo crate que verifica `zx-core`, pero eso deja la clave privada dentro del crate de consenso |
| Una **etiqueta de dominio** para la huella de identidad | `crates/zx-core/src/hash.rs` si algún día se quiere una etiqueta de consenso; **no** hoy | La huella del registro es un marcador local: no entra en ningún `pre_hash` ni viaja por la red. **No debe pasar por `C-HASH-05`** ni añadirse a la tabla de etiquetas de `SPEC.md` §4.5 |
| Constante de `S_max_slots` de producción | Donde viva el perfil de parámetros | `crates/zx-core/src/wire_dag.rs` tiene `MAX_BUNDLES_POT = 150` y `crates/zx-consensus/src/ghostdag.rs` tiene `S_MAX_POR_DEFECTO = 150`; **son dos sitios ya**, y un tercero sería peor. Hay que decidir cuál manda |

**Nada de esto se ha añadido a `crates/`.** El prototipo mantiene su propio `Cargo.lock` porque no
es miembro del workspace (no se podía añadir sin editar `Cargo.toml` en la raíz, que está fuera de
la zona autorizada).

---

## 5 · Lo que hay que decidir antes de integrarlo, y los tests que habría que tocar

### 5.1 · Decisiones de plataforma

1. **`libc` en `zx-consensus`.** El bloqueo entre procesos usa `flock(2)` por FFI porque `std` no
   tiene API de bloqueo de fichero. Alternativas: (i) añadir `libc` como dependencia pineada (ya está
   en `Cargo.lock` de la raíz en la versión 0.2.189); (ii) usar el crate `fs2`/`rustix`, que están en
   el índice local pero **no** en el `Cargo.lock` de la raíz — usarlos obliga a tocar el lock, que es
   la fuente de verdad del árbol consensus-critical (`Cargo.toml` de la raíz, comentario de
   `sha3`); (iii) renunciar al bloqueo entre procesos y aceptar que dos procesos pueden corromper el
   log. **Recomendación: (i).** `propuesto`.
2. **Dónde vive el fichero.** El prototipo escribe donde le digan. En el nodo habría que decidir:
   ruta por defecto, permisos (contiene `pre_hash` y huellas de identidad, no secretos, pero
   revela qué se firmó), qué pasa si el directorio no es escribible (**el nodo no debe arrancar
   productor sin registro**), y si se admite un registro en red (ver §5 del informe: un `fsync` de
   red que mienta anula la garantía).
3. **Formato del registro y migración.** El prototipo tiene `VERSION_FORMATO = 1` y una magia; el
   `VersionInvalida` falla cerrado. Al integrar hay que decidir la política de migración: un
   registro de una versión anterior **no se puede leer en silencio**, y perderlo obliga a la
   abstención de `S_max_slots`.
4. **Cuándo se poda.** El criterio está (`slot + S_max_slots < max_slot`), pero no la frecuencia ni
   el disparador. Si se poda en el camino de producción, la compactación reescribe el log bajo el
   cerrojo y bloquea firmas; fuera de él, hay que decidir el momento.

### 5.2 · Tests del repositorio que habría que tocar

Abiertos y comprobados:

- **`ci/alcance-consenso.sh`** — vigila `zx-consensus` y `zx-storage` buscando funciones públicas que
  nadie llama. `Firmante::firmar` y `Registro::abrir` caerían ahí hasta que exista el productor, así
  que habría que añadirlos a **`ci/consenso-pendiente.txt`** con su motivo, como ya está
  `zx-consensus::bloque::validar_bloque` y todo `ghostdag`. **Sin eso, la CI falla.**
- **`ci/citas-spec.sh`** — busca reglas del `SPEC.md` que ningún código cita. El firmante cita
  `C-GD-04`, `C-GD-07` y `C-HDR-07`; si esas citas no aparecen en el código integrado, el guardián lo
  dirá. Los comentarios del prototipo las citan una a una por número (no en rango).
- **`ci/reglas-sin-cablear.txt`** / **`ci/reglas-sin-codigo.txt`** — no hay regla nueva que declarar:
  el firmante **no** es una regla de consenso y no propone texto de `SPEC.md`.
- **`ci/frontera-crates.sh`** y **`ci/dependencias-exactas.sh`** — el módulo nuevo añadiría la
  dependencia `libc` (o la que se decida) y habría que pasarlos.
- **`crates/zx-consensus/tests/`** — los tests de contrato del prototipo
  (`prototipo/tests/firmante_contrato.rs`) se pueden mover casi tal cual; el único punto a adaptar
  es el dispositivo de aborto, que re-ejecuta el **binario de test** y en el repositorio tendría que
  ser un test de integración de `zx-consensus`. Los tres puntos de entrada `#[ignore]` no deberían
  quedarse en la CI del repositorio sin revisar: abortan el proceso a propósito.
- **`crates/zx-core/tests/vectores_dag.rs`** y **`parsers_dag_prop.rs`** — no habría que tocarlos:
  el firmante no cambia ninguna codificación. Si algún día la identidad entrara en la cabecera, sí.
- **`SPEC.md`** — **no se toca.** El encargo §8 lo prohíbe y no hay nada que proponer: esto es un
  requisito de producción, no una regla.

### 5.3 · Riesgo de obsolescencia, dicho claro

El trabajo **no caduca si Katana cambia de identidad**: por eso es un punto de extensión con dos
implementaciones y un `enum`. Lo que sí caduca es:

- **el valor de `S_max_slots`**: si cambia, cambian la abstención y el horizonte de poda, y hay que
  volver a pasar el parámetro (no hay ninguna constante escondida);
- **el formato del registro**: si cambia `VERSION_ESQUEMA` o el conjunto de campos de la identidad,
  los registros viejos se leen como versión distinta y hay que decidir si se migran o se declaran
  perdidos (con su abstención);
- **la ventana de producción**: si `C-GD-04` cambiara de `S_max` a otra métrica, el criterio de poda
  y la abstención habría que rederivarlos, no reajustarlos.

---

## 6 · Resumen de la propuesta, en una tabla

| Pregunta | Respuesta propuesta |
|---|---|
| ¿Qué crate lo aloja? | `zx-consensus`, módulo `firmante/` (o crate propio `zx-firmante` si se quiere aislar hasta el encargo 04) |
| ¿Qué llamada se añade y dónde? | `Firmante::firmar(&mut cabecera, &clave)` entre el ensamblado del candidato y la publicación, en el productor que todavía no existe |
| ¿Qué tipos faltan hoy? | El trait de identidad y sus dos implementaciones; el registro; la política; una función de firma de sello; el parámetro `S_max_slots` del perfil |
| ¿Qué tests del repositorio se tocan? | `ci/consenso-pendiente.txt` (obligatorio), los guardianes de CI, y el traslado de `tests/firmante_contrato.rs` a `crates/zx-consensus/tests/` |
| ¿Se toca el consenso? | **No.** No fija parámetros, no entra en ningún `pre_hash`, no viaja por la red y ningún verificador lo ejecuta |
| ¿Se toca `SPEC.md`? | **No.** El encargo §8 lo prohíbe expresamente |
