# REVISIÓN W06d2 — red del nodo

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet, único, ≈ 2 h 8 min.
Evidencia: `resultados-W06d2/`. **Veredicto: SUPERADO PARCIALMENTE. Migrada** por parche (21 rutas, base
idéntica en las rutas tocadas, `git apply --check` limpio, 21 huellas verificadas; lock sin cambios de
versión). Suite: **715 pasan, 0 fallan, 2 ignorados** (698 antes; 0 perdidos, 17 añadidos).

## Lo que queda hecho

Validación **diferida** en `zx-p2p` (`Veredicto::Diferir`; lo que no se informa a tiempo caduca como
`Ignorar`, nunca `Rechazar`); difusión de los bloques propios **solo tras persistirlos**; depósito de
huérfanos acotado (FIFO) con petición de padres; sincronización PoW por localizador; penalización;
herramienta adversarial `zx-adversario` (binario aparte). Verificado **en vivo** con procesos reales en TCP:
dos nodos convergen en la fase PoW, y un PoW con nonce malo de `zx-adversario` se rechaza y cierra la
conexión. **Correcciones de la revisión independiente, recibidas a mitad de ejecución:** RI-2a
(`ErrSinPadre` ya no se guarda como definitivo; test nuevo; `diferencial_t04` en verde) y RI-2b (el bloque
PoST propio se persiste antes de admitirse en memoria).

## Dos huecos, uno de ellos error del director

1. **`BloqueRed::Post` no lleva la justificación PoT** (`JustificacionPot`), sin la cual
   `verificar_cabecera_conjunta` no puede verificar el PoT ni el PoAS de un bloque ajeno. El formato de
   red lo fijé yo en W06c sin ese campo: **error del director**. El ejecutor hizo lo correcto: todo PoST de
   red se `Ignora` (nunca se acepta sin verificar ni se penaliza).
2. **El nodo no sigue bifurcaciones PoW:** `admitir_pow_interno` (de W06d1) valida cada bloque contra
   `historial_pow.last()`, no contra su padre declarado; `zx-cadena` sí sabe elegir entre ramas.
   `REVISION-W06d1` no lo vio: **error del director** (no comprobé cómo trataba el nodo una rama PoW ajena).

Consecuencia: **no están demostrados** el cruce del corte ni la convergencia PoST por red (V4 en su
mitad PoST), la llegada tardía de un tercer nodo (V5), la partición y reunión (V6) ni la medida por red
(V8); V7 y V9 son parciales (una desconexión intermitente sin diagnosticar en la ráfaga de huérfanos; la
traza «nada se acepta antes de validarse» se revisó en código, no con un análisis automático).

## Otros

- Prueba de reinicio intermitente: plazo subido de 30 a 120 s (la espera ya era por eventos); ejecutada
  una vez en verde, **no** las cinco seguidas que pedía la orden.
- Todo lo pendiente pasa a `ORDEN-W06d3`.
