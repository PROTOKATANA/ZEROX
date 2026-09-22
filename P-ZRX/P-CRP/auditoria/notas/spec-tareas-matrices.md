# Extracción mecánica, literal y sin juicio — SPEC.md, TAREAS.md y matrices CRP

**Alcance.** Copia literal de textos normativos y de matrices, con su número de línea exacto,
sin interpretación, valoración ni resumen. Los ficheros de origen se han abierto y leído
íntegramente en las partes copiadas.

**Fuentes (rutas completas desde la raíz del repositorio):**

- `/home/katana/zeo/ZEROX/SPEC.md` (3848 líneas)
- `/home/katana/zeo/ZEROX/TAREAS.md` (982 líneas)
- `/home/katana/zeo/ZEROX/P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/MATRIZ-AUTORIDAD.md` (69 líneas)
- `/home/katana/zeo/ZEROX/P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/MATRIZ-AUTORIDAD.md` (69 líneas)
- `/home/katana/zeo/ZEROX/P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/MATRIZ-VALIDEZ.md` (31 líneas)
- `/home/katana/zeo/ZEROX/P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/MATRIZ-VALIDEZ.md` (31 líneas)

**Convención de copia.** En todos los bloques literales, cada línea va prefijada por su número
de línea de origen con el separador `NNNN │ `. El texto a la derecha del separador es copia
literal. Las líneas en blanco del original se reproducen como `NNNN │ ` (número seguido del
separador y nada más). Los bloques se delimitan con cuatro acentos graves para que las
cercas ``` ```text ``` internas del original no los cierren.

---

# PARTE A — `SPEC.md` (raíz del repositorio)

## A.1 · Regla `C-POT-08` y tabla §7.1 de pasos de validez (fila `1b`)

Líneas 1486–1504 de `/home/katana/zeo/ZEROX/SPEC.md`:

````
1486 │ **C-POT-08** · **Orden de validación: estructural y barato antes que AES; cada paso con su estado.**
1487 │ 
1488 │ | Paso | Comprobación | Estado si falla |
1489 │ |---|---|---|
1490 │ | 1 | **Estructural, sin AES.** Decode acotado (C-WIRE-04/C-WIRE-05); `slot(B) ≥ slot(p)` para **todo** padre (C-HDR-05); `pot_bundle_count == slot(B) − slot(sp(B)) ≤ 150` sin underflow (C-HDR-07) | `Inválido` |
1491 │ | 1b | **Flujo (`C-FLU-14`), sin AES.** Derivar `flujo(B, ·)` del pasado validado y comprobarlo contra el de cada `X ∈ past(B)` | `Inválido` si discrepa; `Pendiente` si falta pasado |
1492 │ | 2 | Cabecera y sello (C-HDR-03/C-HDR-04) | `Inválido` |
1493 │ | 3 | **Caché por clave** (`C-POT-07`): comparar la salida anclada con la entrada de la clave del contexto | `Inválido` / `Pendiente` |
1494 │ | 4 | **AES secuencial del rango**: por portador, verificar; encadenar semilla; último checkpoint == `pot_output` | `Inválido` si falla; `Pendiente` si se agota el presupuesto |
1495 │ | 5 | Solo con `Válido`: derivar `reto` del slot (`C-POT-03`) y verificar la solución PoAS contra él | según §7.1 |
1496 │ 
1497 │ El paso 3 es lo que garantiza que **el camino normal no paga AES por bloque**: el coste por salto
1498 │ queda acotado por construcción, que es el criterio de C-NET-06. El paso 4 es el respaldo bajo
1499 │ demanda (C-NET-32), con el presupuesto de `C-NET-33`. Un `Pendiente` en el paso 4 **MUST NOT**
1500 │ invalidar el bloque: el nodo retiene y completa cuando pueda.
1501 │ 
1502 │ > **El paso 1b va donde va, y no más tarde, por dos razones.** La clave de caché del paso 3
1503 │ > **empieza por `f`**: sin el flujo resuelto no hay clave que consultar. Y `C-POT-06` exige que el
1504 │ > flujo lo aporte el contexto: `C-FLU-10` y `C-FLU-11` son quien cumple esa exigencia.
````

## A.2 · Regla `C-FLU-01` (con sus notas/blockquote inmediatos)

Líneas 1507–1542 de `/home/katana/zeo/ZEROX/SPEC.md`:

````
1507 │ **C-FLU-01** · **Todo lo del flujo se mide en índices de slot de PoT, y `L` va atada a `F`.**
1508 │ 
1509 │ ```text
1510 │ T_j      = j · I_slots                  umbral de época j (índice de slot), j ≥ 1
1511 │ I_j      = ancla de la época j          (C-FLU-04)
1512 │ t_j      = slot(I_j) + L_slots          instante de activación (índice de slot)
1513 │ profundidad(t, P) = t − slot(P)         en slots, con P el último ancestro común
1514 │ 
1515 │ L_slots := máx( F_slots , L_suelo_slots , S_max_slots + 1 )
1516 │ ```
1517 │ 
1518 │ `L_slots` es una **definición**, no un parámetro libre: **MUST** derivarse y **MUST NOT**
1519 │ declararse aparte. `F_slots := ⌈F / τ_nom⌉`. `F_slots`, `L_suelo_slots` e `I_slots` son
1520 │ **símbolos**; esta regla no les da valor.
1521 │ 
1522 │ Una comparación de consenso **MUST NOT** depender de `τ_nom` en tiempo de ejecución ni de ningún
1523 │ reloj físico. **La profundidad de una reorganización MUST medirse como
1524 │ `slot(punta) − slot(último ancestro común)`, en índices de slot; MUST NOT medirse en bloques**: a
1525 │ `λ = 1 bloque/s` y `τ_nom = 1 s/slot` coinciden nominalmente, pero C-GD-04 admite saltos de hasta
1526 │ `S_max_slots` en la cadena, así que las dos cuentas se separan y **solo el slot es infalsificable**.
1527 │ 
1528 │ > **Los tres términos del máximo, y por qué hacen falta los tres.** El primero es la atadura que
1529 │ > Katana decidió (perfil **1a**): si `F` baja en producción, `L` baja con ella, como identidad y no
1530 │ > como nota de operación. El segundo es el **suelo**, y existe porque el primero no basta: `L`
1531 │ > responde a una magnitud distinta —la cola de desacuerdo honesto frente a `Δ`—, que no baja cuando
1532 │ > baja `F`. El tercero hace que `C-FLU-08` se cumpla por construcción para cualquier `F`.
1533 │ >
1534 │ > **`L_suelo_slots` MUST fijarse** a partir de (a) la cola medida de desacuerdo de cadena
1535 │ > seleccionada a una `ε` elegida explícitamente y (b) **una cota de `Δ` medida en red real**.
1536 │ > Mientras no exista (b), cualquier valor es provisional y **MUST** decirlo. La referencia de orden
1537 │ > de magnitud —y **solo** eso— está en `veritas/consenso/ancla-inyeccion-v2/`, con `Δ` **simulada**
1538 │ > (DMS-v0.1), no medida. `<<PENDIENTE: el valor de L_suelo_slots>>`.
1539 │ >
1540 │ > ⚠️ §7.3 advierte que `F` «no se iguala por defecto a `L`». Esa frase y `C-FLU-01` **no dicen lo
1541 │ > mismo**: aquella prohíbe copiar `L` desde `F`; ésta **deriva `L` de `F` con un suelo**. Se parecen
1542 │ > mucho y significan cosas distintas.
````

## A.3 · Regla `C-FLU-13` (con su nota/blockquote inmediato)

Líneas 1701–1716 de `/home/katana/zeo/ZEROX/SPEC.md`:

````
1701 │ **C-FLU-13** · **Validez absoluta.** `B` es **válido** si y solo si: (1) su solución PoAS verifica
1702 │ bajo `reto(flujo(B, slot(B)), slot(B))`; (2) su justificación de PoT cubre el rango exigido por
1703 │ C-HDR-07 **bajo ese mismo flujo**; (3) todos los bloques de `past(B)` son válidos; (4) cumple
1704 │ `C-FLU-14`.
1705 │ 
1706 │ La validez de `B` **MUST NOT** depender de la cadena seleccionada del observador, de su punta, de
1707 │ su reloj ni del orden de llegada. Es función de `past(B)` y de nada más.
1708 │ 
1709 │ > **Ésta es la bifurcación de §2.1 de `TAREAS.md`, y su precio se paga aquí, explícito.** Si la
1710 │ > validez del PoT fuese **relativa a la cadena seleccionada**, se abriría el **multistream**
1711 │ > —`α_mínimo = 1/(S+1)`, medido en `veritas/seguridad/coste-rama-privada-v1/`—. Siendo
1712 │ > **absoluta**, el multistream queda cerrado (un flujo fabricado por el atacante no es el flujo de
1713 │ > ningún bloque honesto y sus bloques no se pueden referenciar, `C-FLU-14`) y lo que se abre es la
1714 │ > **partición de flujo** (§7.1.6). **Lo que la contiene no es una regla: es `L_slots` frente a
1715 │ > `Δ`**, con la probabilidad medida en simulación en `veritas/consenso/ancla-inyeccion-v2/` y la
1716 │ > `Δ` **simulada, no medida en red**.
````

## A.4 · Regla `C-FLU-14` (con su nota/blockquote inmediato)

Líneas 1718–1731 de `/home/katana/zeo/ZEROX/SPEC.md`:

````
1718 │ **C-FLU-14** · **Pasado consistente de flujo.**
1719 │ 
1720 │ ```text
1721 │ Para todo X ∈ past(B):   flujo(X, slot(X)) == flujo(B, slot(X))
1722 │ ```
1723 │ 
1724 │ Un bloque **MUST NOT** referenciar un bloque de otro flujo. La comprobación es **estructural** y va
1725 │ **antes** de tocar ningún PoT (paso 1b de `C-POT-08`). Si el nodo no tiene todo `past(B)` el estado
1726 │ es **`Pendiente` por contexto incompleto, nunca `Inválido`**.
1727 │ 
1728 │ > **No necesita AES, y está demostrado:** los ingredientes de `flujo(·)` son una constante, dos
1729 │ > campos de cabecera por ancla, los `slot(I_j)` y el orden GHOSTDAG restringido a `V_j`. **Ninguno
1730 │ > exige evaluar la cadena AES.** Lo que **sí** cuesta es recomputar cadena y flujo del sub-DAG
1731 │ > ajeno, que es superficie de DoS: por eso el paso 1b va bajo el presupuesto de `C-NET-33`.
````

## A.5 · Regla `C-FLU-20` (con su nota/blockquote inmediato)

Líneas 1733–1750 de `/home/katana/zeo/ZEROX/SPEC.md`:

````
1733 │ **C-FLU-20** · **Qué hace el productor con un bloque tardío que cambiaría un ancla ya activada.**
1734 │ Al construir un bloque `B`, el productor **MUST** descartar de su cola de candidatos (C-GD-10) toda
1735 │ punta cuya inclusión cambiaría `entropía_j` o `t_j` de **alguna época `j` ya activada en el pasado
1736 │ de `B`** —es decir, con `t_j ≤ slot(X)` para algún `X ∈ past(B)`—. Un productor **MUST NOT** emitir
1737 │ un bloque inválido por una elección de padres que él mismo controla.
1738 │ 
1739 │ Es **política de producción**, no verificación: un verificador no rechaza por el conjunto de
1740 │ padres, rechaza por `C-FLU-14`, que es validez objetiva.
1741 │ 
1742 │ > **Consecuencia, y hay que decirla así: ese bloque queda INFUSIONABLE PARA SIEMPRE en ese flujo.**
1743 │ > Como el pasado solo crece, ningún descendiente futuro podrá fusionarlo si hacerlo cambiaría `I_j`.
1744 │ > **No hay caducidad ni ventana de rescate.** Normalmente paga el atacante, que es quien retiene;
1745 │ > **el colateral honesto no está medido** (`TAREAS.md` §2.9).
1746 │ >
1747 │ > ⚠️ **Esta política MUST NOT extenderse al intervalo anterior a `t_j`.** Antes de `t_j` fusionar es
1748 │ > legal, así que la política no se apoyaría en ninguna invalidez: sería un «lo primero que vi
1749 │ > manda» y **haría el flujo dependiente del orden de llegada de los mensajes**, que es exactamente
1750 │ > el defecto que la ronda 10a tuvo que retirar. **Solo actúa después de la activación.**
````

## A.6 · Regla `C-FLU-21` (con su nota/blockquote inmediato)

Líneas 1752–1766 de `/home/katana/zeo/ZEROX/SPEC.md`:

````
1752 │ **C-FLU-21** · **La inyección ya activada se hereda, no se recalcula.** Si `past(B)` contiene algún
1753 │ bloque `X` con `t_j ≤ slot(X)`, la inyección `j` de `B` —su `entropía_j` y su `t_j`— **MUST** ser la
1754 │ de `X` y **MUST NOT** recalcularse a partir de `V_j(B)`. `I_j` solo se calcula con `C-FLU-04`
1755 │ cuando ningún bloque del pasado la tiene activada.
1756 │ 
1757 │ > **No cambia qué bloques son válidos: la vuelve constructiva.** El verificador deja de recalcular
1758 │ > `Chn(V_j(B))` por bloque y la hereda; el ancla se calcula **una vez por época y se transporta**.
1759 │ > Se escribe aunque sea redundante porque, sin ella, dos implementaciones pueden calcular lo mismo
1760 │ > por caminos distintos y discrepar en un borde que nadie ha enumerado.
1761 │ >
1762 │ > **Decidido por Katana el 2026-09-20 (D-F8 = C): la vista NO se congela.** Congelarla reabriría
1763 │ > la circularidad del ancla —el ancla dependiendo de la cadena, la cadena de la validez, la validez
1764 │ > del ancla— en una franja de anchura `≤ S_max_slots`, y compraba muy poco: adelantar la
1765 │ > congelación 150 slots nominales sobre una carrera que dura `L_slots ≥ F_slots`. **Esto no arregla
1766 │ > nada de la carrera anterior a `t_j`.**
````

## A.7 · Regla `C-FLU-22` (con sus notas/blockquote inmediatos)

Líneas 1796–1850 de `/home/katana/zeo/ZEROX/SPEC.md`:

````
1796 │ **C-FLU-22** · **Adopción del flujo rival dentro de la ventana, con presupuesto.**
1797 │ 
1798 │ ```text
1799 │ Adoptar = seleccionar. Una rama de otro flujo es VÁLIDA en términos absolutos (C-FLU-13):
1800 │ NO se puede FUSIONAR (C-FLU-14) pero SÍ se puede SELECCIONAR.
1801 │ 
1802 │ d(t) := slot(punta seleccionada actual) − slot(P),  con P el ÚLTIMO ANCESTRO COMÚN
1803 │         de la cadena actual y la rama candidata.
1804 │ ```
1805 │ 
1806 │ Un nodo **MUST** elegir entre ramas válidas por la selección ordinaria de GHOSTDAG (mayor
1807 │ `blue_work`; desempates de C-GD-03), **sin excepción por flujo**, limitada por `C-FIN-01`: solo
1808 │ mientras `d < F_slots`.
1809 │ 
1810 │ Orden y coste, que **MUST** respetarse:
1811 │ 
1812 │ 1. La comprobación estructural del flujo va **siempre primero** (paso 1b de `C-POT-08`). **Sin AES.**
1813 │ 2. El PoT del flujo rival se verifica **solo si hace falta para adoptar**: solo si la rama rival va
1814 │    **por delante** en `blue_work` y `d < F_slots`. Si no, **no se verifica nada**: la punta se
1815 │    ignora (`C-FIN-01`).
1816 │ 3. Todo ello **bajo los dos presupuestos de `C-NET-33`**. Agotarlos da **`Pendiente`, nunca
1817 │    `Inválido`**.
1818 │ 4. **Sin validez comprobada no se adopta.** `Pendiente` **MUST NOT** contar como válido ni como
1819 │    inválido: el nodo se queda donde está y reintenta.
1820 │ 
1821 │ > **La congelación es simultánea.** El instante de cierre es `slot(P) + F_slots`, **función
1822 │ > exclusiva de `P`**: no depende de cuándo cada nodo se enteró de la rama rival, ni de su reloj, ni
1823 │ > del orden de llegada. Todos los nodos **con cadena** cruzan el umbral en el mismo índice de slot.
1824 │ >
1825 │ > **La anchura de la ventana depende de cómo nació la partición**, y esto es lo que hay que leer:
1826 │ >
1827 │ > | Nacimiento | `slot(P)` | Ventana |
1828 │ > |---|---|---|
1829 │ > | **Espontáneo** (latencia) | `t_j − 1` | **máxima**, `F_slots − 1` |
1830 │ > | Corte de red que empezó en `s₀` | `s₀` | `[t_j, s₀ + F_slots)` |
1831 │ > | **Corte de red más largo que `L`** | `≤ t_j − L_slots` | **VACÍA** |
1832 │ >
1833 │ > **Riesgo residual, con su alcance declarado.** Aun con congelación simultánea quedan dos rendijas
1834 │ > medidas en `veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1): el **desfase de vista** en el
1835 │ > instante de congelación, que va como `√(τ/F)` —**condicionado a que la partición haya nacido y a
1836 │ > reparto simétrico**—, y **el nodo que sincroniza después**, que toma el líder del momento. El
1837 │ > segundo **no lo cierra esta regla**: lo gobiernan `C-FLU-18` y `C-FLU-17`. `C-NET-33` añade una
1838 │ > **tercera, no medida** y parcialmente bajo control del atacante.
1839 │ >
1840 │ > **R-FIN-5 cambia de motivo, y la frase exacta importa.** Deja de ser cierto a la letra que «un
1841 │ > nodo honesto **jamás** verifica el PoT de un flujo ajeno». Lo cierto es: **nunca lo verifica para
1842 │ > FUSIONAR** —`C-FLU-14` es estructural y no toca AES—; **solo lo verifica para ADOPTAR**, dentro
1843 │ > de esta ventana y bajo presupuesto. La virtud que se conserva es la que importaba: **el camino
1844 │ > normal nunca paga AES ajeno**.
1845 │ >
1846 │ > **Forzar ese gasto no es barato, y está demostrado** en
1847 │ > `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1373-1425`: exige ganar una carrera de
1848 │ > `blue_work` de longitud `L_slots`. La demostración **usa `L_slots ≥ F_slots`**, así que es un
1849 │ > argumento a favor del perfil 1a, independiente de los demás. **La cola de esa carrera no está
1850 │ > medida** (`TAREAS.md` §2.9).
````

## A.8 · Regla `C-FIN-01` (con sus notas/blockquote inmediatos)

Líneas 2532–2570 de `/home/katana/zeo/ZEROX/SPEC.md`:

````
2532 │ **C-FIN-01 · Finalidad en índices de slot, sin `exit`.**
2533 │ 
2534 │ ```text
2535 │ Sea d = slot(punta actual) − slot(último ancestro común con la punta candidata),
2536 │ en índices de slot de PoT (C-FLU-01).
2537 │ 
2538 │ Un nodo MUST NOT sustituir su cadena seleccionada por una candidata con d ≥ F_slots.
2539 │ Una punta que lo exigiera se IGNORA.
2540 │ El nodo MUST seguir operando: MUST NOT detenerse, MUST NOT abortar y MUST NOT exigir
2541 │ intervención del operador por este motivo.
2542 │ ```
2543 │ 
2544 │ `F_slots` es un **SÍMBOLO**. Esta regla no le da valor: `<<PENDIENTE: §7.3>>`.
2545 │ 
2546 │ `C-FIN-01` obliga **únicamente** a quien ya tiene una cadena seleccionada que reorganizar
2547 │ (`C-FLU-18`). La adopción dentro de la ventana que esta desigualdad deja abierta es `C-FLU-22`.
2548 │ 
2549 │ > **De dónde sale cada pieza.** El enunciado es el de R-FIN-7 (evidencia histórica,
2550 │ > `research/dag-poas-ancla-de-orden.md:301-303`), con tres precisiones que R-FIN-7 no tenía: la
2551 │ > magnitud es el **índice de slot** y no «segundos de slot»; **la desigualdad es explícita** —
2552 │ > profundidad **exactamente** `F_slots` cae **dentro** de lo prohibido, que es la lectura
2553 │ > conservadora (Katana, D-F4 = A)—; y el «nunca apaga el proceso» pasa de nota a **MUST NOT**
2554 │ > enumerado, porque es precisamente lo que la diferencia del comportamiento vigente del código.
2555 │ >
2556 │ > **Por qué en slots y no en bloques.** `C-REORG-07` cuenta **bloques**; toda la regla de flujo
2557 │ > cuenta **slots**. Convertir una en otra exige `λ`, que es una magnitud **estimada por el
2558 │ > retarget**, no una constante de consenso. **Una regla de finalidad medida en bloques no se puede
2559 │ > comparar con una profundidad medida en slots sin meter `λ` en el consenso.**
2560 │ >
2561 │ > **Relación con `C-REORG-07`: se declara, no se resuelve.** `C-REORG-07` sigue siendo
2562 │ > **transitoria** y esta regla **no la toca**. Por alcance decidido (D-F3 = C, acotada al
2563 │ > enunciado) **NO entran aquí**: la reconciliación con el código que hoy **se detiene**, la
2564 │ > relación con `COINBASE_MATURITY` —de la que `MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 11 999`
2565 │ > deriva— y el techo de archivado. Los tres están nombrados en `TAREAS.md` §2.9.
2566 │ >
2567 │ > ⚠️ **Dos reglas de profundidad conviven en este documento y dicen cosas distintas.** La que rige
2568 │ > el diseño destino es **ésta**; `C-REORG-07` es **transitoria** y describe lo que el código hace
2569 │ > hoy, no lo que el protocolo manda. **La reconciliación sigue pendiente** y está pedida en §13 y
2570 │ > nombrada en `TAREAS.md` §2.9.
````

## A.9 · Sección `§17` completa

Líneas 3774–3792 de `/home/katana/zeo/ZEROX/SPEC.md` (la sección §17 termina aquí; la línea
siguiente, 3793, está en blanco y 3794 inicia `## 18 · Trazabilidad`):

````
3774 │ ## 17 · Pendientes activos del consenso destino
3775 │ 
3776 │ Esta lista es local y no depende del estado de un vault externo. La limpieza documental no
3777 │ congela parámetros ni convierte prototipos en implementaciones.
3778 │ 
3779 │ | Área | Trabajo pendiente |
3780 │ |---|---|
3781 │ | Cabecera y wire | Integrar en la ruta activa del nodo el formato ya fijado en §6.1–§6.2: layout (C-HDR-01), prefirma (C-HDR-03), justificación PoT (C-HDR-07) y codec único (C-HDR-09). El texto normativo no deja nada pendiente aquí. |
3782 │ | Prueba de espacio/tiempo | Verificación conjunta de solución, KZG, sello, reto secuencial, autoría y flujos. **🔴 PRIORIDAD: la regla de dependencias por flujo del PoT es el único punto medido que degrada el umbral de seguridad.** `veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1, 2026-09-18) mide `α_mínimo = 1/2` —el mismo que PoW y que GHOSTDAG sobre PoW— para el diseño con **un solo flujo**: la tasa de soluciones es `∝ SR` y el peso `∝ 1/SR`, así que el rango endógeno **se cancela** y no es explotable en media. Pero con `S` flujos de PoT simultáneos la cuota efectiva es `S·α/(1−α+S·α)` y el umbral cae a `α = 1/(S+1)`: **0,040 con `S = 24`**, que es el límite de IOPS de un SSD de 100 k, **sin espacio adicional**. Es el ATAQUE 2 de `research/dag-poas-auditoria.md` (2026-09-06, gravedad crítica), que ya declaraba depender de «una regla que la propuesta no escribe» y advertía que **las dos opciones obvias fallan**: validez del PoT relativa a la cadena seleccionada abre el multistream; validez absoluta abre el split. **DECIDIDO por Katana (2026-09-19/20) y REDACTADO en §7.1: validez ABSOLUTA (`C-FLU-13`), perfil 1a (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`).** El multistream queda cerrado porque un flujo fabricado no es el de ningún bloque honesto y sus bloques no se pueden referenciar (`C-FLU-14`). **El split NO se cierra con una regla: se previene con `L` frente a `Δ`**, y si nace se cura solo en el caso espontáneo (`C-FLU-22`), nunca en un corte de red más largo que `L`. **Lo que queda: el código** —ninguna de las 31 reglas nuevas tiene una línea— y las mediciones que faltan (`TAREAS.md` §2.9). |
3783 │ | Rango | R-FIN-13′ completo: arranque, ventana, redondeos, fusiones tardías, ramas candidatas. |
3784 │ | DAG | Redactado el 2026-09-17: conflictos de transacciones (**C-ORD-04**), `pick_virtual_parents` (**C-GD-10**) y *bounded merge depth* con kosherización (**C-GD-11**). Quedan: el enlace de C-ORD-04 con el estado UTXO (§2.6) y los **cinco pendientes de C-GD-11** —métrica, valor, bootstrap, borde de igualdad y relación con finalidad y poda—, que no se fijan por analogía con Kaspa ni derivando de `F = 2 h` provisional. GHOSTDAG, U2/U3″, peso, cadena seleccionada y orden quedan especificados en §11. |
3785 │ | Poda (*pruning*) | **Auditado el 2026-09-17** (`veritas/consenso/poda-post-v1/`, PPP-v0.1), con **defectos anotados el 2026-09-18** en su `PROCEDENCIA.md` §3.3–§3.4. **Lo que falta no es el IBD sin confianza: es el IBD SUCINTO.** Un nodo nuevo siempre puede descargar y validar toda la historia desde el génesis sin confiar en nadie; lo que ZEROX no tiene es un arranque **sucinto desde estado podado** sin ancla externa. **(1) Poda local:** política de nodo **viable en principio**, no implementada, y condicionada a que existan finalidad integrada (R-FIN-7), estado UTXO con datos de deshacer (§2.6, hoy inexistente) y una profundidad de retención cerrada (C-GD-11). **(2) Prueba de poda por certificados de niveles: descartada.** El nivel de solución se calcula **antes** de elegir padres, así que se pega a cualquier historia; el nivel por hash de cabecera sí liga a los padres pero se muele con CPU (C-HDR-04: el sello Ed25519 no es único, y `merkle_root` varía con la coinbase), luego no mide espacio. En PoW ambas propiedades coinciden en el mismo objeto; en PoST se separan, y esa separación es la raíz. **El resultado vale para los mecanismos examinados, no para toda familia de pruebas**: su formalización no captura que el recurso deba pagarse de nuevo por cada ancestría, y no modela el PoT ni sus flujos. **(3) Disponibilidad histórica** — capa social/económica, no criptográfica: no resuelve (2). **Consecuencia: §6.1 NO se reabre por este mecanismo** — `parents_by_level` no rescata este certificado, luego el cableado de la cabecera DAG no está bloqueado; un reto futuro ligado a la ancestría sí la reabriría. **Abierto y sin cerrar:** la vía de prueba recursiva (coste **estimado**, no medido: no hay circuito ni banco de probador) y, sobre todo, **el coste real de construir una rama privada con más `blue_work`**, que ninguna auditoría ha medido y que decide si esto es un problema de ingeniería o de consenso. **La poda sigue siendo requisito para lanzar mainnet.** Una testnet **MAY** operar sin poda con nodos archivales declarados explícitamente, y eso **no cuenta como solución**. |
3786 │ | Alturas y calendario | Activaciones, expiración de tx/sectores, timelocks, coinbase y archivado derivados del orden DAG. |
3787 │ | Finalidad | **R-FIN-7 queda redactada como `C-FIN-01` (§12), en índices de slot y sin `exit`.** Lo que sigue abierto: la **reconciliación** con `C-REORG-07`, con el código que hoy se detiene, con `COINBASE_MATURITY` y con el techo de archivado (fuera de alcance por decisión, D-F3); la elección conjunta de `I`/`F`/`L_suelo`/`ρ_max`; y la **recuperación**, que `C-FLU-22` solo cubre para el nacimiento espontáneo de una partición de flujo. |
3788 │ | Red | Δ natural y coste por salto: **medidos** (`veritas/finalidad/delta-medido-v1/`, `veritas/rendimiento/coste-salto-v1/`, 2026-09-14). El transporte quedó especificado el 2026-09-17: relé «1+» obligatorio (C-NET-25…28), prioridad y presupuesto de subida (C-NET-29, C-NET-30) y PoT por slot (C-NET-31, C-NET-32). **Pendiente:** los tres valores que el v2a/v2b deben calibrar —tamaño de la cola de anuncios huérfanos, presupuesto de reenvío de transacciones y presupuesto de CPU del PoT bajo demanda—, la decisión de relajar o no C-NET-06, y el código: ninguna de las ocho reglas nuevas tiene implementación. |
3789 │ | Génesis | Parámetros y hashes PoST/DAG distintos por red; bootstrap explícito. |
3790 │ | Pagos | Recalibrar §13 con el mismo modelo y criterio de aceptación en todas las alternativas. |
3791 │ | Blindado | Convertir investigación Orchard de §9 en reglas, compromisos y validación integrados. |
3792 │ | Tarifas/capacidad | Revisar coste adversarial, suelo de tarifa y peso blindado conservando constantes adoptadas. |
````

## A.10 · TODAS las apariciones en `SPEC.md` de las cadenas pedidas

Búsqueda literal (`grep -F`) sobre `/home/katana/zeo/ZEROX/SPEC.md`, una por una. Se copia la
línea completa que contiene cada aparición.

### `coste-rama-privada` — 2 apariciones

````
1711 │ > —`α_mínimo = 1/(S+1)`, medido en `veritas/seguridad/coste-rama-privada-v1/`—. Siendo
````

````
3782 │ | Prueba de espacio/tiempo | Verificación conjunta de solución, KZG, sello, reto secuencial, autoría y flujos. **🔴 PRIORIDAD: la regla de dependencias por flujo del PoT es el único punto medido que degrada el umbral de seguridad.** `veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1, 2026-09-18) mide `α_mínimo = 1/2` —el mismo que PoW y que GHOSTDAG sobre PoW— para el diseño con **un solo flujo**: la tasa de soluciones es `∝ SR` y el peso `∝ 1/SR`, así que el rango endógeno **se cancela** y no es explotable en media. Pero con `S` flujos de PoT simultáneos la cuota efectiva es `S·α/(1−α+S·α)` y el umbral cae a `α = 1/(S+1)`: **0,040 con `S = 24`**, que es el límite de IOPS de un SSD de 100 k, **sin espacio adicional**. Es el ATAQUE 2 de `research/dag-poas-auditoria.md` (2026-09-06, gravedad crítica), que ya declaraba depender de «una regla que la propuesta no escribe» y advertía que **las dos opciones obvias fallan**: validez del PoT relativa a la cadena seleccionada abre el multistream; validez absoluta abre el split. **DECIDIDO por Katana (2026-09-19/20) y REDACTADO en §7.1: validez ABSOLUTA (`C-FLU-13`), perfil 1a (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`).** El multistream queda cerrado porque un flujo fabricado no es el de ningún bloque honesto y sus bloques no se pueden referenciar (`C-FLU-14`). **El split NO se cierra con una regla: se previene con `L` frente a `Δ`**, y si nace se cura solo en el caso espontáneo (`C-FLU-22`), nunca en un corte de red más largo que `L`. **Lo que queda: el código** —ninguna de las 31 reglas nuevas tiene una línea— y las mediciones que faltan (`TAREAS.md` §2.9). |
````

### `CRP-v0` — 1 aparición

````
3782 │ | Prueba de espacio/tiempo | Verificación conjunta de solución, KZG, sello, reto secuencial, autoría y flujos. **🔴 PRIORIDAD: la regla de dependencias por flujo del PoT es el único punto medido que degrada el umbral de seguridad.** `veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1, 2026-09-18) mide `α_mínimo = 1/2` —el mismo que PoW y que GHOSTDAG sobre PoW— para el diseño con **un solo flujo**: la tasa de soluciones es `∝ SR` y el peso `∝ 1/SR`, así que el rango endógeno **se cancela** y no es explotable en media. Pero con `S` flujos de PoT simultáneos la cuota efectiva es `S·α/(1−α+S·α)` y el umbral cae a `α = 1/(S+1)`: **0,040 con `S = 24`**, que es el límite de IOPS de un SSD de 100 k, **sin espacio adicional**. Es el ATAQUE 2 de `research/dag-poas-auditoria.md` (2026-09-06, gravedad crítica), que ya declaraba depender de «una regla que la propuesta no escribe» y advertía que **las dos opciones obvias fallan**: validez del PoT relativa a la cadena seleccionada abre el multistream; validez absoluta abre el split. **DECIDIDO por Katana (2026-09-19/20) y REDACTADO en §7.1: validez ABSOLUTA (`C-FLU-13`), perfil 1a (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`).** El multistream queda cerrado porque un flujo fabricado no es el de ningún bloque honesto y sus bloques no se pueden referenciar (`C-FLU-14`). **El split NO se cierra con una regla: se previene con `L` frente a `Δ`**, y si nace se cura solo en el caso espontáneo (`C-FLU-22`), nunca en un corte de red más largo que `L`. **Lo que queda: el código** —ninguna de las 31 reglas nuevas tiene una línea— y las mediciones que faltan (`TAREAS.md` §2.9). |
````

### `α = 1/2` — 0 apariciones

No aparece la cadena literal `α = 1/2` en `SPEC.md`. La forma presente es `α_mínimo = 1/2`
(línea 3782, copiada arriba; también dentro de la fila `C-FLU-13` no, sólo en §17).

### `1/2` — 1 aparición

````
3782 │ | Prueba de espacio/tiempo | Verificación conjunta de solución, KZG, sello, reto secuencial, autoría y flujos. **🔴 PRIORIDAD: la regla de dependencias por flujo del PoT es el único punto medido que degrada el umbral de seguridad.** `veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1, 2026-09-18) mide `α_mínimo = 1/2` —el mismo que PoW y que GHOSTDAG sobre PoW— para el diseño con **un solo flujo**: la tasa de soluciones es `∝ SR` y el peso `∝ 1/SR`, así que el rango endógeno **se cancela** y no es explotable en media. Pero con `S` flujos de PoT simultáneos la cuota efectiva es `S·α/(1−α+S·α)` y el umbral cae a `α = 1/(S+1)`: **0,040 con `S = 24`**, que es el límite de IOPS de un SSD de 100 k, **sin espacio adicional**. Es el ATAQUE 2 de `research/dag-poas-auditoria.md` (2026-09-06, gravedad crítica), que ya declaraba depender de «una regla que la propuesta no escribe» y advertía que **las dos opciones obvias fallan**: validez del PoT relativa a la cadena seleccionada abre el multistream; validez absoluta abre el split. **DECIDIDO por Katana (2026-09-19/20) y REDACTADO en §7.1: validez ABSOLUTA (`C-FLU-13`), perfil 1a (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`).** El multistream queda cerrado porque un flujo fabricado no es el de ningún bloque honesto y sus bloques no se pueden referenciar (`C-FLU-14`). **El split NO se cierra con una regla: se previene con `L` frente a `Δ`**, y si nace se cura solo en el caso espontáneo (`C-FLU-22`), nunca en un corte de red más largo que `L`. **Lo que queda: el código** —ninguna de las 31 reglas nuevas tiene una línea— y las mediciones que faltan (`TAREAS.md` §2.9). |
````

### `multistream` — 3 apariciones

````
1710 │ > validez del PoT fuese **relativa a la cadena seleccionada**, se abriría el **multistream**
````

````
1712 │ > **absoluta**, el multistream queda cerrado (un flujo fabricado por el atacante no es el flujo de
````

````
3782 │ | Prueba de espacio/tiempo | Verificación conjunta de solución, KZG, sello, reto secuencial, autoría y flujos. **🔴 PRIORIDAD: la regla de dependencias por flujo del PoT es el único punto medido que degrada el umbral de seguridad.** `veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1, 2026-09-18) mide `α_mínimo = 1/2` —el mismo que PoW y que GHOSTDAG sobre PoW— para el diseño con **un solo flujo**: la tasa de soluciones es `∝ SR` y el peso `∝ 1/SR`, así que el rango endógeno **se cancela** y no es explotable en media. Pero con `S` flujos de PoT simultáneos la cuota efectiva es `S·α/(1−α+S·α)` y el umbral cae a `α = 1/(S+1)`: **0,040 con `S = 24`**, que es el límite de IOPS de un SSD de 100 k, **sin espacio adicional**. Es el ATAQUE 2 de `research/dag-poas-auditoria.md` (2026-09-06, gravedad crítica), que ya declaraba depender de «una regla que la propuesta no escribe» y advertía que **las dos opciones obvias fallan**: validez del PoT relativa a la cadena seleccionada abre el multistream; validez absoluta abre el split. **DECIDIDO por Katana (2026-09-19/20) y REDACTADO en §7.1: validez ABSOLUTA (`C-FLU-13`), perfil 1a (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`).** El multistream queda cerrado porque un flujo fabricado no es el de ningún bloque honesto y sus bloques no se pueden referenciar (`C-FLU-14`). **El split NO se cierra con una regla: se previene con `L` frente a `Δ`**, y si nace se cura solo en el caso espontáneo (`C-FLU-22`), nunca en un corte de red más largo que `L`. **Lo que queda: el código** —ninguna de las 31 reglas nuevas tiene una línea— y las mediciones que faltan (`TAREAS.md` §2.9). |
````

### `1/(S+1)` — 2 apariciones

````
1711 │ > —`α_mínimo = 1/(S+1)`, medido en `veritas/seguridad/coste-rama-privada-v1/`—. Siendo
````

````
3782 │ | Prueba de espacio/tiempo | Verificación conjunta de solución, KZG, sello, reto secuencial, autoría y flujos. **🔴 PRIORIDAD: la regla de dependencias por flujo del PoT es el único punto medido que degrada el umbral de seguridad.** `veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1, 2026-09-18) mide `α_mínimo = 1/2` —el mismo que PoW y que GHOSTDAG sobre PoW— para el diseño con **un solo flujo**: la tasa de soluciones es `∝ SR` y el peso `∝ 1/SR`, así que el rango endógeno **se cancela** y no es explotable en media. Pero con `S` flujos de PoT simultáneos la cuota efectiva es `S·α/(1−α+S·α)` y el umbral cae a `α = 1/(S+1)`: **0,040 con `S = 24`**, que es el límite de IOPS de un SSD de 100 k, **sin espacio adicional**. Es el ATAQUE 2 de `research/dag-poas-auditoria.md` (2026-09-06, gravedad crítica), que ya declaraba depender de «una regla que la propuesta no escribe» y advertía que **las dos opciones obvias fallan**: validez del PoT relativa a la cadena seleccionada abre el multistream; validez absoluta abre el split. **DECIDIDO por Katana (2026-09-19/20) y REDACTADO en §7.1: validez ABSOLUTA (`C-FLU-13`), perfil 1a (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`).** El multistream queda cerrado porque un flujo fabricado no es el de ningún bloque honesto y sus bloques no se pueden referenciar (`C-FLU-14`). **El split NO se cierra con una regla: se previene con `L` frente a `Δ`**, y si nace se cura solo en el caso espontáneo (`C-FLU-22`), nunca en un corte de red más largo que `L`. **Lo que queda: el código** —ninguna de las 31 reglas nuevas tiene una línea— y las mediciones que faltan (`TAREAS.md` §2.9). |
````

### `4 %` — 1 aparición

````
2129 │ > los 1000 M hacia el **año 10,69**. Inflación perpetua **0,84 %/año**, decreciente en porcentaje
````

Nota mecánica: la cadena `4 %` casa aquí dentro de `0,84 %` (el `4` de `0,84` seguido de ` %`).
No hay ninguna otra aparición de `4 %` en `SPEC.md`.

### `liga de PoW` — 0 apariciones

No aparece la cadena literal `liga de PoW` en `SPEC.md`.

### `seguro al` — 0 apariciones

No aparece la cadena literal `seguro al` en `SPEC.md`.

---

# PARTE B — `TAREAS.md` (raíz del repositorio)

## B.1 · Sección `§2.1` completa

Líneas 124–226 de `/home/katana/zeo/ZEROX/TAREAS.md`:

````
124 │ ### 2.1 · Dependencias por flujo del PoT (§7.1) — CERRADO EN EL SPEC (2026-09-20), FALTA CABLEAR
125 │ 
126 │ > **CORRECCIÓN DEL TITULAR, y hay que leerla antes que el resto de la sección.** Este apartado se
127 │ > tituló «🔴 AQUÍ ESTÁ EL PROBLEMA DE SEGURIDAD» porque `1/(S+1)` —el **4 %** con `S ≈ 24`— se leyó
128 │ > como el umbral del diseño. **No lo es.** `1/(S+1)` es la **regla aditiva** —`S` flujos
129 │ > independientes suman cuota— y **no aplica con pasado consistente de flujo**: bajo `C-FLU-14` un
130 │ > bloque no puede referenciar un bloque de otro flujo, así que los flujos del atacante no se
131 │ > agregan a una sola cadena. **El propio instrumento ya lo etiquetaba así**: CRP-v0.1 declaró su
132 │ > resultado «condicionado al diseño del flujo, no demostrado»
133 │ > (`veritas/seguridad/coste-rama-privada-v1/`). El umbral que CRP-v0.1 midió con **un solo flujo**
134 │ > es `α_mínimo = 1/2`, el mismo que PoW — **pero esa cifra no está cerrada: CRP-v0.2 declara
135 │ > «sustituye la evidencia protocolaria de CRP-v0.1» (baseline idealizado útil; veredicto
136 │ > protocolario INCONCLUSO), y ni v0.2 ni v0.3 están validadas ni migradas** (§2.9 (e)). **Lo que
137 │ > este cierre corrige es el titular del 4 %, y no lo sustituye por otro titular ancho.**
138 │ >
139 │ > **Lo que el multistream sí obligaba a decidir era la bifurcación**, y Katana la decidió: validez
140 │ > **absoluta** (`C-FLU-13`) con perfil **1a**. Su precio no es el 4 %: es la **partición de flujo**,
141 │ > que no se cierra con una regla y se previene con `L_slots` frente a `Δ`.
142 │ 
143 │ **Estado: CERRADO EN EL SPEC, 2026-09-20.** Redactadas **31 reglas** en §7.1.1–§7.1.7, §12, §14.3
144 │ y §16.6: `C-POT-01`…`C-POT-08`, `C-FLU-01`…`C-FLU-18`, `C-FLU-20`…`C-FLU-22`, `C-FIN-01` y
145 │ `C-NET-33`. Familias nuevas: `C-POT`, `C-FLU`, `C-FIN`. `C-FLU-19` **no existe** y no se reutiliza.
146 │ Reglas existentes modificadas: `C-HASH-06`, `C-HDR-05`, `C-HDR-06`, `C-HDR-07`, `C-GD-04`,
147 │ `C-GD-10`, `C-REORG-07`, `C-NET-31`, `C-NET-32`.
148 │ 
149 │ Procedencia: `veritas/consenso/pot-primitiva-v1/` y `veritas/consenso/regla-flujo-v1/` (propuestas
150 │ validadas), sobre `veritas/consenso/ancla-inyeccion-v2/` y `veritas/consenso/puerta-cobertura-v1/`
151 │ (instrumentos validados). El hilo completo de decisiones, en `P-ZRX/P-2.1/SINTESIS.md`.
152 │ 
153 │ **Lo que queda, y es mucho:**
154 │ 
155 │ - **El código: ninguna de las 31 reglas tiene una línea.** Las 31 están en
156 │   `ci/reglas-sin-codigo.txt`.
157 │ - **Dos reglas existentes cambiaron de semántica y su código quedó por detrás del SPEC:**
158 │   `C-HDR-05` (la cota de slot alcanza ahora a todos los padres; el código solo mira `sp`) y
159 │   `C-HDR-07` (el `pot_output` es la salida futura y el último checkpoint la ancla; el verificador
160 │   devuelve `IntegracionPotPendiente`). Declaradas en `ci/reglas-sin-cablear.txt`, con el precedente
161 │   de C-NET-07.
162 │ - **El verificador PoT sigue sin existir**, y ahora tiene contrato que cumplir (`C-POT-06`).
163 │ - **Las mediciones que faltan: §2.9.**
164 │ 
165 │ ---
166 │ 
167 │ **El registro de cómo se llegó aquí se conserva íntegro a partir de esta línea.**
168 │ 
169 │ Solución de espacio, testigos KZG, identidad de billete, reto, distancia de solución, sello y
170 │ justificación PoT. Pendiente además: formato y validación conjunta, retardo de autoría, puntos de
171 │ control, inyección de entropía y **dependencias por flujo**.
172 │ 
173 │ **Esa última línea dejó de ser un pendiente más el 2026-09-18.** `veritas/seguridad/coste-rama-privada-v1/`
174 │ (CRP-v0.1) midió el coste de construir una rama privada con más `blue_work` y encontró que:
175 │ 
176 │ - **El diseño base aguanta.** `α_mínimo = 1/2`, **el mismo umbral que PoW y que GHOSTDAG sobre
177 │   PoW**, en los dos regímenes (reorg corta y *long-range*). El DAG aporta **menos varianza**, no
178 │   menos umbral.
179 │ - **El rango endógeno NO es explotable en media.** La tasa de soluciones válidas es `∝ SR` y el peso
180 │   es `w(B) = ⌊2^128/(SR+1)⌋ ∝ 1/SR`: **el producto se cancela**. Era la sospecha principal con la
181 │   que se escribió el encargo y queda descartada por identidad, no por estadística. Lo que sí queda
182 │   es un riesgo de **varianza** (fijar `sr` bajo compra cola con el mismo trabajo medio), del que
183 │   sale una propiedad MUST para R-FIN-13′.
184 │ - **El único vector medido que baja el umbral es el multistream de PoT** — **y `C-FLU-14` lo
185 │   cierra**, porque los flujos del atacante no se pueden agregar a una sola cadena. La tabla se
186 │   conserva como registro de qué se midió y bajo qué hipótesis, **no como el umbral del diseño**.
187 │   Cuota efectiva `S·α/(1−α+S·α)` ⟹ `α_mínimo = 1/(S+1)`:
188 │ 
189 │   | `S` | 2 | 4 | 8 | 16 | 24 |
190 │   |---|---:|---:|---:|---:|---:|
191 │   | `α_mínimo` | 0,333 | 0,200 | 0,111 | 0,059 | **0,040** |
192 │ 
193 │   `S ≈ 24` es el techo de IOPS de un SSD de 100 k. **Coste: `S` núcleos e IOPS, cero espacio
194 │   adicional.**
195 │ 
196 │ **No es un hallazgo nuevo: es el ATAQUE 2** de `research/dag-poas-auditoria.md` (2026-09-06),
197 │ calificado allí de **gravedad crítica** y con el estado «SOSPECHA fuerte — depende de una regla
198 │ (validez del PoT en DAG) que la propuesta no escribe». Lo que CRP-v0.1 añade es el **número** y el
199 │ haber comprobado que es el **único** vector medido que mueve el umbral.
200 │ 
201 │ ⚠️ **La auditoría avisaba de que las dos salidas obvias fallan:** si la validez del PoT es
202 │ **relativa a la cadena seleccionada**, se abre el multistream; si es **absoluta**, se abre el split
203 │ de cadena (ATAQUE 1). **DECIDIDO por Katana el 2026-09-19/20: validez absoluta, perfil 1a.** El
204 │ split no se cierra con una regla: se **previene** con `L_slots` frente a `Δ` y, si nace, se cura
205 │ **solo** en el caso espontáneo (`C-FLU-22`). Ver §2.9.
206 │ 
207 │ **Lo que Claude acotó al validar** (`PROCEDENCIA.md` §3.2 del instrumento): el efecto de «rojos
208 │ asimétricos» —que el adversario sufra menos rojos que la honesta— queda **no medido** por el
209 │ instrumento, pero con la Δ medida (0,26–0,60 s, 25× por debajo del primer escalón de la ronda 11a)
210 │ la fracción roja honesta es 0,0000 y **el umbral no se mueve**.
211 │ 
212 │ **La parte de red ya está decidida** (Q4 de §3.1, 2026-09-13):
213 │ - antes de reenviar se comprueban cabecera, prueba de espacio, 2 KZG, sello, justificación PoT
214 │   (desde la caché) y compromiso Merkle;
215 │ - después, firmas, pruebas Halo2 y UTXO;
216 │ - el PoT se verifica una vez por slot y se cachea.
217 │ 
218 │ Eso fija el orden, no la verificación conjunta en sí, que sigue pendiente. Las reglas que faltan
219 │ por escribir están en §2.7.
220 │ 
221 │ **El verificador PoT no existe todavía.** `prototipos/pot-estable` tiene el PoT AES de Autonomys en
222 │ Rust con vectores diferenciales, pero no está integrado, y
223 │ `zx-core::wire_dag::verificar_justificacion_pot` devuelve `IntegracionPotPendiente` de forma
224 │ explícita en vez de un booleano provisional. Hasta que exista, C-HDR-07 está en
225 │ `ci/reglas-sin-cablear.txt` y nadie exige la justificación.
226 │ 
````

## B.2 · Punto 15 de `§2.9 (e)` (CRP-v0.2 y CRP-v0.3)

Cabecera del apartado y punto 15, líneas 550–558 de `/home/katana/zeo/ZEROX/TAREAS.md`:

````
550 │ **(e) Evidencia sin validar que afecta a lo anterior**
551 │ 
552 │ 15. **CRP-v0.2 y CRP-v0.3 existen en `deepseek/` y NO están validadas ni migradas.** CRP-v0.2
553 │     declara en su propia cabecera que **«sustituye la evidencia protocolaria de CRP-v0.1»**
554 │     (baseline idealizado útil; **veredicto protocolario inconcluso**), y CRP-v0.3 se deriva de
555 │     CRP-v0.2, «que **no** se cierra». **§2.1 y `SPEC.md` §17 citan CRP-v0.1.** Hasta que alguien
556 │     valide v0.2/v0.3 o declare por qué no aplican, **hay una versión posterior de la evidencia
557 │     central de §2.1 sin revisar**, en una zona que `.gitignore` excluye y que se borra al cerrar
558 │     cada encargo.
````

## B.3 · Otras apariciones en `TAREAS.md` de `coste-rama-privada`, `CRP-v0`, `α`, `1/2`, `multistream`

Se copia la línea completa de cada aparición. (Las de `§2.1` y `§2.9 (e)` ya figuran arriba; se
repiten aquí para que la enumeración sea completa.)

### `coste-rama-privada` — 2 apariciones

````
133 │ > (`veritas/seguridad/coste-rama-privada-v1/`). El umbral que CRP-v0.1 midió con **un solo flujo**
````

````
173 │ **Esa última línea dejó de ser un pendiente más el 2026-09-18.** `veritas/seguridad/coste-rama-privada-v1/`
````

### `CRP-v0` — apariciones

````
131 │ > agregan a una sola cadena. **El propio instrumento ya lo etiquetaba así**: CRP-v0.1 declaró su
````

````
133 │ > (`veritas/seguridad/coste-rama-privada-v1/`). El umbral que CRP-v0.1 midió con **un solo flujo**
````

````
134 │ > es `α_mínimo = 1/2`, el mismo que PoW — **pero esa cifra no está cerrada: CRP-v0.2 declara
````

````
135 │ > «sustituye la evidencia protocolaria de CRP-v0.1» (baseline idealizado útil; veredicto
````

````
174 │ (CRP-v0.1) midió el coste de construir una rama privada con más `blue_work` y encontró que:
````

````
198 │ (validez del PoT en DAG) que la propuesta no escribe». Lo que CRP-v0.1 añade es el **número** y el
````

````
471 │    **umbral** está medido (`α_mínimo = 1/2`, CRP-v0.1); **la cola a `L = F_slots`, no**. Y lo que
````

````
552 │ 15. **CRP-v0.2 y CRP-v0.3 existen en `deepseek/` y NO están validadas ni migradas.** CRP-v0.2
````

````
553 │     declara en su propia cabecera que **«sustituye la evidencia protocolaria de CRP-v0.1»**
````

````
554 │     (baseline idealizado útil; **veredicto protocolario inconcluso**), y CRP-v0.3 se deriva de
````

````
555 │     CRP-v0.2, «que **no** se cierra». **§2.1 y `SPEC.md` §17 citan CRP-v0.1.** Hasta que alguien
````

````
927 │     aplica con pasado consistente de flujo** (`C-FLU-14`). CRP-v0.1 ya etiquetaba su resultado
````

### `α` — apariciones

````
134 │ > es `α_mínimo = 1/2`, el mismo que PoW — **pero esa cifra no está cerrada: CRP-v0.2 declara
````

````
176 │ - **El diseño base aguanta.** `α_mínimo = 1/2`, **el mismo umbral que PoW y que GHOSTDAG sobre
````

````
187 │   Cuota efectiva `S·α/(1−α+S·α)` ⟹ `α_mínimo = 1/(S+1)`:
````

````
191 │   | `α_mínimo` | 0,333 | 0,200 | 0,111 | 0,059 | **0,040** |
````

````
471 │    **umbral** está medido (`α_mínimo = 1/2`, CRP-v0.1); **la cola a `L = F_slots`, no**. Y lo que
````

````
905 │      umbral (`α = 0,040` con `S = 24`). La poda resultó ser un problema de **coste de arranque**,
````

### `1/2` — 3 apariciones

````
134 │ > es `α_mínimo = 1/2`, el mismo que PoW — **pero esa cifra no está cerrada: CRP-v0.2 declara
````

````
176 │ - **El diseño base aguanta.** `α_mínimo = 1/2`, **el mismo umbral que PoW y que GHOSTDAG sobre
````

````
471 │    **umbral** está medido (`α_mínimo = 1/2`, CRP-v0.1); **la cola a `L = F_slots`, no**. Y lo que
````

### `multistream` — 3 apariciones

````
139 │ > **Lo que el multistream sí obligaba a decidir era la bifurcación**, y Katana la decidió: validez
````

````
184 │ - **El único vector medido que baja el umbral es el multistream de PoT** — **y `C-FLU-14` lo
````

````
202 │ **relativa a la cadena seleccionada**, se abre el multistream; si es **absoluta**, se abre el split
````

---

# PARTE C — Matrices de los instrumentos rescatados

## C.1 · `coste-rama-privada-v2/MATRIZ-AUTORIDAD.md` — tabla completa

Fichero: `/home/katana/zeo/ZEROX/P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/MATRIZ-AUTORIDAD.md`
(69 líneas; se copian las 69).

````
1 │ # CRP-v0.2 · Matriz de autoridad
2 │ 
3 │ Estados usados: `SPEC vigente`, `candidata`, `oráculo abstracto`, `implementada sin cablear`,
4 │ `integrada`, `pendiente`, `excluida`.
5 │ Validez de traza (trivaluada): `Válida`, `Inválida`, `Pendiente`. Una decisión ausente **nunca**
6 │ se resuelve localmente para obtener `Válida`.
7 │ 
8 │ ## A · Selección y orden (GHOSTDAG)
9 │ 
10 │ | Regla | Fuente | Estado normativo | Integración | Depende de pendiente | Conclusión permitida |
11 │ |---|---|---|---|---|---|
12 │ | C-GD-01 peso `⌊2^128/(SR+1)⌋` | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs` (sin cablear), GDR-v0.2 | — | identidad aritmética |
13 │ | C-GD-02 dominio `u256` | `SPEC.md` §11 | SPEC vigente | `BW256` en GDR / `checked_add` Rust | — | cota de no desbordamiento |
14 │ | C-GD-03 padre seleccionado | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | C-GD-10 | desempate determinista |
15 │ | C-GD-04 mergeset y límites R-FIN-12 | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | validez estructural |
16 │ | C-GD-05 orden del mergeset | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | orden total |
17 │ | C-GD-06 k-cluster | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | color azul/rojo_k |
18 │ | C-GD-07 U2/U3″ | `SPEC.md` §11 / R-FIN-11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | validez / color |
19 │ | C-GD-08 acumuladores | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | `blue_work` |
20 │ | C-GD-09 color contextual | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | color no global |
21 │ | C-GD-10 padres barajados | `SPEC.md` §11 | SPEC vigente | `ci/reglas-sin-codigo.txt` | — | política de producción, no verificación |
22 │ | C-GD-11 bounded merge depth | `SPEC.md` §11 | SPEC vigente, **5 pendientes** | sin código | métrica, valor, bootstrap, borde, finalidad | validez de fusión condicionada |
23 │ | C-ORD-01 `rank` | `SPEC.md` §7.2 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | orden total |
24 │ | C-ORD-02 P1 selección de copia | `SPEC.md` §7.2 | SPEC vigente | `ghostdag.rs` (`seleccionar_copia`) | — | agrupa por billete |
25 │ | C-ORD-03 orden de aplicación | `SPEC.md` §7.2 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | orden de estado |
26 │ | C-ORD-04 conflictos | `SPEC.md` §11 | SPEC vigente | `ci/reglas-sin-codigo.txt` | UTXO/undo | descarte silencioso |
27 │ | `ghostdag.rs` | `crates/zx-consensus` | implementada sin cablear | no lo usa `zx-node` | — | instrumento Rust aislado |
28 │ | `fork_choice.rs` | `crates/zx-consensus` | ruta activa (PoW lineal) | `cadena.rs` | migración DAG | NO representa el DAG destino |
29 │ | GDR-v0.2 | `veritas/consenso/ghostdag-rank-v1/` | oráculo abstracto | este instrumento lo reutiliza | — | referencia GHOSTDAG |
30 │ 
31 │ ## B · Prueba, flujo y rango
32 │ 
33 │ | Regla | Fuente | Estado normativo | Integración | Depende de pendiente | Conclusión permitida |
34 │ |---|---|---|---|---|---|
35 │ | C-HDR-05 slot no estricto | `SPEC.md` §6.1 | SPEC vigente | GDR-v0.2 lo aplica | — | restricción estructural |
36 │ | C-HDR-06 rango contextual | `SPEC.md` §6.1 | SPEC vigente, interfaz implementada sin cablear (`bloque_dag.rs`) | no lo usa `zx-node` | ventana/arranque/redondeos (TAREAS §2.3) | controlador **Pendiente** |
37 │ | C-HDR-07 justificación PoT | `SPEC.md` §6.1 | SPEC vigente | `wire_dag` devuelve `IntegracionPotPendiente` | verificador PoT AES | bloque no declarable válido |
38 │ | R-FIN-1a slot no estricto | SPEC §6.1 (C-HDR-05) / ancla-de-orden | SPEC vigente | GDR-v0.2 lo valida | — | restricción estructural |
39 │ | R-FIN-2/3 identidad de flujo | ancla-de-orden | candidata | `DescriptorFlujo` (estructural) | `Pot`/`PotOrigin` autorizados | compatibilidad estructural |
40 │ | R-FIN-4 validez absoluta | ancla-de-orden | candidata | no | flujo + PoT real | conservar `Pendiente` |
41 │ | R-FIN-5 pasado consistente de flujo | ancla-de-orden | candidata | `rfin5.jl` (estructural) | `PotOrigin`/`N(s)` autenticados | rechazo estructural, no "PoT verificado" |
42 │ | R-FIN-11 U2/U3″ | SPEC §11 (C-GD-07) / ancla-de-orden | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | unicidad de billete |
43 │ | R-FIN-13′ retarget paga = cuenta | ancla-de-orden | candidata | no | ventana | no reutilizar tasas antiguas |
44 │ | R-FIN-14 reto por slot | ancla-de-orden | candidata | no | PoT AES, `N(s)`, `ρ_max` | reto secuencial |
45 │ | R-FIN-7 finalidad en tiempo | ancla-de-orden | candidata | sin código | `F` provisional, `Δ` sin medir | no garantía de pago |
46 │ | C-NET-31/32 PoT por slot cacheado | `SPEC.md` §2.7 | SPEC vigente, valores pendientes | `ci/reglas-sin-codigo.txt` | presupuesto CPU, caché por flujo | tensión caché global vs `(flujo,slot)` Pendiente |
47 │ | Dominio/autorización (DAV) | `veritas/consenso/dominio-autorizacion-v1/` | oráculo abstracto | no | — | permite hablar de `PotOrigin` como contrato |
48 │ | Contrato de billete CBE | `veritas/consenso/contrato-billete-v1/` | oráculo abstracto | no | — | identidad de billete supuesta |
49 │ | DAV/DA0/DCM | `veritas/consenso/identidad-disponibilidad-v1/` | oráculo abstracto | no | — | disponibilidad no implementada |
50 │ | DMS (Δ) | `veritas/finalidad/delta-medido-v1/` | oráculo abstracto | no | — | Δ sintética, no de red ZEROX |
51 │ 
52 │ ## C · Retarget y finalidad
53 │ 
54 │ | Regla | Fuente | Estado normativo | Integración | Depende de pendiente | Conclusión permitida |
55 │ |---|---|---|---|---|---|
56 │ | Controlador del SPEC | SPEC §7.2/§6.1 | pendiente | no | ventana, arranque, redondeos, fusiones fuera de ventana | corrida adversaria **Pendiente** |
57 │ | RCE-v0.1 rev2 (+Z0) | `retarget-causal-endogeno-v1/` | oráculo abstracto (candidato) | `controlador_rce.jl` | asociación DAG→cohorte es oráculo | SR derivado en el perfil candidato |
58 │ | ARM-v0.1 | `admision-retarget-multivista-v1/` | oráculo abstracto (candidato) | vectores en tests | contexto de cierre desde DAG | no consenso |
59 │ | `F = 2 h` | MIGRACION §Parámetros | provisional | — | medición de Δ en red DAG | no cierra finalidad |
60 │ | Poda/IBD sucinto | `veritas/consenso/poda-post-v1/` | excluida (niveles) / abierta (recursiva) | no | — | sync sucinto **no disponible** |
61 │ 
62 │ ## D · Conclusión de autoridad
63 │ 
64 │ - El **texto vigente** que este instrumento puede usar como autoridad es §6.1–§7.3 y §11 del SPEC,
65 │   con C-GD-01…09, C-ORD-01…03 y C-HDR-06/07.
66 │ - El **flujo PoT conjunto (R-FIN-5)**, el **controlador del SPEC** y partes de **C-GD-11/finalidad**
67 │   permanecen pendientes: todo veredicto global queda **inconcluso**, y las trazas que dependan de
68 │   ellos quedan `Pendiente`.
69 │ - RCE/ARM, DAV, DCM y el contrato de billete son **instrumentos/oráculos**, no consenso activado.
````

## C.2 · `coste-rama-privada-v3/MATRIZ-AUTORIDAD.md` — tabla completa

Fichero: `/home/katana/zeo/ZEROX/P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/MATRIZ-AUTORIDAD.md`
(69 líneas; se copian las 69).

````
1 │ # CRP-v0.3 · Matriz de autoridad (revisa y sustituye la de v0.2)
2 │ 
3 │ Estados usados: `SPEC vigente`, `candidata`, `oráculo abstracto`, `implementada sin cablear`,
4 │ `integrada`, `pendiente`, `excluida`.
5 │ Validez de traza (trivaluada): `Válida`, `Inválida`, `Pendiente`. Una decisión ausente **nunca**
6 │ se resuelve localmente para obtener `Válida`.
7 │ 
8 │ ## A · Selección y orden (GHOSTDAG)
9 │ 
10 │ | Regla | Fuente | Estado normativo | Integración | Depende de pendiente | Conclusión permitida |
11 │ |---|---|---|---|---|---|
12 │ | C-GD-01 peso `⌊2^128/(SR+1)⌋` | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs` (sin cablear), GDR-v0.2 | — | identidad aritmética |
13 │ | C-GD-02 dominio `u256` | `SPEC.md` §11 | SPEC vigente | `BW256` en GDR / `checked_add` Rust | — | cota de no desbordamiento |
14 │ | C-GD-03 padre seleccionado | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | C-GD-10 | desempate determinista |
15 │ | C-GD-04 mergeset y límites R-FIN-12 | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | validez estructural |
16 │ | C-GD-05 orden del mergeset | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | orden total |
17 │ | C-GD-06 k-cluster | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | color azul/rojo_k |
18 │ | C-GD-07 U2/U3″ | `SPEC.md` §11 / R-FIN-11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | validez / color |
19 │ | C-GD-08 acumuladores | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | `blue_work` |
20 │ | C-GD-09 color contextual | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | color no global |
21 │ | C-GD-10 padres barajados | `SPEC.md` §11 | SPEC vigente | `ci/reglas-sin-codigo.txt` | — | política de producción, no verificación |
22 │ | C-GD-11 bounded merge depth | `SPEC.md` §11 | SPEC vigente, **5 pendientes** | sin código | métrica, valor, bootstrap, borde, finalidad | validez de fusión condicionada |
23 │ | C-ORD-01 `rank` | `SPEC.md` §7.2 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | orden total |
24 │ | C-ORD-02 P1 selección de copia | `SPEC.md` §7.2 | SPEC vigente | `ghostdag.rs` (`seleccionar_copia`) | — | agrupa por billete |
25 │ | C-ORD-03 orden de aplicación | `SPEC.md` §7.2 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | orden de estado |
26 │ | C-ORD-04 conflictos | `SPEC.md` §11 | SPEC vigente | `ci/reglas-sin-codigo.txt` | UTXO/undo | descarte silencioso |
27 │ | `ghostdag.rs` | `crates/zx-consensus` | implementada sin cablear | no lo usa `zx-node` | — | instrumento Rust aislado |
28 │ | `fork_choice.rs` | `crates/zx-consensus` | ruta activa (PoW lineal) | `cadena.rs` | migración DAG | NO representa el DAG destino |
29 │ | GDR-v0.2 | `veritas/consenso/ghostdag-rank-v1/` | oráculo abstracto | este instrumento lo reutiliza | — | referencia GHOSTDAG |
30 │ 
31 │ ## B · Prueba, flujo y rango
32 │ 
33 │ | Regla | Fuente | Estado normativo | Integración | Depende de pendiente | Conclusión permitida |
34 │ |---|---|---|---|---|---|
35 │ | C-HDR-05 slot no estricto | `SPEC.md` §6.1 | SPEC vigente | GDR-v0.2 lo aplica | — | restricción estructural |
36 │ | C-HDR-06 rango contextual | `SPEC.md` §6.1 | SPEC vigente, interfaz implementada sin cablear (`bloque_dag.rs`) | no lo usa `zx-node` | ventana/arranque/redondeos (TAREAS §2.3) | controlador **Pendiente** |
37 │ | C-HDR-07 justificación PoT | `SPEC.md` §6.1 | SPEC vigente | `wire_dag` devuelve `IntegracionPotPendiente` | verificador PoT AES | bloque no declarable válido |
38 │ | R-FIN-1a slot no estricto | SPEC §6.1 (C-HDR-05) / ancla-de-orden | SPEC vigente | GDR-v0.2 lo valida | — | restricción estructural |
39 │ | R-FIN-2/3 identidad de flujo | ancla-de-orden | candidata | `DescriptorFlujo` (estructural) | `Pot`/`PotOrigin` autorizados | compatibilidad estructural |
40 │ | R-FIN-4 validez absoluta | ancla-de-orden | candidata | no | flujo + PoT real | conservar `Pendiente` |
41 │ | R-FIN-5 pasado consistente de flujo | ancla-de-orden | candidata | `rfin5.jl` (estructural) | `PotOrigin`/`N(s)` autenticados | rechazo estructural, no "PoT verificado" |
42 │ | R-FIN-11 U2/U3″ | SPEC §11 (C-GD-07) / ancla-de-orden | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | unicidad de billete |
43 │ | R-FIN-13′ retarget paga = cuenta | SPEC §7.2 / ancla-de-orden | SPEC vigente (acoplamiento); detalle de ventana candidato | no | ventana | no reutilizar tasas antiguas |
44 │ | R-FIN-14 reto por slot | ancla-de-orden | candidata | no | PoT AES, `N(s)`, `ρ_max` | reto secuencial |
45 │ | R-FIN-7 finalidad en tiempo | ancla-de-orden | candidata | sin código | `F` provisional, `Δ` sin medir | no garantía de pago |
46 │ | C-NET-31/32 PoT por slot cacheado | `SPEC.md` §16 (C-NET-31/32) | SPEC vigente, valores pendientes | `ci/reglas-sin-codigo.txt` | presupuesto CPU, caché por flujo | tensión caché global vs `(flujo,slot)` Pendiente |
47 │ | Dominio/autorización (DAV) | `veritas/consenso/dominio-autorizacion-v1/` | oráculo abstracto | no | — | permite hablar de `PotOrigin` como contrato |
48 │ | Contrato de billete CBE | `veritas/consenso/contrato-billete-v1/` | oráculo abstracto | no | — | identidad de billete supuesta |
49 │ | DAV/DA0/DCM | `veritas/consenso/identidad-disponibilidad-v1/` | oráculo abstracto | no | — | disponibilidad no implementada |
50 │ | DMS (Δ) | `veritas/finalidad/delta-medido-v1/` | oráculo abstracto | no | — | Δ sintética, no de red ZEROX |
51 │ 
52 │ ## C · Retarget y finalidad
53 │ 
54 │ | Regla | Fuente | Estado normativo | Integración | Depende de pendiente | Conclusión permitida |
55 │ |---|---|---|---|---|---|
56 │ | Controlador del SPEC | SPEC §7.2/§6.1 | pendiente | no | ventana, arranque, redondeos, fusiones fuera de ventana | corrida adversaria **Pendiente** |
57 │ | RCE-v0.1 rev2 (+Z0) | `retarget-causal-endogeno-v1/` | oráculo abstracto (candidato) | `controlador_rce.jl` | asociación DAG→cohorte es oráculo | SR derivado en el perfil candidato |
58 │ | ARM-v0.1 | `admision-retarget-multivista-v1/` | oráculo abstracto (candidato) | vectores en tests | contexto de cierre desde DAG | no consenso |
59 │ | `F = 2 h` | MIGRACION §Parámetros | provisional | — | medición de Δ en red DAG | no cierra finalidad |
60 │ | Poda/IBD sucinto | `veritas/consenso/poda-post-v1/` | excluida (niveles) / abierta (recursiva) | no | — | sync sucinto **no disponible** |
61 │ 
62 │ ## D · Conclusión de autoridad
63 │ 
64 │ - El **texto vigente** que este instrumento puede usar como autoridad es §6.1–§7.3 y §11 del SPEC,
65 │   con C-GD-01…09, C-ORD-01…03 y C-HDR-06/07.
66 │ - El **flujo PoT conjunto (R-FIN-5)**, el **controlador del SPEC** y partes de **C-GD-11/finalidad**
67 │   permanecen pendientes: todo veredicto global queda **inconcluso**, y las trazas que dependan de
68 │   ellos quedan `Pendiente`.
69 │ - RCE/ARM, DAV, DCM y el contrato de billete son **instrumentos/oráculos**, no consenso activado.
````

## C.3 · `coste-rama-privada-v2/MATRIZ-VALIDEZ.md` — tabla completa

Fichero: `/home/katana/zeo/ZEROX/P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v2/MATRIZ-VALIDEZ.md`
(31 líneas; se copian las 31).

````
1 │ # CRP-v0.2 · Matriz de validez por escenario
2 │ 
3 │ Cada traza se clasifica `Válida`, `Inválida`, `Pendiente` o `Contrafactual`. Una regla ausente
4 │ **nunca** se resuelve localmente para obtener `Válida`.
5 │ 
6 │ | # | Escenario | Reglas aplicadas | Observador | Clasificación | Por qué |
7 │ |---|---|---|---|---|---|
8 │ | 1 | Baseline analítico ±1 (flujo compatible, sin rojos) | aritmética + carrera | — | **Válida (demostrado/derivado)** | forma cerrada y DP exacta coinciden |
9 │ | 2 | SPEC actualmente escrito | C-HDR-06 `Pendiente`; flujo no cerrado | veterano/nuevo | **Pendiente** | primer dato ausente: ventana del controlador |
10 │ | 3 | DAG con red (GDR-v0.2 + vistas locales) | C-GD-01…09, C-ORD-01…03 | veterano | **Válida (medido condicionado)** | rojos y anticonos reales; sin C-GD-11 |
11 │ | 4 | Escenario candidato R-FIN-5 | R-FIN-5 estructural + GDR | veterano | **Válida estructural / Pendiente cripto** | `PotOrigin`/`N(s)` no autenticados por fuente |
12 │ | 5 | Contrafactual aditivo sin filtro de flujo | suma de ramas | — | **Contrafactual (no regla adoptada)** | cuantifica peligro `S·α`, no representa GHOSTDAG |
13 │ | 6 | Regímenes corto y largo | reloj/ventana explícitos | veterano/nuevo | **Corto Válido; largo Pendiente** | falta finalidad/`F`/`Δ` |
14 │ | 7 | RCE/ARM como controlador | contrato RCE rev2 + fixture | — | **Válida como instrumento / Pendiente como consenso** | asociación DAG→cohorte es oráculo |
15 │ | 8 | Sync sucinto | — | nuevo desde génesis | **Pendiente** | no existe en el SPEC |
16 │ 
17 │ ## Trazas concretas
18 │ 
19 │ | Traza | Resultado | Estado |
20 │ |---|---|---|
21 │ | Empate vs superación estricta (`d`, `T`) | `(q/p)^d` vs `(q/p)^(d+1)` | demostrado |
22 │ | Lattice `g`: `d` trabajo ≡ `d·g` retícula | misma probabilidad | demostrado (test) |
23 │ | Vector ARM `W=10,N=5` | rango 100→200 en slot 20 | derivado del contrato |
24 │ | Ventana vacía Z0 | no agenda; rango 200 en 40 | derivado del contrato |
25 │ | Fixture `rojo_k` conocido | `k+3` hermanos ⇒ al menos un rojo | medido (GDR) |
26 │ | Fixture cero rojos | `min(k+1,15)` hermanos ⇒ 0 rojos | medido (GDR) |
27 │ | Concurrencia calibrada `k=2` | fracción de réplicas con rojo = 1.0; IC (0.912,1.0) | medido |
28 │ | Control `k=30` | 0 rojos; IC sup 0.088 (límite unilateral) | medido |
29 │ | Control escalar `S` | `α_drift=1/(S+1)`, `g=0` | demostrado |
30 │ | Prefijo R-FIN-5 en `slot(X)` | divergencia futura no invalida pasado | demostrado (test) |
31 │ | Descriptor sin autenticar | `Pendiente`, nunca `true` | demostrado (test) |
````

## C.4 · `coste-rama-privada-v3/MATRIZ-VALIDEZ.md` — tabla completa

Fichero: `/home/katana/zeo/ZEROX/P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/MATRIZ-VALIDEZ.md`
(31 líneas; se copian las 31).

````
1 │ # CRP-v0.3 · Matriz de validez
2 │ 
3 │ | # | Escenario | Reglas | Observador | Clasificación |
4 │ |---|---|---|---|---|
5 │ | 1 | Baseline ±1 (terminal/paso/eventual) | aritmética + DP | — | **demostrado** |
6 │ | 2 | SPEC actualmente escrito | C-HDR-06 pendiente | veterano/nuevo | **Pendiente** (ventana) |
7 │ | 3 | DAG con red (GDR-v0.2, R-FIN-5 estructural) | C-GD-01…09, C-ORD-01…03, R-FIN-5; **C-GD-11 ausente** | nuevo | **Pendiente por C-GD-11 y PoT no criptográfico** (la estructura de color es válida, la validez de fusión no está cerrada) |
8 │ | 4 | Escenario candidato R-FIN-5 (máximo de ramas) | R-FIN-5 | nuevo/veterano | **Válida estructural** |
9 │ | 5 | Contrafactual aditivo | suma | — | **Contrafactual, no regla** |
10 │ | 6 | Observador veterano | R-FIN-7/`F` | veterano | **Pendiente** (`F` provisional) |
11 │ | 7 | Observador eclipsado | — | eclipsado | **Pendiente** |
12 │ | 8 | Sync sucinto | — | nuevo | **Pendiente** |
13 │ | 9 | RCE/ARM | contrato RCE rev2 | — | **instrumento / Pendiente consenso** |
14 │ 
15 │ ## Trazas
16 │ 
17 │ | Traza | Resultado | Estado |
18 │ |---|---|---|
19 │ | `P_terminal ≤ P_paso ≤ P_eventual` | orden verificado | demostrado (test) |
20 │ | `α_prob` por evento (d=4,T=100) | terminal 0.443; paso 0.355; eventual 0.355 | derivado |
21 │ | Celda 0/n en `α_prob` | `:solo_cota_superior` | demostrado (test) |
22 │ | R-FIN-5 prefijo en `slot(X)` | compatible ≤ fork, incompatible > | demostrado |
23 │ | Fusión público+rama divergente | `:rechazada_rfin5` | medido |
24 │ | Único productor, Δ∈{0,1,5} | 0 rojos | medido (test) |
25 │ | Δ=0, 8 productores, k=2 | rojos > 0 | medido |
26 │ | Correlación perfecta S=4 | ramas idénticas | medido |
27 │ | iid S=3 | identidad `1−E[F^S]` vs MC | medido (test) |
28 │ | Aditivo S=4 | cruce entre α=0.15 y 0.20 (≈1/5) | medido |
29 │ | η_h, η_a | η_h≈0.99, η_a=1.0; **0 rojos** | curva con rojos **inconclusa** |
30 │ | U2 misma rama | `:u2` | medido (test) |
31 │ | U3″ ramas disjuntas | una `rojo_U3` | medido (test) |
````

## C.5 · Celdas donde aparecen las palabras exactas pedidas

Localización celda a celda. En las matrices de autoridad las columnas son, en este orden:
**1 Regla · 2 Fuente · 3 Estado normativo · 4 Integración · 5 Depende de pendiente ·
6 Conclusión permitida**. En `MATRIZ-VALIDEZ` v2 las columnas del bloque de escenarios son
**1 # · 2 Escenario · 3 Reglas aplicadas · 4 Observador · 5 Clasificación · 6 Por qué**; las del
bloque «Trazas concretas» son **1 Traza · 2 Resultado · 3 Estado**. En `MATRIZ-VALIDEZ` v3 las
columnas de escenarios son **1 # · 2 Escenario · 3 Reglas · 4 Observador · 5 Clasificación**, y
las de «Trazas» **1 Traza · 2 Resultado · 3 Estado**.

### C.5.1 · `coste-rama-privada-v2/MATRIZ-AUTORIDAD.md`

| Palabra exacta | Línea | Fila | Columna | Celda (texto literal) |
|---|---|---|---|---|
| `candidata` | 3 | (preamble «Estados usados», no es tabla) | — | `candidata` declarada como estado |
| `candidata` | 39 | R-FIN-2/3 identidad de flujo | 3 Estado normativo | `candidata` |
| `candidata` | 40 | R-FIN-4 validez absoluta | 3 Estado normativo | `candidata` |
| `candidata` | 41 | R-FIN-5 pasado consistente de flujo | 3 Estado normativo | `candidata` |
| `candidata` | 43 | R-FIN-13′ retarget paga = cuenta | 3 Estado normativo | `candidata` |
| `candidata` | 44 | R-FIN-14 reto por slot | 3 Estado normativo | `candidata` |
| `candidata` | 45 | R-FIN-7 finalidad en tiempo | 3 Estado normativo | `candidata` |
| `pendiente` | 4 | (preamble «Estados usados», no es tabla) | — | `pendiente` declarada como estado |
| `pendiente` | 10, 33, 54 | (filas de cabecera de tabla A/B/C) | 5 | encabezado `Depende de pendiente` |
| `pendiente` | 22 | C-GD-11 bounded merge depth | 3 Estado normativo | `SPEC vigente, **5 pendientes**` (subcadena dentro de `pendientes`) |
| `pendiente` | 46 | C-NET-31/32 PoT por slot cacheado | 3 Estado normativo | `SPEC vigente, valores pendientes` (subcadena dentro de `pendientes`) |
| `pendiente` | 56 | Controlador del SPEC | 3 Estado normativo | `pendiente` (palabra completa) |
| `pendiente` | 67 | (sección D, texto de viñeta, no es tabla) | — | `permanecen pendientes` (subcadena dentro de `pendientes`) |
| `SPEC vigente` | 3 | (preamble «Estados usados», no es tabla) | — | `SPEC vigente` declarada como estado |
| `SPEC vigente` | 12–26 | C-GD-01…C-ORD-04 (15 filas) | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 22 | C-GD-11 bounded merge depth | 3 Estado normativo | `SPEC vigente, **5 pendientes**` |
| `SPEC vigente` | 35 | C-HDR-05 slot no estricto | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 36 | C-HDR-06 rango contextual | 3 Estado normativo | `SPEC vigente, interfaz implementada sin cablear (`bloque_dag.rs`)` |
| `SPEC vigente` | 37 | C-HDR-07 justificación PoT | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 38 | R-FIN-1a slot no estricto | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 42 | R-FIN-11 U2/U3″ | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 46 | C-NET-31/32 PoT por slot cacheado | 3 Estado normativo | `SPEC vigente, valores pendientes` |
| `oráculo abstracto` | 3 | (preamble «Estados usados», no es tabla) | — | `oráculo abstracto` declarado como estado |
| `oráculo abstracto` | 29 | GDR-v0.2 | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 47 | Dominio/autorización (DAV) | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 48 | Contrato de billete CBE | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 49 | DAV/DA0/DCM | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 50 | DMS (Δ) | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 57 | RCE-v0.1 rev2 (+Z0) | 3 Estado normativo | `oráculo abstracto (candidato)` |
| `oráculo abstracto` | 58 | ARM-v0.1 | 3 Estado normativo | `oráculo abstracto (candidato)` |
| `implementada sin cablear` | 3 | (preamble «Estados usados», no es tabla) | — | `implementada sin cablear` declarada como estado |
| `implementada sin cablear` | 27 | `ghostdag.rs` | 3 Estado normativo | `implementada sin cablear` |
| `implementada sin cablear` | 36 | C-HDR-06 rango contextual | 3 Estado normativo | `SPEC vigente, interfaz implementada sin cablear (`bloque_dag.rs`)` |
| `integrada` | 4 | (preamble «Estados usados», no es tabla) | — | `integrada` declarada como estado; ninguna celda de tabla la usa como valor |
| `excluida` | 4 | (preamble «Estados usados», no es tabla) | — | `excluida` declarada como estado |
| `excluida` | 60 | Poda/IBD sucinto | 3 Estado normativo | `excluida (niveles) / abierta (recursiva)` |
| `Válida` | 5, 6 | (preamble, no es tabla) | — | `Válida` dentro de la enumeración trivaluada; ninguna celda de tabla |
| `Inválida` | 5 | (preamble, no es tabla) | — | `Inválida` dentro de la enumeración trivaluada; ninguna celda de tabla |
| `Pendiente` | 5 | (preamble, no es tabla) | — | `Pendiente` dentro de la enumeración trivaluada |
| `Pendiente` | 36 | C-HDR-06 rango contextual | 6 Conclusión permitida | `controlador **Pendiente**` |
| `Pendiente` | 37 | C-HDR-07 justificación PoT | 4 Integración | `wire_dag` devuelve `IntegracionPotPendiente` (subcadena dentro de `IntegracionPotPendiente`) |
| `Pendiente` | 40 | R-FIN-4 validez absoluta | 6 Conclusión permitida | ``conservar `Pendiente` `` |
| `Pendiente` | 46 | C-NET-31/32 PoT por slot cacheado | 6 Conclusión permitida | ``tensión caché global vs `(flujo,slot)` Pendiente`` |
| `Pendiente` | 56 | Controlador del SPEC | 6 Conclusión permitida | `corrida adversaria **Pendiente**` |
| `Pendiente` | 68 | (sección D, texto de viñeta, no es tabla) | — | ``ellos quedan `Pendiente` `` |

### C.5.2 · `coste-rama-privada-v3/MATRIZ-AUTORIDAD.md`

Idéntica a C.5.1 salvo las diferencias de línea/celda que se indican (el texto de la mayoría de
celdas es el mismo; no se repiten filas idénticas celda a celda salvo en lo que cambia):

| Palabra exacta | Línea | Fila | Columna | Celda (texto literal) |
|---|---|---|---|---|
| `candidata` | 3 | (preamble «Estados usados», no es tabla) | — | `candidata` declarada como estado |
| `candidata` | 39 | R-FIN-2/3 identidad de flujo | 3 Estado normativo | `candidata` |
| `candidata` | 40 | R-FIN-4 validez absoluta | 3 Estado normativo | `candidata` |
| `candidata` | 41 | R-FIN-5 pasado consistente de flujo | 3 Estado normativo | `candidata` |
| `candidata` | 44 | R-FIN-14 reto por slot | 3 Estado normativo | `candidata` |
| `candidata` | 45 | R-FIN-7 finalidad en tiempo | 3 Estado normativo | `candidata` |
| `pendiente` | 4 | (preamble «Estados usados», no es tabla) | — | `pendiente` declarada como estado |
| `pendiente` | 10, 33, 54 | (filas de cabecera de tabla A/B/C) | 5 | encabezado `Depende de pendiente` |
| `pendiente` | 22 | C-GD-11 bounded merge depth | 3 Estado normativo | `SPEC vigente, **5 pendientes**` (subcadena dentro de `pendientes`) |
| `pendiente` | 46 | C-NET-31/32 PoT por slot cacheado | 3 Estado normativo | `SPEC vigente, valores pendientes` (subcadena dentro de `pendientes`) |
| `pendiente` | 56 | Controlador del SPEC | 3 Estado normativo | `pendiente` (palabra completa) |
| `pendiente` | 67 | (sección D, texto de viñeta, no es tabla) | — | `permanecen pendientes` (subcadena dentro de `pendientes`) |
| `SPEC vigente` | 3 | (preamble «Estados usados», no es tabla) | — | `SPEC vigente` declarada como estado |
| `SPEC vigente` | 12–26 | C-GD-01…C-ORD-04 (15 filas) | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 22 | C-GD-11 bounded merge depth | 3 Estado normativo | `SPEC vigente, **5 pendientes**` |
| `SPEC vigente` | 35 | C-HDR-05 slot no estricto | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 36 | C-HDR-06 rango contextual | 3 Estado normativo | `SPEC vigente, interfaz implementada sin cablear (`bloque_dag.rs`)` |
| `SPEC vigente` | 37 | C-HDR-07 justificación PoT | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 38 | R-FIN-1a slot no estricto | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 42 | R-FIN-11 U2/U3″ | 3 Estado normativo | `SPEC vigente` |
| `SPEC vigente` | 43 | R-FIN-13′ retarget paga = cuenta | 3 Estado normativo | `SPEC vigente (acoplamiento); detalle de ventana candidato` |
| `SPEC vigente` | 46 | C-NET-31/32 PoT por slot cacheado | 3 Estado normativo | `SPEC vigente, valores pendientes` |
| `oráculo abstracto` | 3 | (preamble «Estados usados», no es tabla) | — | `oráculo abstracto` declarado como estado |
| `oráculo abstracto` | 29 | GDR-v0.2 | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 47 | Dominio/autorización (DAV) | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 48 | Contrato de billete CBE | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 49 | DAV/DA0/DCM | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 50 | DMS (Δ) | 3 Estado normativo | `oráculo abstracto` |
| `oráculo abstracto` | 57 | RCE-v0.1 rev2 (+Z0) | 3 Estado normativo | `oráculo abstracto (candidato)` |
| `oráculo abstracto` | 58 | ARM-v0.1 | 3 Estado normativo | `oráculo abstracto (candidato)` |
| `implementada sin cablear` | 3 | (preamble «Estados usados», no es tabla) | — | `implementada sin cablear` declarada como estado |
| `implementada sin cablear` | 27 | `ghostdag.rs` | 3 Estado normativo | `implementada sin cablear` |
| `implementada sin cablear` | 36 | C-HDR-06 rango contextual | 3 Estado normativo | `SPEC vigente, interfaz implementada sin cablear (`bloque_dag.rs`)` |
| `integrada` | 4 | (preamble «Estados usados», no es tabla) | — | `integrada` declarada como estado; ninguna celda de tabla la usa como valor |
| `excluida` | 4 | (preamble «Estados usados», no es tabla) | — | `excluida` declarada como estado |
| `excluida` | 60 | Poda/IBD sucinto | 3 Estado normativo | `excluida (niveles) / abierta (recursiva)` |
| `Válida` | 5, 6 | (preamble, no es tabla) | — | `Válida` dentro de la enumeración trivaluada; ninguna celda de tabla |
| `Inválida` | 5 | (preamble, no es tabla) | — | `Inválida` dentro de la enumeración trivaluada; ninguna celda de tabla |
| `Pendiente` | 5 | (preamble, no es tabla) | — | `Pendiente` dentro de la enumeración trivaluada |
| `Pendiente` | 36 | C-HDR-06 rango contextual | 6 Conclusión permitida | `controlador **Pendiente**` |
| `Pendiente` | 37 | C-HDR-07 justificación PoT | 4 Integración | `wire_dag` devuelve `IntegracionPotPendiente` (subcadena dentro de `IntegracionPotPendiente`) |
| `Pendiente` | 40 | R-FIN-4 validez absoluta | 6 Conclusión permitida | ``conservar `Pendiente` `` |
| `Pendiente` | 46 | C-NET-31/32 PoT por slot cacheado | 6 Conclusión permitida | ``tensión caché global vs `(flujo,slot)` Pendiente`` |
| `Pendiente` | 56 | Controlador del SPEC | 6 Conclusión permitida | `corrida adversaria **Pendiente**` |
| `Pendiente` | 68 | (sección D, texto de viñeta, no es tabla) | — | ``ellos quedan `Pendiente` `` |

### C.5.3 · `coste-rama-privada-v2/MATRIZ-VALIDEZ.md`

| Palabra exacta | Línea | Fila | Columna | Celda (texto literal) |
|---|---|---|---|---|
| `candidata` | — | — | — | sin apariciones |
| `pendiente` | — | — | — | sin apariciones (minúscula) |
| `SPEC vigente` | — | — | — | sin apariciones |
| `oráculo abstracto` | — | — | — | sin apariciones |
| `implementada sin cablear` | — | — | — | sin apariciones |
| `integrada` | — | — | — | sin apariciones |
| `excluida` | — | — | — | sin apariciones |
| `Válida` | 3, 4 | (preamble, no es tabla) | — | `Válida` en la enumeración de clasificaciones |
| `Válida` | 8 | 1 Baseline analítico ±1 | 5 Clasificación | `**Válida (demostrado/derivado)**` |
| `Válida` | 10 | 3 DAG con red | 5 Clasificación | `**Válida (medido condicionado)**` |
| `Válida` | 11 | 4 Escenario candidato R-FIN-5 | 5 Clasificación | `**Válida estructural / Pendiente cripto**` |
| `Válida` | 14 | 7 RCE/ARM como controlador | 5 Clasificación | `**Válida como instrumento / Pendiente como consenso**` |
| `Inválida` | 3 | (preamble, no es tabla) | — | `Inválida` en la enumeración; ninguna celda de tabla |
| `Pendiente` | 3 | (preamble, no es tabla) | — | `Pendiente` en la enumeración |
| `Pendiente` | 9 | 2 SPEC actualmente escrito | 3 Reglas aplicadas | ``C-HDR-06 `Pendiente`; flujo no cerrado`` |
| `Pendiente` | 9 | 2 SPEC actualmente escrito | 5 Clasificación | `**Pendiente**` |
| `Pendiente` | 11 | 4 Escenario candidato R-FIN-5 | 5 Clasificación | `**Válida estructural / Pendiente cripto**` |
| `Pendiente` | 13 | 6 Regímenes corto y largo | 5 Clasificación | `**Corto Válido; largo Pendiente**` |
| `Pendiente` | 14 | 7 RCE/ARM como controlador | 5 Clasificación | `**Válida como instrumento / Pendiente como consenso**` |
| `Pendiente` | 15 | 8 Sync sucinto | 5 Clasificación | `**Pendiente**` |
| `Pendiente` | 31 | Descriptor sin autenticar (tabla «Trazas concretas») | 2 Resultado | `` `Pendiente`, nunca `true` `` |

### C.5.4 · `coste-rama-privada-v3/MATRIZ-VALIDEZ.md`

| Palabra exacta | Línea | Fila | Columna | Celda (texto literal) |
|---|---|---|---|---|
| `candidata` | — | — | — | sin apariciones |
| `pendiente` | 6 | 2 SPEC actualmente escrito | 3 Reglas | `C-HDR-06 pendiente` |
| `SPEC vigente` | — | — | — | sin apariciones |
| `oráculo abstracto` | — | — | — | sin apariciones |
| `implementada sin cablear` | — | — | — | sin apariciones |
| `integrada` | — | — | — | sin apariciones |
| `excluida` | — | — | — | sin apariciones |
| `Válida` | 8 | 4 Escenario candidato R-FIN-5 (máximo de ramas) | 5 Clasificación | `**Válida estructural**` |
| `Inválida` | — | — | — | sin apariciones (tampoco en el preámbulo: la única línea de preámbulo es el título, línea 1) |
| `Pendiente` | 6 | 2 SPEC actualmente escrito | 5 Clasificación | `**Pendiente** (ventana)` |
| `Pendiente` | 7 | 3 DAG con red | 5 Clasificación | `**Pendiente por C-GD-11 y PoT no criptográfico** (la estructura de color es válida, la validez de fusión no está cerrada)` |
| `Pendiente` | 10 | 6 Observador veterano | 5 Clasificación | ``**Pendiente** (`F` provisional)`` |
| `Pendiente` | 11 | 7 Observador eclipsado | 5 Clasificación | `**Pendiente**` |
| `Pendiente` | 12 | 8 Sync sucinto | 5 Clasificación | `**Pendiente**` |
| `Pendiente` | 13 | 9 RCE/ARM | 5 Clasificación | `**instrumento / Pendiente consenso**` |

Notas de literalidad sobre `MATRIZ-VALIDEZ` v3 (para no confundir cadenas distintas con la pedida):
- La línea 7 contiene además la palabra en minúscula `válida` («la estructura de color es válida»),
  que **no** es la cadena `Válida` (capitalizada).
- En la tabla «Trazas» de v3 no aparecen `Válida` ni `Pendiente`.

---

# Cifras del documento

- Parte A: `SPEC.md` — reglas `C-POT-08` (1486–1504), `C-FLU-01` (1507–1542), `C-FLU-13` (1701–1716),
  `C-FLU-14` (1718–1731), `C-FLU-20` (1733–1750), `C-FLU-21` (1752–1766), `C-FLU-22` (1796–1850),
  `C-FIN-01` (2532–2570), sección §17 (3774–3792) y listado de cadenas.
- Parte B: `TAREAS.md` — §2.1 (124–226), §2.9 (e) punto 15 (550–558) y listado de cadenas.
- Parte C: las cuatro matrices completas (69 + 69 + 31 + 31 líneas) y el mapa de celdas.
