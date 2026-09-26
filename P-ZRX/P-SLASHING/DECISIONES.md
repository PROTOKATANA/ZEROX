# P-SLASHING — Decisiones

| ID | Decisión | Quién y cuándo | Motivo | Consecuencia |
|---|---|---|---|---|
| DS-L01 | Única falta castigable en v0: la doble firma (`C-EVP-02`); ninguna ausencia | Director, `ORDEN-SL1` §3 | Mandato §90–91 | — |
| DS-L02 | Sin castigo correlacionado; pérdida no correlacionada, fracción fija `f` | Director, `ORDEN-SL1` §3 | DS-5 | Desaparecen las cohortes de `C-SLA-01` |
| DS-L03 | **Destino de los fondos confiscados: 3/8 a la coinbase del bloque que aplica la `EvidenceTx`; 5/8 se queman** (`EV-23`) | **Katana, 2026-09-26** | Sin inclusión no hay disuasión: todo productor tiene motivo para incluir la prueba | Contra un atacante confabulado con quien incluye, la pérdida neta es 5/8 de lo confiscado; la calibración se repite con ese factor (`ORDEN-SL2b`). La autodenuncia nunca es rentable: el infractor pierde al menos 5/8 |
| DS-L04 | Identidad de oportunidad (`EV-05`): la vigente de `C-GD-07` con candado, o con dominio de red | **Pendiente de Katana** | — | — |
| DS-L05 | Se adopta el cierre de `EV-15b`/`EV-24(ii)`: una liberación exige además `Plazo_slots + M_margen_slots` desde el último bloque producido por la clave; la activación comprueba la desigualdad como puerta | Director, 2026-09-26 (`REVISION-SL1.md`) | Hueco nuevo de SL-1 (retiro parcial con producción continuada) | — |
