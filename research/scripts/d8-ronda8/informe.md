# D8 · ronda 8 — ataques contra el diseño completo (ancla por `slot`, constantes fijadas)

**Fecha:** 2026-09-08 · **Agente:** D8 (adversarial, fresco) · **Estado:** EN CURSO

> **Regla 8 (volcado incremental).** Un D8 anterior murió por cuota sin escribir nada. Este
> fichero se escribe ANTES de A1 y se cierra tras CADA línea con veredicto y números.
> Lo que esté en disco es lo único que sobrevive.

---

## 0 · Plan y estado del instrumento

### 0.1 · Qué se ataca

`research/dag-poas-ancla-de-orden.md` §2 (R-FIN-1..13), con las constantes:
`k = 30`, `mp = 15`, `msl = 180`, `λ = 1 bloque/s`, `q = 1`, `Δ = 4 s`,
`I = 4 200 s`, `F = L = 5,3 h`, `S_max ∈ [20, 150] s`, `W_RETARGET ≥ 3 083`, `τ ≈ 0,1-0,17 s` (rama A).

### 0.2 · Líneas

| Línea | Objetivo | Estado |
|---|---|---|
| A0 | Validar el instrumento heredado (`d8_lib.py` del D8 muerto) | PENDIENTE |
| A1 | ¿Se **sostiene** el sesgo `δ` del Lema 9 con `α < 1/2`? `δ` sostenible real | PENDIENTE |
| A2 | Acuerdo honesto con **dos vistas** separadas por `Δ`: `P(I_j distinto)` | PENDIENTE |
| A3 | Partición + `S_max` + R-FIN-7: ¿se puede **provocar** sin partición real? | PENDIENTE |
| A4 | Cruce del ancla `slot` en régimen (`I = 4 200 s`, `F = 5,3 h`); retención hasta `S_max` | PENDIENTE |
| A5 | Soborno BDK+19 §2 portado a PoAS (`W/κ = 1,22`) | PENDIENTE |
| A6 | Líneas 3/5/6 de §7 + **margen económico** con lookahead `F + I = 6,5 h` | PENDIENTE |

### 0.3 · Estado del instrumento — declaración sobre `d8_lib.py`

`d8-ronda8/d8_lib.py` (12 112 B, 2026-09-08 06:57) lo dejó el D8 que murió. **No se da por bueno.**
Lo que contiene, leído línea a línea:

- `MundoL9` — extiende `r8c_sim.Mundo`, sobrescribe el bucle para ejecutar la maniobra
  **adaptativa** del Lema 9 (`phantom-ghostdag.txt` L1131-1141): retener `J` bloques privados y
  soltarlos cuando `_key(tip_privado) > _key(sp_honesto)`. Reutiliza `_padres`
  (`pick_virtual_parents`) sin tocarlo. Contadores: `n_rafagas`, `n_abandonos`, `n_intentos`,
  `n_bloques_priv`, `n_bloques_perdidos`.
- `MundoDosVistas` — dos honestos `H_A`, `H_B` con `Δ` entre ellos; el atacante entrega a uno solo.
- `delta_hon`, `vista_en` — lecturas.

**Defecto encontrado en la lectura (declarado antes de usarlo):** en `corre_l9`,
`sp_h = d.virtual_sp(pub)` con `pub = [h for h in llega]` toma **todos los bloques entregados,
incluidos los que aún viajan** (`llega[b] = t + Δ`). Eso **no es** el padre seleccionado que el
honesto usará en `t`; es la vista omnisciente del atacante. La maniobra del Lema 9 exige superar
**la cadena que el honesto ve**. Se corrige y se parametriza (`vista_sp`), y se mide con las dos.

**Validación obligatoria antes de reutilizar** (encargo explícito): reproducir `m_SLOT = 2,54`
en las 12 semillas de `d9-ronda8f/salida_b1_gran1.txt` (`copias=14`, `α=0,25`, `gran=1,0`).
Resultado: PENDIENTE (§A0).

### 0.4 · Reglas que este informe respeta

1. Criterio `α` (fila `α = 0` en toda tabla). 2. Contadores de cobertura de rama.
3. ≥ 12 semillas. 4. El instrumento demuestra primero que **puede** detectar lo que busca.
5. `AUDITA_SCRIPTS.py` antes de entregar, salida declarada. 6. Etiquetas REFUTADO / SIN VECTOR /
TENSIÓN / LAGUNA. 7. Fichero y línea, o LAGUNA. 11. Adversario del paper, sin retardo.

---
