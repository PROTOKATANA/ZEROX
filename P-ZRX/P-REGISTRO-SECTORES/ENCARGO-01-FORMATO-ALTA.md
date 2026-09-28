# Encargo 01 — compromiso y alta de un sector real

**Tipo:** investigación de formato y prototipo aislado. **Dependencia:** ninguna.
**Zona de entrega:** `P-ZRX/P-REGISTRO-SECTORES/investigacion/01-formato-alta/`.
**Prohibido en este encargo:** cambios de `SPEC.md`, `D-ZRX/SPEC.md`, consenso,
activación o restauración masiva del árbol histórico.

## Pregunta falsable

¿Puede una solución PoAS real demostrar pertenencia al **mismo sector completo**
que fue comprometido antes de ser elegible, con coste admisible de alta y
verificación? No confundir esta propiedad con preexistencia física o permanencia.

## Trabajo

1. Fijar la revisión de fuente y reconstruir el camino real: bytes de la
   parcela en disco → `SectorId` y metadatos → `Solution` → verificación PoAS
   → `C-GD-07`. Citar líneas y señalar qué se deduce del informe histórico y
   qué se vuelve a verificar en código. Leer `P-COBERTURA` §§2–3, 7;
   `P-SEMBRADOR` fase 1; y la fuente de Filecoin para alta/PoRep.
2. Definir dos candidatos mínimos: R1, alta de identidad y fecha; R2,
   compromiso exacto con versión, dominio de red, clave, índice, historia,
   cardinalidad y raíz de los bytes codificados y metadatos necesarios.
   Especificar serialización canónica, orden de hojas, relleno y tipos de
   apertura; identificar los bytes que quedan fuera.
3. Construir un prototipo fuera de consenso que genere una parcela real de
   tamaño manejable, registre R1/R2 y verifique apertura de una solución
   ganadora contra R2. Rechazar intercambios de sector, clave, índice,
   historia, versión, hoja y raíz, además de sectores duplicados/caducados.
   Si la fuente histórica no puede compilar en el árbol actual, documentar
   bloqueo y usar un checkout aislado fijado a un commit; no sustituir el
   verificador real por una simulación para reclamar G1.
4. Estudiar la tercera variante R3: prueba de inicialización/codificación
   completa ligada a aleatoriedad disponible después del precompromiso.
   Entregar una construcción verificable o una razón técnica precisa de por
   qué requiere cambiar el formato/circuito. Una raíz Merkle por sí sola no
   cumple R3; una prueba de cómputo no demuestra retención posterior.
5. Medir bytes por alta, por solución y por apertura; CPU, RAM, I/O, tiempo
   de alta, tamaño de estado y coste de verificación por bloque para varios
   tamaños. Comparar con R0 sin registro. No usar cifras antiguas como medida
   del prototipo nuevo.

## Salida y criterio de cierre

Entregar `INFORME.md`, especificación de bytes, tabla de cobertura por
variante, código y comandos reproducibles, pruebas negativas y resultados.
Cerrar G1 como **superada**, **fallida** o **inconclusa**. Una apertura válida
de una sola pieza frente a la raíz demuestra vínculo de esa pieza; documentar
por separado por qué el compromiso cubre el conjunto y qué trabajo exigió
producir la raíz. No declarar «sector almacenado» con una prueba de pertenencia.

Antes de escribir benchmarks o auditorías de cálculo, leer `V-ZRX/LINEO.md`.
Usar Julia CPU para el modelo; Rust para el prototipo de formato/verificador;
C++/CUDA solo si un perfil exige medir una ruta GPU. No crear auditorías Python.
