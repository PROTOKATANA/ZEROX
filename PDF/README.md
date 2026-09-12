# Fuentes de consulta

Este directorio conserva material útil sobre pruebas de espacio. No fija reglas de ZEROX.

- `time-memory-tre-off-proof-space.pdf`: fuente del informe de
  [intercambio entre tiempo y memoria](../research/time-memory-tradeoff.md).
- `chia-blockchain/`: copia local de referencia, ignorada por Git; no es código de ZEROX.
- `autonomys-subspace/`: implementación Rust de Autonomys usada por la investigación de ZEROX,
  ignorada por Git; no es un miembro del workspace.
- [repositorio.txt](repositorio.txt): enlaces y commits de las fuentes.
- [Greenpaper de Chia fechado 2026-06-12](../research/scripts/d14-sin-comite/fuentes/chia-greenpaper-20260612.pdf): fuente conservada en investigación.

La limpieza retiró de este directorio el precursor `ChiaGreenPaper.pdf` de 2019 y el whitepaper
comercial de 2022. Se recuperan desde la copia de seguridad del usuario o el historial de Git.
Los informes históricos que los citan no convierten esos diseños en el protocolo vigente.

## Versiones de referencia

| Copia local | Repositorio original | Commit consultado |
|---|---|---|
| `autonomys-subspace/` | https://github.com/autonomys/subspace | `f8842d019cdf0f7163421b9644db5a9ff82b2a73` |
| `chia-blockchain/` | https://github.com/Chia-Network/chia-blockchain | `f87270c0275904981366651a59a0618aea5144ce` |

El 10 de septiembre de 2026 se encontró la copia de Autonomys en
`/home/katana/zeo/fuentes/subspace`, limpia y en el commit citado por los informes. Se creó aquí
un clon independiente, sin hardlinks ni dependencias de objetos del original, en ese mismo commit
(`HEAD` separado). Se conservó intacta la copia original y se configuró el remoto oficial.
No hizo falta descargar ni actualizar código de Internet. Estos commits identifican la evidencia;
no se presentan como las versiones más recientes de los proyectos.

Para reconstruir la copia de Autonomys si no existe:

```bash
git clone https://github.com/autonomys/subspace PDF/autonomys-subspace
git -C PDF/autonomys-subspace checkout --detach f8842d019cdf0f7163421b9644db5a9ff82b2a73
```

Los parámetros upstream no pasan automáticamente a ZEROX: la prueba de espacio, el calendario
de Autonomys, el consenso de Chia y el orden DAG son capas distintas. Toda adaptación debe registrar
valor de origen, modificación, motivo y evidencia. Tampoco basta que Autonomys use una tabla Chia
para heredar el consenso o las cotas de seguridad de `chia-blockchain`.
