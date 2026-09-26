# REVISIÓN A10-M1 — hashrate medido del PoW dev en CPU y GPU

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet, dos rondas
(la segunda por `CORRECCION-A10-M1-A`). Evidencia: `resultados-A10-M1/` (informe, fuentes del banco
y del núcleo, registros, muestreo de `nvidia-smi`, huellas; los volcados de 32 MB de la validación (b)
quedan en `deepseek/A10M1/gpu/` con su `sha256` copiado).

**Veredicto: ACEPTADA. Pregunta falsable REFUTADA** («GPU ≥ 10× los 32 hilos»): 8,2×.

## Comprobado por el director

- Validación (b): `cpu_dump.bin` y `gpu_dump.bin` (10⁶ digests, 32 000 000 B) **idénticos**
  (`cmp`; ambos `8ee6f015…95b3`). (a) 136/136 vectores CAVP y (c) mismo primer nonce válido (1 737 536),
  según el informe.
- `gpu_bench.log`: 5 repeticiones de ≈ 30 s; `hashes/segundos` recalculado = 561,1 MH/s en las tres
  últimas. Caída de 627 → 561 MH/s con el reloj SM 1 860 → 1 506 MHz (estrangulamiento térmico a
  ~85 °C, utilización 99–100 %): la cifra sostenida es la de régimen.
- Potencia bajo carga (151 muestras de `nvidia-smi`): **109,0 W** ⇒ **1,94·10⁻⁷ J por hash**
  (derivación del director sobre el muestreo; solo la tarjeta, no el equipo).
- El núcleo se compila con NVRTC 12.9 para `compute_61` y no incluye cabeceras del sistema; el
  anfitrión es C11. No se instaló nada.

## Cifras (medición real reproducida; máquina con carga ajena en la parte CPU)

| Plataforma | H/s del `hash_pow` dev | Nota |
|---|---:|---|
| CPU AMD 9950X3D, 1 hilo | 4 845 383 | provisional (carga ajena) |
| CPU, 32 hilos (16 núcleos + SMT) | 68 505 024 | provisional; escala 14,1× sobre 1 hilo |
| GPU GTX 1070 (Pascal, 2016), régimen | 561 084 507 | 8,19× CPU-32; 115,8× CPU-1 |

**Derivación** (tiempo para `W` hashes esperados a ritmo constante):

| `W` | CPU-32 | GTX 1070 | Energía GPU |
|---|---:|---:|---:|
| 2³⁶ | 16,7 min | 2,0 min | 1,3·10⁴ J |
| 2⁴⁰ | 4,46 h | 32,7 min | 2,1·10⁵ J (0,06 kWh) |
| 2⁴⁴ | 71,3 h | 8,71 h | 3,4·10⁶ J (0,95 kWh) |
| 2⁴⁸ | 47,6 días | 5,8 días | 5,5·10⁷ J (15,2 kWh) |

## Lo que no queda demostrado

- Una GTX 1070 es **cota inferior** de una GPU actual; no se midió ninguna otra ni ASIC/FPGA de
  Keccak. **Hipótesis** (no medida): una GPU de consumo actual rinde varias veces más.
- La cifra de CPU tiene carga ajena: el director la repetirá en reposo con `correr_cpu_bench.sh`.
- No hay precios: el coste en dinero de `W_min` sigue abierto (IPA A-10).

## Consecuencia para A-12 (derivación)

Con SHA3-256, quien tenga GPU produce el trabajo del prefijo ~8× más rápido que un sobremesa de 16
núcleos y ~116× más que un núcleo; el trabajo de un prefijo dev (`W_min` de 30 bloques a
`0x1e7fffff`, ≈ 2²² hashes) cuesta **segundos** con cualquier plataforma: el PoW dev no protege nada,
como ya declara `PERFIL-DEV-v0.md`. Para producción, el dato cierra la parte «hashrate CPU/GPU» de
A-10; faltan hash alquilable, precios y hash honesto plausible al arranque.
