# PROPUESTA — PPP-v0.1

**Propuesta, no SPEC.** Nada de aquí es una regla de consenso ni texto normativo. El SPEC lo
redacta Claude. Se describen únicamente las salidas que el resultado sugiere, con sus supuestos y
su alcance, y se marca lo que **no** está demostrado.

## P1. Política de poda local (no es regla de consenso)

Para el problema (1), la poda local puede especificarse como **política de nodo**, no como regla
de validación: un nodo que ya validó puede descartar toda cabecera y cuerpo por debajo de un
checkpoint `K` que él mismo fijó, conservando

- el bloque de checkpoint y su `blue_work`/estado, para seguir calculando GHOSTDAG hacia delante;
- el conjunto UTXO (o su raíz) con los datos de deshacer de la ventana viva;
- la ventana de hashes que exige C-EXP-06 (`VIDA_MINIMA + DISPERSION = 1 114 112`, 35,65 MB);
- la ventana contextual del controlador de rango y la de `merge_depth` (C-GD-11);
- madurez de coinbase, timelocks y expiración de sectores.

**Supuestos**: existe finalidad (R-FIN-7) que hace irreversible por debajo de `K`; existe el
conjunto UTXO con datos de deshacer (TAREAS §2.6, **hoy no existe**). **Alcance**: no sirve para
un nodo nuevo ni para un cliente ligero; es una decisión local. **No fija** la profundidad, que
depende de constantes pendientes.

## P2. Sobre `parents_by_level` y §6.1: no añadir nada por poda

La conclusión del informe es que el campo **no resolvería** el problema (D5, INFORME §4). La
propuesta es, por tanto, **no reabrir §6.1** por motivos de poda y **no cablear** niveles de poda
sobre el formato actual. Un `parents_by_level` sin reto ligado a la ancestría sería un campo cuya
verificación no acreditaría lo que promete, que es peor que no tenerlo.

## P3. Si en el futuro se exigiera una prueba de poda sin confianza: qué haría falta (abierto)

**No demostrado y no adoptado.** Un diseño que pudiera funcionar tendría que aportar, a la vez:

1. **Trabajo normalizado**: medir recurso con un peso inmune al `SR` (ya existe: `w(B) =
   ⌊2^128/(SR+1)⌋`, C-GD-01) o anclar el nivel a un `SR₀` de protocolo, aceptando que la tasa
   escala `≈ SR₀/SR` (D3). Sin esto no hay unidad de trabajo estable.
2. **Reto ligado a la ancestría**: que el desafío auditado dependa del hash del conjunto de padres
   —y solo de datos ya comprometidos— de modo que una solución no pueda pegarse a otra historia.
   Esto **choca con la ventana de autoría `Δ`** (habría que elegir padres antes de auditar) y abre
   **molienda por elección de padres** (probar varios conjuntos de padres para acertar el reto),
   cuyo coste en IOPS/sector es finito y no analizado aquí. Es un rediseño de PoAS/PoT, no un
   parche de cabecera.
3. **`blue_work` verificable sin el DAG**: un compromiso del conjunto azul (Merkle/Patricia) o una
   prueba recursiva que permita recomputar `blue_work(B)` sin bajar todo el pasado. Sin esto,
   `blue_work` declarado sigue siendo gratis (ATAQUE 8) y no hay fork-choice verificable.

**Coste y riesgo**: (2) puede debilitar el anti-VDF-rápido del PoT y la unicidad; (3) exige estado
UTXO y pruebas recursivas que hoy no existen. **Recomendación**: no emprenderlo antes de cerrar
TAREAS §2.6 (estado UTXO) y las constantes de C-GD-11; y no presentarlo como «poda resuelta».

## P4. Mientras tanto (operación)

La única vía defendible hoy es la que el propio SPEC ya admite: **bootstrap por checkpoint firmado
del periodo frágil** (§12.1, C-CHK) + **archivales explícitos** + poda local de nodos veteranos.
Eso **no es** una prueba de poda e IBD sin confianza y **no cuenta como solución** (encargo §5.8).
Debe decirse con esas palabras en cualquier plan de lanzamiento.

## P5. Lo que el encargo pedía y esta auditoría entrega como «no»

Un «no existe» demostrado (D5) con la frontera exacta del problema: mientras el nivel se calcule
desde la auditoría (independiente de los padres) o desde el hash de cabecera (molible), no habrá
prueba de poda verificable. La lista de lo que **sí** sobrevive: poda local (P1), compromiso de
estado como pieza necesaria (D10) y archivales como capa social (P4).
