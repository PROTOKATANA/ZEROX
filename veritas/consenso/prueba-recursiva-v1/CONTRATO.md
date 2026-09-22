# PRV-v0.1 — ¿Da una prueba recursiva el IBD sin confianza que los niveles no dan?

Fecha: 2026-09-17. Ejecutor: DeepSeek, zona aislada `deepseek/`. Encargo:
`deepseek/ENCARGO-06-prueba-recursiva.md`. Categoría dominante: **consenso**; secundaria
**criptografía**. Vive en `veritas/consenso/prueba-recursiva-v1/`. Destino final, si se
valida: `veritas/consenso/prueba-recursiva-v1/`. Estado: **instrumento de estudio**; no decide
reglas de consenso.

## Presupuesto (declarado ANTES de ejecutar, LINEO §7)

Máquina: `znver5`, 32 hilos lógicos, 123,4 GB RAM. Tope de LINEO: **64 GiB y 24 hilos**.

- Conteo y construcción (GDR-v0.2, serial): 1 hilo, < 2 GiB, cada corrida < 5 s.
- Escalado por hilos: hasta 24 hilos, < 2 GiB, < 1 min. No había `deepseek/MIDIENDO` vivo.
- Disco: `resultados/`, < 1 MiB. Sin temporales fuera.
- Si se agota: checkpoint y **inconcluso**. No ha ocurrido.

Se declaran **sólo** las dependencias usadas (lección de `PROCEDENCIA.md` §2 del encargo 05):
`BenchmarkTools`, `StableRNGs` y las stdlib `Dates`, `InteractiveUtils`, `Pkg`, `Printf`,
`Profile`, `Random`, `Test`. **Nueve** entradas, ninguna superflua.

## Qué calcula

1. **Selección (§2, prioridad máxima).** Construye, con el oráculo **GDR-v0.2** (reutilizado, no
   reimplementado), dos historias válidas `H1 ⊂ H2` con la MISMA estructura de prueba de validez
   aceptada y **distinta punta canónica**; la segunda tiene más `blue_work`. Demuestra que una
   prueba de validez no decide la canónica.
2. **Coste (§3.2).** Cuenta, por bloque de cadena, las operaciones que un circuito de GHOSTDAG
   tendría que probar —tamaño del mergeset, contexto azul, decisiones de ancestría, hashes de
   identidad, sumas `u256`, comparaciones de orden— sobre DAGs construidos por el oráculo, y las
   traduce a restricciones con un factor **citado** (Poseidon P128Pow5T3: 80 S-boxes por
   permutación). Entrega la tasa de cierre como **función de la ventana de fusión `W`**, no con un
   valor fijo.
3. **Comparación con una cadena lineal** equivalente (`--lineal`) y **ventana crítica** `W*` a la
   que dejaría de cerrar a 1 bloque/s (§6).

## Qué NO calcula (fuera de alcance, declarado)

- **No implementa el circuito** ni un probador. Es un conteo y un modelo de coste, como pide el
  §3.2 del encargo.
- **No incluye en la cota inferior** el coste en circuito de: sello Ed25519, las 2 verificaciones
  KZG por cabecera (§7, §26), la cadena PoT (AES por slot) ni las transiciones UTXO. Sólo pueden
  **aumentar** el coste; se declaran.
- **No mide la tasa real de un probador Halo2** en esta máquina. La tasa de conversión se declara
  con rango (Halo2 realista 1e6, optimista 1e9, 24 hilos 2,4e10 restricciones/s) y el informe da
  la tasa de cierre para las tres.
- **No audita PoT, inyección, flujos ni finalidad**: los usa como supuestos donde toca y los marca.
- **No fija `W`, `M`, la profundidad de fusión ni ninguna constante de producción.**

## Criterios de aceptación

1. El conteo rápido coincide con la recomputación independiente desde la definición (mergeset por
   conjuntos, anticono por ancestría) en DAGs pequeños: **0 fallos**.
2. Las dos historias de selección son **válidas** y sus pruebas aceptadas, con puntas canónicas
   distintas.
3. La suite pasa con `--check-bounds=yes`.
4. GDR-v0.2 se **reutiliza**; no se reimplementa GHOSTDAG.
5. Cada cifra lleva semilla, comando y versión en `resultados/`; cada factor de conversión lleva
   fuente CITADA o marca DECLARADO.

## Límite declarado

El veredicto de selección es sobre **pruebas que sólo acreditan validez de una historia**. Bajo un
**checkpoint firmado** (§12.1, C-CHK) o bajo el supuesto de que un nodo observa TODAS las puntas
(disponibilidad de datos), la situación cambia, y el informe lo dice. El «no» es a «IBD sin
confianza a partir de la prueba sola», no a «la prueba es inútil».
