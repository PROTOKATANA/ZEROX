# PROGRESO — P-POT · Propuesta de SPEC para PoT como primitiva y contrato del verificador

## Inicio

```
$ date
sáb 19 sep 2026 07:10:04 CEST

$ LC_ALL=C sha256sum -c P-POT/ENTRADA.sha256
P-POT/ENCARGO.md: OK
P-POT/PROMPT.md: OK

$ git status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-POT/
?? P-PUERTA/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

Estado preexistente al inicio (ningún archivo tocado por este agente aún).

## Trabajo realizado

1. Lecturas obligatorias del encargo §1 completadas en orden (AGENTS.md, SPEC.md §0/§6.1-6.2/
   §7.1/§7.3/C-NET-31/32, R-FIN-14/R-FIN-9, wire_dag.rs, pot-estable, plantilla
   ghostdag-rank-v1, TAREAS.md §2.1/§4.2).
2. Datos del encargo §2 comprobados en fuente antes de citar: pot.rs:276-295 (aleatoriedad,
   seed, inyección), lib.rs:104-112 (reto), subspace-verification/src/lib.rs:442-446
   (entropía), sp-consensus-subspace/src/lib.rs:89-149 (PotNextSlotInput, NonZeroU32,
   encadenado), digests.rs:56-86 (dos salidas en el pre-digest), slot_worker.rs:390-479
   (rango de checkpoints, future), verifier.rs:259-262 (ancla), pot.rs:176-195 (génesis,
   clave AES). Copia local de Autonomys confirmada en `f8842d0` (`git rev-parse`).
   Costes de verificación citados de `veritas/rendimiento/coste-salto-v1/` sin recalcular.
3. Redactados:
   - `PROPUESTA-SPEC.md`: reglas propuestas C-POT-01…C-POT-08 (primitiva, contrato del
     verificador con tres estados, caché con clave contextual + demostración de inocuidad
     con un único flujo, orden de validación), cada una con etiqueta (verificado en
     fuente / propuesto / no determinado por el SPEC) y cita con ruta desde la raíz.
     Cierra con «Lo que esta propuesta NO resuelve».
   - `DECISIONES-PENDIENTES.md`: D-1 (blake3 vs H_d, recomendación A) y D-2 (identidad del
     `pot_output` único, recomendación A) con lo que gana/paga/cierra cada opción, más
     D-3/D-4/D-5 como bifurcaciones menores.
   - `vectores/`: crate mínimo dependiente de `pot-estable` por ruta; vectores V1-V5
     generados con N=16 y fijados en `tests/vectores.rs` (4/4 tests pasan). Compilado
     offline con `-j 2` y `CARGO_TARGET_DIR=/tmp/opencode/ppot-target` (nada pesado;
     zona de P-2.1 intacta).
4. Nada fuera de `P-POT/propuesta/` fue editado. Sin Python, sin cómputo pesado.

## Decisiones de Katana — 2026-09-19

- **D-1 = A:** conservar `blake3` byte a byte como Autonomys. Motivo de Katana: el oráculo
  diferencial es lo único independiente que acredita el port, y el SPEC ya tiene precedente
  de excepción documentada en C-NET-07.
- **D-2 = A:** `pot_output = salida(f, slot(B) + D)`, la salida futura. Motivo de Katana:
  conserva el ancla interna de Autonomys y, con la caché por slot, su coste casi desaparece;
  C decide un parámetro (`D`) que todavía no toca decidir.

Incorporadas a `PROPUESTA-SPEC.md` (condicionalidades retiradas en C-POT-02, C-POT-05 y §5) y
registradas en `DECISIONES-PENDIENTES.md`. Las reglas C-POT siguen siendo propuesta hasta que
Katana las traslade al SPEC.

## Cierre

```
$ date
sáb 19 sep 2026 07:17:50 CEST

$ LC_ALL=C sha256sum -c P-POT/ENTRADA.sha256
P-POT/ENCARGO.md: OK
P-POT/PROMPT.md: OK

$ git status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-POT/
?? P-PUERTA/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

Idéntico al inicio (los modificados son preexistentes; `P-POT/` nuevo completo, como
esperado).

## Verificación tras incorporar las decisiones (2026-09-19 07:34)

```
$ LC_ALL=C sha256sum -c P-POT/ENTRADA.sha256
P-POT/ENCARGO.md: OK
P-POT/PROMPT.md: OK

$ git status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-POT/
?? P-PUERTA/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

Sin cambios fuera de `P-POT/`.

## Comprobaciones de los vectores

```
$ CARGO_TARGET_DIR=/tmp/opencode/ppot-target cargo test --release --offline -j 2
running 4 tests
test v1_encadenado_sin_inyeccion ... ok
test v2_inyeccion ... ok
test v3_v4_aleatoriedad_reto ... ok
test v5_dominio_de_n ... ok
test result: ok. 4 passed; 0 failed
```
