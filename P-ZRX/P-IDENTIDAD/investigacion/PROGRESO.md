# PROGRESO — P-IDENTIDAD

Bitácora. Toda cifra de este directorio se etiqueta `demostrado`, `verificado en fuente`,
`enumerado`, `derivado`, `estimado`, `propuesto` o `no determinado`.

## 0 · Advertencias de método ANTES de empezar (encargo §8)

Tres cosas del encargo no se sostienen tal como están escritas. Se declaran antes de empezar y se
contestan en el `INFORME.md`:

1. **`chunk` no está «dentro de la pieza».** El encargo §1 presenta A como «más fina» que B porque
   habría «varios `chunk` por `piece_offset`». Eso es cierto **dentro de una pieza fija**: un mismo
   `piece_offset` admite varias soluciones ganadoras con `chunk` distinto. Pero **globalmente A y B no
   están en relación de refinamiento: se cruzan**. A agrupa por `chunk` e ignora `piece_offset`; B
   agrupa por `piece_offset` e ignora `chunk`. Dos soluciones con el mismo `chunk` y distinto
   `piece_offset` son **la misma** para A y **distintas** para B. `IDENTIDAD.md` §3 lo declara
   medido en el prototipo PoAS. Por tanto la afirmación «A es más fina que B» solo vale en la fibra
   de `piece_offset` fijo, y hay que escribirla así. Se demuestra en `INFORME.md` F1.
2. **La tabla de `P-PRESTAMO` §3.3 leída literalmente es falsa.** «`β_d` no aporta peso neto» **no**
   es una propiedad de la identidad: entre ramas disjuntas cada copia es azul en la suya y su
   `blue_work` la cuenta (`veritas/seguridad/coste-rama-privada-v1/INFORME.md` §6, medido contra
   GDR-v0.2, que es el mismo instrumento que usa este encargo). Lo que B/C cierran es (i) que el par
   sea **evidencia objetiva** —con A los dos billetes son distintos y el par no prueba nada— y (ii)
   que al **fusionar** una copia sea inerte. Lo que **no** cierran es que la copia sume mientras las
   ramas están separadas. La conclusión de `P-PRESTAMO` necesita esa condición escrita, que es
   exactamente lo que el encargo F4 pide comprobar.
3. **El cambio SÍ toca `C-FLU-12`, por un invariante, no por su texto.** `C-FLU-12` usa `sol.chunk`
   directamente, así que el cambio de identidad no lo reescribe. Pero su *«Invariante de
   no-equivocación del inyector»* dice que **dos copias del mismo billete MUST producir la misma
   entropía**. Bajo A eso es gratis (`chunk` es parte de la identidad). Bajo B/C la identidad **no**
   contiene `chunk`, así que dos copias de la misma oportunidad en ramas distintas pueden llevar
   `chunk` distinto y producir **entropías distintas**. El invariante deja de ser un teorema y pasa a
   ser una condición que hay que imponer o reescribir.

Nada de esto invalida el encargo: lo precisa. Las tres se cuantifican o se demuestran abajo.

---

## 1 · Comprobaciones de ENTRADA (encargo §5)

Ejecutadas desde `/home/katana/zeo/ZEROX` antes de escribir nada en `investigacion/`:

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-IDENTIDAD/ENTRADA.sha256
P-ZRX/P-IDENTIDAD/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 22:01:03 CEST
```

`uptime` antes del primer benchmark: `22:01:03  up 13 days 18:30,  0 users,  carga promedio: 1,20, 1,36, 1,32`.

El árbol ya estaba sucio antes de empezar (`P-ZRX/` sin seguimiento). **No se toca nada fuera de
`P-ZRX/P-IDENTIDAD/investigacion/`.** `PROMPT.md` y `ENTRADA.sha256` no se modifican.

## 2 · Presupuesto declarado (LINEO §5.7 / §8.11)

- **Hilos:** 4 como máximo (el encargo lo fija; muy por debajo del tope de 24 de la máquina).
- **RAM:** ≤ 8 GiB (tope de la máquina 64 GiB). **Disco temporal:** ≤ 1 GiB.
- **Tiempo:** corridas de minutos; ninguna corrida individual > 30 min. Si se agota: checkpoint y
  estado **inconcluso**.

## 3 · Bitácora

| # | fecha/hora | qué | resultado |
|---|---|---|---|
| 1 | 2026-09-21 22:01 | comprobaciones de entrada (§1) | `OK`, árbol sucio preexistente |
| 2 | 2026-09-21 22:2x | lectura íntegra: `veritas/LINEO.md`, `SPEC.md` §6.1, §7.1.1–§7.1.4, §7.2, §11; `IDENTIDAD.md`, `CONTRATO-VALIDACION.md`; `P-PRESTAMO` §0/§3.3/D1; `P-EQUIVOCACION` P7–P10; CRP §6; `T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md`; `research/README.md` | hecho |
| 3 | 2026-09-21 22:2x | API de GDR-v0.2 (`Params`, `u2`, `u3_mode`, `EstadoReferencia`/`EstadoRapido`, `anadir!`, `orden_aplicacion`) | hecho: el instrumento ya lleva `idents` por bloque, U2 y U3″; el enumerador se apoya en él sin reimplementar GHOSTDAG |
| 4 | 2026-09-21 22:2x | hechos de fuente Autonomys, **releídos por el agente principal** en `sectors.rs:33-39,56-67,117-126`, `sector.rs:521-552,582-608`, `plotting.rs:651-667`, `verification/src/lib.rs:236-262`, `pallet-subspace/src/lib.rs:1588-1600`, `slot_worker.rs:571-592` | los siete hechos E1–E7 de `INFORME.md` §2 |
| 5 | 2026-09-21 22:2x | enumerador `identidad-billete-v1`: proyecto Julia, 5 fuentes, 9 fixtures, 259 tests, 4 subcomandos | **259/259 en verde** con `--check-bounds=yes` |
| 6 | 2026-09-21 22:28 | defecto propio **D1** detectado (autociclo en la lista enlazada de copias de `src/rapido.jl`) y corregido; queda comentado y como vector de regresión | corregido |
| 7 | 2026-09-21 22:30 | corrida publicada (`--seed 0x5a5a --replicas 400 todo`), benchmarks y escalado 1/2/4 hilos | 8,8 s de pared, 421 MiB de RSS; `resultados/{RUN,BENCH,ESCALADO}.txt` |
| 8 | 2026-09-21 22:32 | comprobaciones de salida (§5) | ver abajo |
| 9 | 2026-09-21 22:33 | `HUELLAS.sha256` de los 21 artefactos | generado |

## 4 · Entregables

- `INFORME.md` — primera línea, la respuesta; después el inventario del §2 y F1–F6.
- `INVENTARIO.md` — 28 filas de reglas de SPEC + 28 de código Rust + 9 de instrumentos, con la propiedad
  que cada una necesita y qué habría que reescribir.
- `DECISIONES-PENDIENTES.md` — 8 bifurcaciones para Katana, empezando por A / B / C.
- `PROGRESO.md` — este fichero.
- `veritas/consenso/identidad-billete-v1/` — enumerador Julia (`Project.toml`, `Manifest.toml`, `src/`,
  `test/`, `bench/`, `run.jl`, `resultados/`, `INFORME.md`) con
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 5 · Comprobaciones de SALIDA (encargo §5)

Ejecutadas desde `/home/katana/zeo/ZEROX` al terminar:

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-IDENTIDAD/ENTRADA.sha256
P-ZRX/P-IDENTIDAD/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 22:32:50 CEST
```

El árbol sigue **exactamente** como estaba al empezar: las cinco líneas de `git status` son las mismas.
**No se tocó nada fuera de `P-ZRX/P-IDENTIDAD/investigacion/`**: ni `SPEC.md`, ni `TAREAS.md`, ni `ci/`,
ni `crates/`, ni `prototipos/`, ni `research/`, ni `veritas/` (el instrumento `ghostdag-rank-v1` se usó
como dependencia por ruta, sin modificarlo), ni el resto de `P-ZRX/`, ni el vault externo.
`PROMPT.md` y `ENTRADA.sha256` están intactos (`OK`).

`uptime` al cerrar: `22:32:50  up 13 days 19:02,  0 users,  carga promedio: 3,17, 3,03, 2,81`.

## 6 · Resultado en una línea

La identidad se puede cambiar; **dentro de una historia las tres particiones coinciden**, así que no se
pierde ningún bloque honesto ni cambia ningún pago, y el beneficio de B/C frente a A se limita a las
ramas con **retos divergentes** y a la fracción en que el atacante **no puede elegir otra pieza**
(≈0,6 % con `pieces_in_sector = 1000`). A cambio B/C **rompen el invariante de `C-FLU-12`** y crean un
vector de **invalidación en cascada** que `C-GD-10` no descarta. C exige un registro de parcelas que no
existe; B no.
