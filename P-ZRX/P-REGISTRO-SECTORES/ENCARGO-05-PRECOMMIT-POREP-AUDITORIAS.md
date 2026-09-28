# Encargo 05 — evaluar precompromiso + PoRep + auditorías como sistema

**Tipo:** evaluación de arquitectura y seguridad, con prototipo si las
interfaces de 01/02 lo permiten. **Estado:** investigación, no regla de
consenso. **Zona de entrega:**
`P-ZRX/P-REGISTRO-SECTORES/investigacion/05-sistema-porep/`.

Puede comenzar la revisión de fuentes y el diseño de interfaces ahora. El
veredicto depende de los resultados de 01 (formato/alta), 02 (regeneración y
auditorías), 03 (estado DAG/garantía) y 04 si se necesita un formato nuevo.
No repetir sus mediciones bajo nombres distintos: integrarlas y comprobar
las propiedades del **conjunto**.

## Pregunta falsable

¿Aporta a ZEROX una mejora de seguridad demostrable la secuencia completa
**precomprometer sector → sellar/probar una réplica ligada a identidad y
aleatoriedad posterior → activar → auditar periódicamente → fallar/recuperar**,
manteniendo PoAS + PoT como recurso que produce oportunidades y peso?

La respuesta debe distinguir: (a) obligación de pagar trabajo de sellado;
(b) identificación de una réplica; (c) prueba de que existía en un momento;
(d) retención durante un intervalo; (e) poder producir un bloque PoAS con
*esa misma* capacidad. Ninguna implica automáticamente a las demás.

## Fuentes y límite de transferencia

- Filecoin: [alta de almacenamiento](https://spec.filecoin.io/systems/filecoin_mining/sector/adding_storage/),
  [PoRep](https://spec.filecoin.io/algorithms/pos/porep/),
  [sellado y aleatoriedad](https://spec.filecoin.io/systems/filecoin_mining/sector/sealing/),
  [Winning/WindowPoSt](https://spec.filecoin.io/algorithms/pos/post/),
  [faltas](https://spec.filecoin.io/systems/filecoin_mining/sector/sector-faults/)
  y [colateral](https://spec.filecoin.io/systems/filecoin_mining/miner_collaterals/).
- ZEROX histórico: `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §§2–3, 7;
  `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md`;
  `P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md`, en
  `/home/katana/zeo/.trash/zerox/` o `HEAD:...` del commit `9681061`.
- ZEROX nuevo: `D-ZRX/SPEC.md` C-BOT/C-BON/C-EVP/C-SLA y los encargos 01–04.

Filecoin registra un `SealedCID` con depósito, exige una PoRep después de
aleatoriedad futura y antes de expirar el precompromiso, y audita las
réplicas activas. Su PoRep depende de una **codificación sellada específica**.
El `SectorId` y la solución de pieza del PoAS histórico de ZEROX no son esa
PoRep. No importar el significado de «sector», el SNARK, los 150 bloques,
los plazos WindowPoSt ni las sanciones de Filecoin como parámetros ZEROX.

## Trabajo obligatorio

### 1. Contrato temporal y transición PoW → PoAS + PoT + DAG

1. Dibujar el orden verificable: elección del historial PoW, precompromiso,
   depósito, aparición de aleatoriedad impredecible, sellado/prueba,
   activación, auditoría, fallo, recuperación, expiración y retiro.
2. Resolver cuándo se admiten operaciones de sector bajo PoW y cuáles quedan
   activas en el primer bloque PoAS + PoT. Si la semilla de sellado sale del
   bloque terminal PoW, mostrar cómo llega a tiempo un sector sellado;
   comparar un ancla PoW anterior, una espera de activación posterior y
   otras variantes explícitas. Modelar dos terminales PoW y reorg tardío.
3. Definir identidad única de réplica, raíz precomprometida, referencia de
   cadena, ventana de presentación y caducidad, con consulta contextual
   desde `past(B)`. Separar altura PoW, slot PoT, orden DAG y tiempo real.

### 2. Compatibilidad criptográfica y física con PoAS

1. Mostrar exactamente qué bytes sella PoRep y cuáles lee el productor
   PoAS para calcular una solución. Probar con un sector real si ambos
   mecanismos pueden usar una **única representación almacenada**, o medir
   la duplicación de bytes, I/O y CPU si hacen falta dos representaciones.
2. Comparar: P0, `SectorId`/raíz sin sellado; P1, compromiso de sector
   completo con formato PoAS actual; P2, nuevo sellado verificable ligado
   a clave, sector y aleatoriedad futura; P3, P2 más auditorías. Para cada
   uno, indicar qué afirma el verificador y el contraejemplo más barato.
3. Si se propone adaptar un PoRep existente, indicar prueba de seguridad,
   implementación auditada, parámetros de confianza, portabilidad,
   integración con KZG/erasure coding/PoAS y riesgo de circuitos nuevos.
   Un hash del sector o una apertura Merkle no cuentan como PoRep.

### 3. Seguridad adversarial y operación honesta

1. Ensayar precomputación, creación de precompromisos vacíos, grinding de
   claves/sectores y ancla PoW, ploteo parcial, compresión, una réplica
   compartida entre varias identidades, alquiler, sellado acelerado,
   regeneración al reto, borrado tras premio y uso en dos ramas privadas.
2. Medir sellado/proof/verify y auditoría por sector/TiB: latencia,
   throughput, CPU/GPU, RAM, I/O, bytes en cadena y estado acumulado;
   tasa de altas, capacidad inactiva y retraso para un granjero doméstico.
   Separar trabajo total de profundidad secuencial; ninguna medición de
   una GPU local es un límite universal del adversario.
3. Medir respuestas honestas perdidas por fallo de disco, desconexión,
   partición, censura y reorg. Comparar suspensión de elegibilidad,
   retención de recompensa, recuperación y confiscación. Una ausencia
   observable no prueba su causa; no activar slashing automático sin un
   criterio que incluya falsos positivos.
4. Evaluar depósito de precompromiso, garantía por sector y recompensas
   retenidas junto a C-BON. Verificar conservación monetaria, undo exacto
   y efecto en acceso de nuevos productores. Ni pledge ni número de
   sectores declarados multiplican `blue_work`.

## Comparación y entrega

Comparar P0–P3 y PoST sin registro bajo el **mismo** adversario, red,
horizonte y criterio de fallo. Publicar una matriz:

`variante × propiedad verificada × ataque residual × coste honesto × coste
adversarial × latencia de entrada × falsa falta × fuente`.

Entregar `ARQUITECTURA.md`, `MATRIZ.md`, `MODELO.md`, `METODO.md`,
`INFORME.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`, trazas y
prototipo reproducible cuando haya medición. El informe terminará en
**descartar**, **mejora condicional del formato actual**, **investigar un
PoRep/plot nuevo** o **proponer ratificación**, indicando el experimento
que haría cambiar la decisión.

Solo proponer ratificación si están demostradas la compatibilidad entre
prueba de replicación y farming PoAS, la semántica del corte PoW, la
resistencia medida a regeneración, el coste honesto, el tratamiento de
faltas y el estado/undo DAG. El sistema no puede declararse solución al
doble farmeo de una rama que nunca revela una segunda firma.

Para código de auditoría, leer antes `V-ZRX/LINEO.md`: Julia CPU;
C++/CUDA GPU si el perfil lo justifica; Rust para formato y verificadores.
No crear auditorías Python ni modificar consenso o `D-ZRX/SPEC.md` en este
encargo.
