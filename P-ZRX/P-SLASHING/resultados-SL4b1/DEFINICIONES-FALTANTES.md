# DEFINICIONES-FALTANTES — ORDEN-SL4b1

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Zona:** `/home/katana/zeo/ZEROX/deepseek/SL4b1/`.
**Fecha de apertura:** 2026-09-26.

Se listan **antes de editar** los puntos que la orden deja abiertos o ambiguos, con la lectura
adoptada. Ninguna amplía el alcance ni toca archivos vedados.

## DF-1 · Forma del resultado de los productores `_con_firmante`

La orden §3.6 pide «un resultado que distingue `Bloque(BloqueDag)` de `Abstenido { motivo }`», pero
V6(a) exige observar `Reemitido` **a través del productor** («segunda llamada → `Reemitido` y bloque
idéntico byte a byte»), y §3.4 sitúa `Sellado`/`Reemitido` como resultados del firmante. Un enum de
solo dos variantes no deja observar `Reemitido` en el productor.

**Lectura adoptada:** se expone el veredicto del firmante dentro de la variante de bloque:

```rust
pub enum ProductoFirmado {
    Bloque(BloqueDag, Resultado),          // Sellado o Reemitido
    Abstenido { motivo: MotivoAbstencion }, // Conflicto o Pérdida de registro
}
```

Así se distingue `Bloque` de `Abstenido` (orden §3.6) y V6(a) puede nombrar `Reemitido`.

## DF-2 · Firma de `Registro::nueva`

La orden §3.5 escribe literalmente `Registro::nueva(ruta)` (sin `s_max_slots`), mientras §3.3 dice que
`S_max_slots` entra como argumento y no como constante. La ruta `nueva` **no** se abstiene nunca, así
que el valor de `s_max_slots` no decide ninguna firma.

**Lectura adoptada:** se respeta la firma literal `nueva(ruta)` y la instancia guarda
`s_max_slots = 0`, documentando que ese valor es inerte porque la abstención está inactiva. Si la
dirección prefería `nueva(ruta, s_max_slots)`, el cambio es de una línea.

## DF-3 · Abstención por pérdida como resultado, no como error de E/S

§3.4 pide la abstención por pérdida (FIR-10) «como resultado distinto de un error de E/S».

**Lectura adoptada:** `Registro::resolver` conserva `RegistroError::EnAbstinencia` (que no es E/S),
pero `Firmante::firmar` lo traduce a `Resultado::AbstenidoPorPerdida { hasta, s_max_slots }`; el
productor lo traduce a `MotivoAbstencion::PerdidaRegistro`. Los fallos de E/S del registro siguen
siendo `Err`.

## DF-4 · Los tests de durabilidad y de recuperación necesitan el interior del módulo

V2 (proceso hijo que reserva y aborta) y V3 (cola a cero / bit cambiado) requieren
`Registro::resolver`/`abrir_con_politica` e inyección de E/S, que son `pub(crate)`/privados, y el
proceso hijo debe re-ejecutar el binario de test. Los tests externos `tests/firmante*.rs` solo ven la
API pública.

**Lectura adoptada:** se reparten como en el código antiguo: la durabilidad con proceso hijo y la
inyección de E/S viven en los `#[cfg(test)]` de `src/firmante/**` (permitido por §4), y el contrato
público portado vive en `tests/firmante_publico.rs`. La cobertura de cada variante se cuenta en el
informe, no depende de dónde viva el test.

## DF-5 · Cobertura de `FirmanteError::SelloInvalido`

Con Ed25519 correcto y la comprobación previa de clave (FIR-04), el sello construido **siempre**
verifica, así que `SelloInvalido` es inalcanzable por la API pública. La tabla de cobertura exige
mínimo 1 caso por fila.

**Lectura adoptada:** se añade una inyección **solo de test** (`#[cfg(test)]`, `AtomicBool`) que
corrompe el sello de la copia antes de `verificar_sello`, sin afectar a la cabecera de entrada ni al
camino de producción. No hay ninguna ruta no-test que convierta un `Ok` ficticio en real.

## DF-6 · Etiqueta de la suite que no cambia de sitio

La orden §4 permite `crates/zx-post/tests/firmante*.rs` (nuevos) y `crates/zx-post/src/firmante/**`.
No autoriza modificar los tests existentes (`regimen.rs`, `extremo_a_extremo.rs`, …). El fixture real
de PoAS/PoT/KZG que V6(c) necesita se **duplica** en un test nuevo, no se toca `regimen.rs`.

## DF-7 · Anchura de `consensus_branch_id` en la huella

La orden fija el orden `(consensus_branch_id, public_key, sector_index, history_size, chunk, slot)` y
«campos de anchura fija», pero no el ancho del `cbid`. `incident_id_evidencia` (la identidad de la
evidencia, RAT-1) codifica `cbid` como `u32` LE, así que se usa `u32` LE para que la igualdad de
oportunidades del firmante y la de la evidencia sean la misma relación.

## DF-8 · Nombre del constructor de la identidad

El código antiguo exponía `IdentidadTicket::vigente(...)`; la orden renombra la identidad a RAT-1
(`cbid` incluido). Se adopta `IdentidadTicket::rat1(...)` para no confundirla con la identidad v1
sin red. `Firmante::identidad(&cabecera)` sigue siendo la única vía de producción de la identidad.

## DF-9 · Borde exacto de la abstención (contradicción V4 ↔ decisión 5)

La orden §3.5 (decisión del director: «no las cambies») dice que `Registro::abrir` «crea en
abstención hasta `slot_actual + s_max_slots`», y FIR-10 fija `abstención_hasta = slot_perdida +
S_max_slots`. El código antiguo implementa eso de forma **inclusiva** (`slot <= hasta`): con
`slot_actual = s` y `S_max = m`, se abstiene en `s, s+1, …, s+m` y firma en `s+m+1`.

V4 de la orden, en cambio, pide «niega `s … s+m−1`, firma en `s+m`».

**Lectura adoptada:** la decisión 5 y FIR-10 (y el código antiguo, fuente normativa del portado)
mandan sobre la redacción de V4, que queda desplazada en uno. Se implementa `hasta = s + m` con
`slot <= hasta` y se prueban **los dos bordes** (`s+m` se abstiene; `s+m+1` firma). No se toca la
semántica del registro v3 portado. Si la dirección quería el borde de V4, el cambio es una línea
(`abstener_hasta = s + m - 1`), pero contradiría FIR-10 y el código antiguo.

