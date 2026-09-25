# Revisión del director — fuentes de coste PoW (2026-09-26)

**Ejecutor:** subagente Claude Sonnet (investigación de fuentes, sin código). **Revisor:** Claude
(director). **Veredicto:** aceptado como insumo de A-10/A-12; **no cierra A-10** (el propio
informe lista cuatro huecos).

**Comprobado por el director en la fuente:** bitquery.io, ataque a Ethereum Classic de
2020-07-31/08-01: bloques 10904147–10907761 (3 615), 807 260 ETC (~5,6 M USD) doble gastados,
«The total cost of mining is approx 17.5 BTC ( ~$192,000 )» comprado a «Nicehash provider
daggerhashimoto». Coincide. La tabla de RandomX del README (i9-9900K 5 770 H/s rápido) coincide con
la lectura del director del mismo README (rango 20–5 770 H/s).

**Lo que el director extrae para la decisión (derivación):**
1. El hash **desviable** es el riesgo dominante de un PoW de arranque pequeño; existe incluso sin
   mercado de alquiler (caso Qubic/Monero 2025, disputado en su alcance, pero documentado en su
   mecanismo).
2. SHA3-256 no tiene red grande que lo use (hecho negativo, con la cautela de ausencia de evidencia)
   ⇒ menos hash desviable **hoy**; a cambio es favorable a hardware especializado. RandomX tiene la
   mayor red desviable con la misma primitiva (Monero, ~6 GH/s según CoinWarz, 2026-09-25) y su
   verificación cuesta ~4 órdenes de magnitud más (derivación del informe).
3. Ninguna cifra permite aún convertir `W_min` en dinero: faltan precios en vivo.
