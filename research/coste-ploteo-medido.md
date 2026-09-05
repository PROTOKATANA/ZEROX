# Coste de ploteo y de auditoría en PoAS — MEDIDO, no citado

**Fecha:** 2026-09-05 · **Motivo:** `PREGUNTAS-PARA-KATANA.md` P-032 y `DECISIONES.md` §15.

Toda la discusión del ritmo de relleno y del ataque de generación bajo demanda descansaba en una
cifra de prosa: *"Modern CPUs can complete the plotting of a sector in less than two minutes, while
a single high performance GPU can accomplish the same task in under five seconds"* (Autonomys
Academy, página *Plotting*). **Es exactamente el tipo de número que este proyecto ya se ha comido
tres veces** (H-005, tamaño de cabecera, `MAX_RESPUESTA_BYTES`), así que se midió.

## Qué se midió

`cargo bench -p subspace-farmer-components --bench plotting -- --sample-size 10`
sobre `subspace @ f8842d0`, toolchain `nightly-2026-05-03`, en la máquina de desarrollo (32 hilos).
El banco usa `CpuRecordsEncoder` y `ChiaV2Table`, con `MAX_PIECES_IN_SECTOR = 1000` (sector ≈ 1 GiB).

## Resultado

```
plotting/in-memory      time:   [82.236 s  83.608 s  85.476 s]
                        thrpt:  [11.792 MiB/s  12.055 MiB/s  12.257 MiB/s]
```

**83,6 s por sector de 1 GiB en CPU, 12,06 MiB/s.** La prosa de Academy («<2 min en CPU») **se
sostiene**. La cifra de GPU («<5 s») **no se ha medido** — no se usa como si estuviera verificada.

## Para qué sirve: el coste de fabricar espacio al vuelo

`SLOT_DURATION = 1000` ms (`subspace-runtime/src/lib.rs:145`). Un atacante que guarde la historia y
regenere sectores en el momento de auditar produce, como mucho, su rendimiento de ploteo por slot:

| | Espacio fabricable por slot de 1 s |
|---|---:|
| CPU 32 hilos — **medido** | **12,1 MiB** |
| GPU a 5 s/sector — *doc, sin medir* | 204,8 MiB |

Y por tanto, para fabricar una red entera al vuelo frente a comprarla en disco:

| Red | CPUs | GPUs | Disco honesto equivalente |
|---|---:|---:|---:|
| 10 TiB | 869 827 | 51 200 | ~$250 |
| 100 TiB | 8 698 266 | 512 000 | ~$2 500 |
| 1 PiB | 89 070 247 | 5 242 880 | ~$25 600 |

## Lo que esto NO demuestra

⚠️ La tabla supone que el atacante regenera **todo** el espacio que reclama, en **cada** slot. El
ataque real es más listo: no necesita responder a todos los desafíos, solo **encontrar un ganador**.
Con un `solution_range` ancho —que es justo lo que tiene una red pequeña— podría bastar con
regenerar unos pocos sectores candidatos. **La tabla acota el ataque ingenuo, no el ataque real.**

Contrastar con `chia-parcelas-comprimidas.md`: el número de Chia (una RTX 5090 ≈ 20 TB imitados) mide
otra cosa —*plot ID grinding*, no regeneración completa— y **no se transfiere** a este cuadro.

Pendiente: el banco `auditing` mide el coste por desafío, que es la magnitud que decide el ataque
real. Y la derivación formal está en manos de D9.

---

## El coste por auditoría — la magnitud que sí decide

`cargo bench -p subspace-farmer-components --bench auditing -- --sample-size 10`, misma máquina y
commit. `sectors_count` por defecto = 10 (`benches/auditing.rs:48`).

```
auditing/disk/sync      time:   [92.825 µs  93.221 µs  93.558 µs]   (10 sectores)
                        thrpt:  [106.89 Kelem/s  107.27 Kelem/s  107.73 Kelem/s]
```

**9,32 µs por sector auditado desde disco.**

⚠️ El resultado `auditing/memory/sync = 404 ps` **es un banco roto de ellos, no una medición.** Usa
`b.iter(|| async { … })`: el bloque `async` construye un futuro que **nadie awaitea ni sondea**, así
que Criterion cronometra la construcción del futuro y nada más. No se usa esa cifra.

## El número que cierra el ataque de generación bajo demanda

| Acción, por sector | Coste |
|---|---:|
| Auditarlo honestamente desde disco | **9,32 µs** |
| Regenerarlo para auditarlo | **83,6 s** |
| **Razón** | **≈ 9,0 millones ×** |

Un granjero honesto audita ~107 000 sectores por segundo, es decir **~105 TiB de espacio prometido
por slot** con una sola máquina. El atacante que no guarda paga nueve millones de veces más **por
cada sector que quiera comprobar**, y tiene que comprobar para saber si gana.

Esto vale también para el ataque «listo» que la sección anterior dejaba abierto: el atacante no
necesita auditar todo, pero **auditar es precisamente cómo se descubre si un sector gana**. No hay
atajo que evite regenerar el sector que se quiere comprobar. La razón de 9 millones no depende de
cuántos sectores compruebe.

## Consecuencia para la compresibilidad del relleno (P-032)

La objeción abierta era: si el relleno es ChaCha8 sembrado de 32 bytes, ¿puede un atacante guardar
semillas en vez de piezas y regenerar al auditar?

**Puede regenerar las piezas gratis. Lo que no puede es saltarse la codificación.** Lo que el
auditor lee no es la pieza: es el **registro codificado** con la tabla de pruebas de espacio, y
producir eso es justo los 83,6 s medidos. La entropía del dato subyacente no es la barrera; **la
barrera es la tabla**. Que el relleno sea pseudoaleatorio derivable no lo hace comprimible en el
sentido que importa.

Lectura del hilo principal a partir de la medición; la derivación formal es de D9.
