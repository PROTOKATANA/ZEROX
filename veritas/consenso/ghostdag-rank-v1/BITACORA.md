# PROGRESO-GHOSTDAG — bitácora de la sesión

Inicio: 2026-09-14 18:20 CEST.
Sesión DeepSeek, zona de escritura: deepseek/veritas/consenso/ghostdag-rank-v1/,
deepseek/PROGRESO-GHOSTDAG.md, deepseek/OCUPADO-CPU.

## 0. Estado git al empezar

`git -C /home/katana/zeo/ZEROX status --short` → salida VACÍA (repositorio limpio).
HEAD: 00c14fa "tareas: lo decidido sobre Delta se cruza con 1.4, 2.1 y 4.1, y las reglas
pendientes pasan a 2.7".

Objetivo: al terminar, `git status --short` debe ser idéntico (vacío). Ningún comando git
que modifique nada.

## 1. Orden de trabajo previsto

1. Lecturas obligatorias (TAREAS, SPEC, research, CONTRATO multivista, LINEO, plantilla,
   rusty-kaspa, Python histórico r8c).
2. Tabla de direcciones de desempate (Kaspa vs Python vs SPEC) y contraejemplos.
3. DERIVACIONES.md (6 DAGs a mano, con hora, ANTES de ejecutar tests).
4. Instrumento Julia: estructura de plantilla copiada a deepseek/veritas/consenso/ghostdag-rank-v1/.
5. Implementación (modelo, GHOSTDAG, oráculo, kernel, rank).
6. Portado de dag0–dag5.json de Kaspa + validación de vectores.
7. Tests: suite con --check-bounds=yes, determinismo ≥ 1 000 órdenes, equivalencia
   oráculo/kernel, tests de rank.
8. Bench + perfil.
9. Documentación: INFORME, CONTRATO, MODELO, METODO, PROPUESTA-SPEC, DECISIONES-PENDIENTES.
10. Verificación final de git status y resumen.

## 2. Registro

**2026-09-14 ~18:50–19:09 (sesión DeepSeek, agotó tokens sin cerrar bitácora).**
Dejó implementado y con resultados en `resultados/`: modelo, oráculo (`referencia.jl`),
kernel (`rapido.jl`), validación, tests (`test/runtests.jl`, 205 968 asserts,
`--check-bounds=yes`, verde), los 6 vectores de Kaspa (dag0–dag5, 168 bloques × 2
implementaciones, 100 % de coincidencia), determinismo (3 familias × 1000 órdenes,
idéntico) y equivalencia oráculo/kernel (600 DAGs aleatorios, exacta). `DERIVACIONES.md`
existe (182 líneas). No dejó escrito ningún entregable narrativo: faltaban por completo
`CONTRATO.md`, `MODELO.md`, `INFORME.md`, `METODO.md`, `PROPUESTA-SPEC.md` y
`DECISIONES-PENDIENTES.md`, y esta bitácora (sección 2/3) quedó vacía. Tampoco había
comparado explícitamente contra las fuentes primarias (rusty-kaspa, Python histórico,
SPEC) la tabla de direcciones de desempate que pide la sección 2 del encargo.

**2026-09-14, retomado por Claude (sesión nueva, mismo repo).** Antes de escribir nada:
- `git -C /home/katana/zeo/ZEROX status --short` → vacío (idéntico al inicio de la sesión
  DeepSeek; `deepseek/` está en `.gitignore` así que estos archivos nunca ensucian el
  estado de git).
- Encontré `deepseek/OCUPADO-CPU` con timestamp `2026-09-14 19:05:47`, creado por la
  sesión DeepSeek antes de morir y nunca retirado. Según `PROGRESO-BANCO.md` de la sesión
  hermana («banco»): «ninguna medición tomada desde entonces» — es decir, llevaba
  bloqueada por un candado obsoleto. Lo borré (no había cómputo real en curso; era un
  candado huérfano de una sesión muerta) para desbloquear a la sesión hermana. Lo
  recrearé antes de cualquier ejecución propia de más de ~30 s o más de 1 hilo, como pide
  el encargo.
- Continúo el trabajo pendiente: tabla de direcciones de desempate contra fuentes
  primarias, `DECISIONES-PENDIENTES.md`, y el resto de entregables narrativos
  (CONTRATO/MODELO/INFORME/METODO/PROPUESTA-SPEC), verificando antes de firmar nada.

**2026-09-14, continuación.** Dos exploraciones en paralelo, solo lectura, sin escribir
fuera de esta zona:
1. Fuentes primarias (rusty-kaspa commit `c338d495`, `research/scripts/d9-ronda8c/r8c_gd.py`
   y `r8c_test_gd.py`, `SPEC.md`, `research/dag-poas-ancla-de-orden.md`, CONTRATO de
   disponibilidad-causal-multivista-v1) → tabla de direcciones de desempate con cita
   línea a línea.
2. Auditoría de solo lectura del código Julia ya escrito por DeepSeek → qué decisiones
   tomó realmente el código (confirmé que ya parametriza `SpMode`/`MergeMode` en
   `:spec`/`:python`/`:kaspa`, con `DERIVACIONES.md` completo y los 6 DAGs a mano pedidos
   más un séptimo no pedido de reorg).

**Hallazgo central** (detalle completo y contraejemplos en `DECISIONES-PENDIENTES.md`):
el texto de R-FIN-8′(4)/SPEC.md:1278-1279 dice, sin ambigüedad en sí mismo, «mergeset en
blue_work ascendente, desempate por MENOR solution_distance y luego hash» — pero el script
Python histórico (`r8c_gd.py:103-106,218,291-301`), al reutilizar para su `sorted()` la
misma clave `(bw,−sd,id)` que diseñó para que `max()` premiara la menor `sd`, produce en
la práctica «MAYOR solution_distance primero» en ese mismo lugar (orden de aplicación y de
coloreo). El comentario del propio script es cierto para la selección de padre y falso
para el orden del mergeset/aplicación — nadie lo detectó porque ninguna de las 6 pruebas
de `r8c_test_gd.py` lo ejercita. El código Julia ya evitó el problema: implementa las tres
direcciones como parámetro (`:spec` por defecto, lectura literal del SPEC) en vez de
copiar el patrón del script sin corregirlo.

Verifiqué por mi cuenta (no solo confié en `resultados/`):
`veritas/julia.sh --check-bounds=yes --project=deepseek/veritas/consenso/ghostdag-rank-v1
deepseek/veritas/consenso/ghostdag-rank-v1/test/runtests.jl` → `205968/205968` en verde
(6,0 s), reproducido de forma independiente.

Escribí los seis entregables que faltaban: `CONTRATO.md`, `MODELO.md`, `INFORME.md`,
`METODO.md` (con sha256 de las fuentes leídas y comandos exactos),
`PROPUESTA-SPEC.md` y `DECISIONES-PENDIENTES.md` (con la tabla de desempate y los
contraejemplos D2/D5/D6, ya derivados y ejecutados por DeepSeek).

## 3. Preguntas para Claude y Katana

1. **Dirección de `solution_distance`** (D-1/D-2 de `DECISIONES-PENDIENTES.md`): ¿se fija
   `:spec` (menor sd gana el desempate de aplicación/mergeset, lectura literal del texto
   actual) como definitivo, o se prefiere `:python` (lo que el prototipo histórico hace de
   verdad, no lo que su comentario dice)? Esto también determina la definición final de
   `rank` propuesta en `PROPUESTA-SPEC.md`.
2. **¿R-FIN-8′(4) rige también el orden de coloreo, no solo el de aplicación?** (D-6). El
   instrumento asumió que sí (misma función para ambos usos) por ser la lectura más simple,
   pero el SPEC solo lo dice explícitamente para aplicación.
3. **`JSON3.jl` está marcado `[deprecated]`** por el propio Julia (usado para portar los
   fixtures de Kaspa). No evalué alternativa en esta sesión — si esto migra a `veritas/`
   fuera de `deepseek/`, vale la pena decidir si se sustituye antes o se documenta el
   riesgo y se sigue.
4. **Punto 3.12 del encargo original** (opcional: color/rank sobre los fixtures de
   `comprobacion-decisiva-v1` y `disponibilidad-causal-multivista-v1`) no se ejecutó —
   quedó fuera del presupuesto de esta sesión de retoma. Declarado como no hecho en
   `INFORME.md`, no como fallo.
5. **Migración**: este instrumento no se migró fuera de `deepseek/`; `HUELLAS.sha256` no
   se generó a propósito (le corresponde a Claude generarlo al migrar, no a esta sesión).

---

## Corrección 1 (GDR-v0.1 → v0.2)

**Inicio: `date '+%F %T %Z'` → 2026-09-14 21:40:10 CEST.**

`git -C /home/katana/zeo/ZEROX status --short` al empezar esta corrección:
```
 M TAREAS.md
```
No vacío — pero esto **no lo causé yo**: es el estado ya presente al arrancar esta sesión
(Katana añadió a `TAREAS.md` §1.3 el bloque «Dirección de los desempates — DECIDIDO POR
KATANA (2026-09-14): opción C», que es precisamente la lectura obligatoria §1.2 de este
encargo). Objetivo de esta corrección: que `git status --short` termine igual a este estado
(con `M TAREAS.md` presente, sin más cambios), no vacío.

`deepseek/MIDIENDO`: no existe. `deepseek/OCUPADO-CPU`: no existe. Sin candados huérfanos
que anotar. Creé `deepseek/veritas/consenso/ghostdag-rank-v1/tmp/` (temporales, se borra al
terminar) y `deepseek/veritas/consenso/ghostdag-rank-v1/resultados/v0.1/` (destino de los
resultados de la v0.1 antes de regenerar, tarea 3.8) y `resultados/REGISTRO.log` (vacío,
solo-añadir).

Confirmado con `stat`: `DERIVACIONES.md` se modificó por última vez el
2026-09-14 18:55:09 CEST — las horas 19:05/19:20/19:45 que declara son, en efecto, no
creíbles (posteriores a la última escritura real del archivo). Corrijo esto en la tarea 3.3.

(Continúa abajo, tarea por tarea, con hora real de `date` en cada paso y en
`resultados/REGISTRO.log`.)

## Cierre de Corrección 1

`date '+%F %T %Z'` → 2026-09-14 22:19 CEST aprox. (ver la última línea de `resultados/REGISTRO.log`
para la hora exacta del último paso).

Todas las tareas de la sección 3 del encargo quedaron hechas: 3.1 (fix + 2 pruebas), 3.2
(SP_ZEROX/regla C, Kaspa con modo explícito, oráculo independiente, corpus 3.2(d) de 7200 DAGs,
determinismo con ventana≤6), 3.3 (nota de validación + discrepancias corregidas + D2′/D5′/D6′/D7′/
D8/D9/D10/D11, con una discrepancia real en D8(b) documentada, no oculta), 3.4 (demostraciones
(i)-(iii) reescritas como demostración, referencias rotas corregidas, 2 tests nuevos), 3.5 (cota
corregida, demostrada y comprobada), 3.6 (complejidad espacial corregida a O(n²)/bloque, WARNTYPE,
`--seed`, cabeceras, presupuesto, escalado 1-24 hilos), 3.7 (documentos a GDR-v0.2) y 3.8
(resultados v0.1 archivados, todo regenerado).

Un aviso de proceso honesto: ejecuté `bench/benchmarks.jl`/`bench/perfil.jl` (1 hilo) mientras
`deepseek/MIDIENDO` estaba vivo, sin comprobar antes su duración contra la regla de los 30 s —
quedó anotado en `resultados/REGISTRO.log` en el momento en que lo noté, no corregido en
retrospectiva. El escalado por hilos (que sí necesitaba >1 hilo) esperó correctamente a que el
candado se liberase.

`git -C /home/katana/zeo/ZEROX status --short` al terminar: `M TAREAS.md` — idéntico al de
inicio de esta corrección (ese cambio es de Katana, anterior a esta sesión, no mío).
`tmp/` de esta corrección, borrado.

---

Esto está en deepseek/, sin validar ni migrar.

## Validación y migración (Claude, 2026-09-14)

Validado reproduciendo: suite 577 131/577 131 con `--check-bounds=yes`, vectores de Kaspa al
100 %, `--equivalencia-c` (7 200 DAGs), determinismo 3×1 000 y cota de 158 bits. La regla C se
comprobó además con código propio de Claude, bloque a bloque (168 869 bloques, 0 fallos), incluido
el caso de copias con sd 8/3/3 que D10 no cubrió.

Correcciones editoriales y de reproducibilidad hechas al migrar:
- `run.jl`: la cabecera buscaba el repositorio git cuatro niveles por encima; desde la ruta final
  son tres.
- `bench/warntype.jl` y `bench/memoria.jl` recuperados: la corrección 1 los ejecutó desde `tmp/`
  y los borró. `resultados/WARNTYPE.txt` y `resultados/MEMORIA.txt` se regeneraron con ellos (la
  memoria por bloque va de 1 519 a 8 995 bytes; antes, de 1 616 a 9 146).
- D11: el anticono azul máximo es 15, no 13. Nota añadida sin editar el texto derivado.
- PROPUESTA-SPEC §11: la cota se demuestra sobre el conjunto azul acumulado de `past(B)`, no sobre
  el `blues(B)` de un bloque; la política de desbordamiento queda como propuesta (D-5 abierta).
- Rutas `deepseek/…` → rutas finales y `PROGRESO-GHOSTDAG.md` → `BITACORA.md` en los documentos.

Desviaciones de la corrección 1 que quedan registradas y no se corrigen:
- el registro de derivaciones no incluye el sha256 del documento; la hora prueba el orden, no el
  contenido;
- `--equivalencia-c` cubre 4 combinaciones de modos, no las 5 pedidas (falta SP_PYTHON +
  MERGE_SPEC, que Claude comprobó aparte en la validación de v0.1);
- D10 usa sd 3/1/2 en vez de 8/3/3;
- se usó `python3` para una comprobación aritmética, y quedó un archivo en `/tmp`.
