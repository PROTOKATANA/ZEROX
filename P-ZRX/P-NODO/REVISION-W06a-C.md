# REVISIÓN W06a-C — `zx-cadena` sin atajos del oráculo

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek, 09:51–11:59 (2 h 09 min
frente a 1 h 30 min previstos, declarado). Evidencia: `resultados-W06a-C/`. **Veredicto: SUPERADO.
Migrada** por parche (11 rutas, `git apply --check` limpio, huellas de las rutas del parche verificadas
contra `MIGRACION.sha256`; lock idéntico).

## Lo que cambia

- `Cadena::nueva(…, max_padres)`: sin valor oculto; el nodo usa 15 (`PERFIL-DEV-v0.md`), el arnés de T04
  declara 3. Tests: 15 padres admitido, 16 rechazado.
- Identidad GHOSTDAG real (`IdentidadGhostdag::Billete` de la tupla `C-GD-07`), sin truncar;
  `de_fixture` solo en el arnés. Test de U2 con dos identidades cuyos primeros 8 bytes coinciden y difieren
  en el resto (una colisión real de 8 bytes de SHA3 no cabe en un test: lectura declarada).
- Suite: **698 pasan, 0 fallan, 2 ignorados** (694 + 4); `diferencial_t04` 914 casos, 0 discrepancias,
  cobertura idéntica.

## Hallazgo: prueba de reinicio intermitente

La primera ejecución conjunta de la raíz (W06d1 + W06a-B, `logs/V0.log`) **falló** en
`crates/zx-node/tests/reinicio.rs` («ronda régimen 4: no se vieron 4 bloques producidos en 30 s»); aislada
pasa (428,69 s) y la suite repetida da 694/0/2. Ya había pasado lo mismo en W06d1. Es una espera de 30 s de
reloj de pared en `debug`: **una prueba intermitente no es evidencia**. Se corrige en W06d2 (decisión
nueva en su orden): esperar por eventos del registro con un límite generoso y declarado, o ejecutar la
prueba en `release`.
