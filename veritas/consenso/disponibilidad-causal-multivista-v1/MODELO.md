# Modelo DCM-v0.1 — revisión 2

El oráculo conserva `Set{UInt64}` y recorre padres explícitamente. El kernel compila un mapa
BlockId opaco→índice denso y usa `BitSet` sobre esos índices, de modo que IDs dispersos no reservan
memoria proporcional a su valor. Aún comparte el catálogo `Dict`/`Vector` y las funciones de validación,
selección y cierre causal. Es una ruta de estado separada y una validación diferencial parcial,
no un oráculo independiente de esas reglas compartidas. No se afirma una representación CSR.

Estado por observador: política P0/P1 fija desde la construcción, cabeceras vistas,
cuerpos COMPLETE monotónicos, evidencia contextual por
`(HistoryId,BlockId)`, entregas rechazadas informativas,
punta pública, journal, snapshots por WindowId, conjunto Inert, pila de undo y candidato Pending.
Las entregas son locales; el catálogo DAG/HistorySpec y la política son comunes y fijos para la
comparación. La proyección de equivalencia incluye la política; undo nunca la sustituye.
Una invocación con otra política devuelve PolicyMismatch sin mutar ningún estado de la vista.
La verdad contextual es un mapa explícito en ambos lenguajes: una pareja ausente no autoriza
registrar VALID. Rank/color se suministran globalmente y no modelan su variación por historia.

La pila inicial usa copias completas de `PublicState`; es deliberadamente simple para auditar y
Θ(H²) en una cadena creciente. El benchmark debe incluir profundidad y reorg. No se denomina
kernel optimizado ni se extrapola a un nodo.

Rust guarda deltas de undo y hace una copia privada de la vista al reproducir. Su detector de
ciclos es iterativo; los mapas ordenados añaden coste logarítmico por acceso, sin consumir pila
proporcional a la profundidad. El oráculo independiente de regresión usa alcanzabilidad en
matrices pequeñas, fuera del kernel; cubre exactamente 512 grafos dirigidos sobre tres bloques
por 27 ubicaciones en ausencia/primera historia/segunda historia, es decir, 13 824 entradas.
Son casos de validación estructural, no trazas acreditadas de ataque PoST+DAG.

No se cuantifican ancho de banda, memoria de spam, latencia física, probabilidad de eclipse,
finalidad ni riesgo de Cortex. Tampoco se interpreta `PendingHistory` como cero o como rechazo.
