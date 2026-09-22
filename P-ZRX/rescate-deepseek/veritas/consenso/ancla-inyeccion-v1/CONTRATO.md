# ANCLA-v0.1 — contrato del instrumento P-2.1

**ID propuesto:** `ANCLA-v0.1` («ventana de anclaje para la inyección del PoT»).
**Fecha:** 2026-09-18. **Zona:** `deepseek/P-2.1/veritas/consenso/ancla-inyeccion-v1/` (solo lectura
fuera de ella). **Categoría dominante:** `consenso`; secundaria: `seguridad`.
**Estado:** instrumento de estudio. **No decide reglas de consenso, no activa nada, no fija
`ρ_max`, `F`, `I`, `L` ni `D`.** Todo resultado es MS sobre el modelo ANCLA-v0.1 salvo lo
marcado como estimado o derivado.

## Presupuesto declarado antes de las corridas largas (LINEO §7)

Máquina de referencia: AMD Ryzen 9 9950X3D, 32 hilos lógicos, 123 GiB RAM. Tope LINEO:
**64 GiB de RAM y 24 hilos de cómputo**.

- Simulación de red + GHOSTDAG por réplica: **1 hilo**, memoria residente estimada < 1 GiB.
- Corridas principales: hasta **24 hilos**, RAM residente observada por debajo de ~8 GiB.
- Disco temporal: `resultados/` < 100 MiB; sin temporales fuera del proyecto.
- Tiempo declarado: corridas de hasta ~30 min de pared cada una. Si se agotara, checkpoint y
  estado **inconcluso** en `PROGRESO.md`; nunca se cambia un timeout por un resultado negativo.

Ninguna corrida publicada superó estos topes. La mayor (`curva-grande`, 10 000 réplicas) usó
1 514 s de pared con 24 hilos y produjo ~2,4 GB de asignaciones acumuladas, sin agotar RAM.

## Qué calcula

Sobre una red honesta sintética (parámetros DMS-v0.1: G(n,p), latencia lognormal mediana 80 ms /
p99 500 ms, inundación con cola serial, Poisson λ, creador uniforme) en la que cada bloque
referencia hasta 15 puntas de su creador, este instrumento:

1. Construye el DAG global con instante de llegada a cada nodo (`simular_red`).
2. Aplica **GDR-v0.2 sin modificarlo** (`anadir!`, `virtual_sp`, `cadena_seleccionada`, incluidas
   las fuentes de `veritas/consenso/ghostdag-rank-v1/src/`) para obtener la cadena seleccionada de
   cada observador honesto en cada corte temporal.
3. Mide **P(discrepancia)(D)**: probabilidad de que dos observadores honestos con puntas distintas
   asignen bloques distintos a la **posición absoluta N = H_ref(corte) − D** de la cadena
   seleccionada, con una Δ del modelo DMS-v0.1. Es una probabilidad de coincidencia entre
   observadores, **no una garantía de irreversibilidad**.
4. Entrega el mapa `(ρ, F) → ¿existe D admisible?` bajo las restricciones de R-FIN-14(f) y con la
   interpretación de la cota superior declarada explícitamente en `INFORME.md` §3.3.

## Qué NO calcula (límites del contrato)

- **No mide finalidad.** Mide estabilidad del ancla entre observadores honestos. No hay
  irreversibilidad, ni `exit`, ni tolerancia a particiones/eclipse: el modelo no tiene adversario,
  ni partición, ni eclipse, ni churn, ni pérdida de paquetes.
- **No es MR:** no existe red ZEROX (TAREAS §1.4). Toda cifra es MS sobre el modelo.
- **No hay atacante de VDF en la simulación.** El efecto de `ρ` entra solo por las restricciones de
  R-FIN-14, no se simula un timekeeper rápido.
- **No hay reimplementación de consenso.** GHOSTDAG, `sp`, color, `rank` y cadena salen de GDR-v0.2;
  la única regla que este instrumento añade (selección de hasta 15 puntas del creador) es política
  de producción del modelo, declarada en `MODELO.md`.
- **No fija constantes.** `ρ_max`, `F`, `I`, `L` y `D` van como funciones o regiones.
- **No cubre** el retarget, la emisión, UTXO, red real, ni el verificador PoT.

## Criterio de terminación

LINEO §10, y además:

- la curva `P(discrepancia)(D)` con Δ del modelo, CI por bootstrap de clúster y umbrales
  10⁻³/10⁻⁶/10⁻⁹ declarados con su estado (medido/estimado);
- el mapa `(ρ,F)` con su frontera y sus supuestos a la vista;
- `git status` idéntico al inicio, `Project.toml` recortado, `HUELLAS.sha256` verificado;
- lo no medido queda **inconcluso**, no redondeado a favor de la hipótesis.
