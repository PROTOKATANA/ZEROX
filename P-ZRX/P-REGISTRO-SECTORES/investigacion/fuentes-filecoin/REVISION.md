# Revisión del director — fuentes de Filecoin (2026-09-26)

**Ejecutor:** subagente Claude Sonnet (investigación de fuentes, sin código). **Revisor:** Claude
(director). **Veredicto:** aceptado como insumo de D-04/D-05, con una corrección.

**Comprobado por el director en la fuente (WebFetch, 2026-09-26):**
- `sector-faults`: «Without this incentive, it is impossible to distinguish an honest minerʼs
  hardware failure from malicious behavior, which is necessary to treat miners fairly»; gracia de un
  día; cuota por sector y día; retirada tras «more than 42 consecutive days». Coincide.
- `sealing`: dos frases **separadas** — «The ticket has to be drawn from a finalized block in order
  to prevent the miner from potential losing storage (in case of a chain reorg) even though their
  storage is intact» y «Tickets are used as input to calculation of the ReplicaID in order to tie
  Proofs-of-Replication to a given chain, thereby preventing long-range attacks (from another miner
  in the future trying to reuse SEALs)».

**Corrección.** INFORME §3 y §8 dicen que el ticket se toma de un bloque finalizado
«explícitamente para evitar ataques de largo alcance». Según la fuente, el bloque **finalizado**
protege al minero **honesto** frente a un reorg; lo que evita el largo alcance es **incluir el
ticket en el `ReplicaID`**. La conclusión de fondo no cambia (un punto finalizado no separa ramas
no finalizadas: RFT-06), pero la motivación citada estaba fundida.

**Límites que se mantienen:** citas marcadas `[fuente-reportada]` (texto devuelto por la
herramienta), no cotejadas contra el HTML crudo salvo las dos anteriores; no se consultó el
artículo de Stacked DRG ni hay cifra de profundidad secuencial ni de tiempo de sellado.
