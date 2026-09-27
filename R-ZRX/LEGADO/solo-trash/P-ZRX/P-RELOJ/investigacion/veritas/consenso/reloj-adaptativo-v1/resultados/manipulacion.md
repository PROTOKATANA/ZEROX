# Región de manipulación de N — M2
#
# Generado: 2026-09-24T16:29:44.293
# Máquina: AMD Ryzen 9 9950X3D (Zen 5)
# Hardware medido: lat_ronda=7.369e-10 s, lat_bloque=7.739e-10 s, t_bloque_par=9.603e-10 s, K=8, 4.001 ciclos/ronda, 5.428 GHz
#
# TODOS los parámetros de protocolo de este fichero son ENTRADAS de barrido,
# declaradas como tales. Ninguno es un valor decidido para ZEROX.
#

Fuente: timestamps. Reglas aplicables: `C-TS-01` (monotonía; la relación
timestamp–slot **sigue pendiente** en `SPEC.md` §7.4), `C-TS-03` (FTL, **valor
pendiente**), `C-TS-04` (prohíbe la hora de red) y `C-TS-02` (MTP no sustituye
el índice PoT).

PARÁMETROS DE EJEMPLO, todos ENTRADAS de barrido: ventana observada
τ_obs = 600.0 s, retraso máximo por bloque δ = 1 s, FTL φ (se declara en cada tabla).

## 1 · Umbral de mayoría

Con `W = 2m+1` la mediana es la posición `m+1`; el adversario la FIJA con
`C = ⌊α·W⌋ ≥ m+1`, o sea con `α` por encima de:

| W | α mínimo que fija la mediana |
|---:|---:|
| 5 | 0.6 |
| 11 | 0.5455 |
| 21 | 0.5238 |
| 51 | 0.5098 |
| 101 | 0.505 |
| 201 | 0.5025 |

## 2 · Sesgo por bloque y factor sobre N

Sesgo máximo por bloque del adversario: hacia abajo `−min(δ,1)` (cadena monótona o
posición), hacia arriba `+φ` (FTL). Factor sobre `N`, que escala con `1/τ_obs`:

| C (bloques del adversario en la ventana) | sesgo abajo (s) | factor N abajo | sesgo arriba con φ=3600 s | factor N arriba |
|---:|---:|---:|---:|---:|
| 1 | -1.0 | 1.00166945 | 3600.0 | 0.14285714 |
| 2 | -2.0 | 1.00334448 | 7200.0 | 0.07692308 |
| 5 | -5.0 | 1.00840336 | 18000.0 | 0.03225806 |
| 10 | -10.0 | 1.01694915 | 36000.0 | 0.01639344 |
| 20 | -20.0 | 1.03448276 | 72000.0 | 0.00826446 |
| 50 | -50.0 | 1.09090909 | 180000.0 | 0.00332226 |
| 100 | -100.0 | 1.2 | 360000.0 | 0.00166389 |

## 3 · Región por α y W (factor de N hacia abajo, δ = 1 s)

`C = ⌊α·W⌋`; el sesgo es `−C·min(δ,1)` y el factor `τ_obs/(τ_obs+sesgo)`.

| α \ W | W=11 | W=51 | W=201 |
|---:|---:|---:|---:|
| 0.1 | 1.001669 | 1.008403 | 1.034483 | 
| 0.2 | 1.003344 | 1.016949 | 1.071429 | 
| 0.3 | 1.005025 | 1.025641 | 1.111111 | 
| 0.4 | 1.006711 | 1.034483 | 1.153846 | 
| 0.49 | 1.008403 | 1.041667 | 1.195219 | 
| 0.5 | 1.008403 | 1.043478 | 1.2 | 
| 0.55 | 1.010101 | 1.048951 | 1.22449 | 
| 0.66 | 1.011804 | 1.058201 | 1.282051 | 
| 0.75 | 1.013514 | 1.067616 | 1.333333 | 
| 0.9 | 1.015228 | 1.081081 | 1.428571 | 

**Lectura:** con `α < 1/2` el adversario no fija la mediana, pero el factor se
aleja de 1 de forma monótona en `α` y en `W`. Con `α > 1/2` domina la mediana.

## 4 · Límite declarado de la evidencia

El oráculo por programación dinámica (`Referencia.sesgo_mediana_dp`) reproduce
estos números cuando TODOS los bloques del adversario van al final de la ventana y
son mayoría para fijar la mediana. Fuera de ese régimen su modelo se separa del
protocolo y **se declara inconcluso**, con el caso concreto que lo rompe:
`W = 51, C = 48, δ = φ = 0` da mediana 2 s donde la escala honesta daría 25 s, porque
el oráculo trata los timestamps como una única cadena monótona global y en el
protocolo cada bloque honesto tiene su propio reloj. **Los números publicados de esta
sección son los de la aritmética del orden, no los del oráculo**, y la discrepancia
está contada en `resultados/validacion.md`.
