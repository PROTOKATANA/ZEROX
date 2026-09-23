| Poblacion | n | Media | Varianza | Convencion | Denominador | Cociente | Que significa |
|---|---:|---:|---:|---|---|---:|---|
| Los 65536 buckets del sector (universo completo) | 65536 | 500.000000 | 40792.2309 | muestral, /(n-1) | `M/4 = 250` | **163.1689** | ocupacion desigual entre buckets |
| Los 65536 buckets del sector (universo completo) | 65536 | 500.000000 | 40791.6085 | poblacional, /n | `M/4 = 250` | **163.1664** | la misma, con la otra convencion |
| Los 512 retos muestreados (muestra; 510 buckets distintos) | 512 | 516.6602 | 34108.2209 | muestral, /(n-1) | `M/4 = 250` | **136.4329** | la misma magnitud, estimada |
| Los 512 retos muestreados (muestra) | 512 | 516.6602 | 34108.2209 | muestral, /(n-1) | la **media** (indice de Poisson) | **66.0167** | sobredispersion frente a Poisson |

Los 65 536 buckets son el **universo completo** de un sector, pero `var` de Julia usa la
convencion **muestral** (`/(n-1)`); se publican las dos. Los 512 retos son una **muestra**
y cubren solo 510 buckets distintos. **No** son intercambiables entre si.
