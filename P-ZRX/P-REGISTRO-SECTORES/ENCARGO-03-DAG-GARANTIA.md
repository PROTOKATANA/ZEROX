# Encargo 03 — semántica DAG y vínculo con la garantía

**Tipo:** diseño de estado y oráculo de consenso, sin activación.
**Dependencias:** definiciones de sector de 01 y modelo de auditoría de 02.
**Zona de entrega:** `P-ZRX/P-REGISTRO-SECTORES/investigacion/03-dag-garantia/`.
**Prohibido:** modificar `D-ZRX/SPEC.md` o tratar el stake como fuente de
turnos, rango PoAS o `blue_work`.

## Pregunta falsable

¿Se puede añadir un ciclo de vida de sector y obligaciones auditables al
PoAS + PoT + DAG de ZEROX con transiciones deterministas, undo exacto,
contabilidad conservativa y acceso viable para productores nuevos?

## Trabajo

1. Especificar un autómata de investigación: precomprometido, pendiente de
   prueba, activo, temporalmente fallido, en recuperación, en retirada,
   caducado. Cada transición debe indicar operación, autorización, identidad,
   slot de aplicación, caducidad y efecto de reorg. Rechazar dobles altas,
   índices reciclados sin versión, pruebas fuera de plazo y `history_size`
   incompatible.
2. Definir consulta del registro desde `past(B)` validado. Comparar el alta
   en cadena seleccionada, una rama lateral y un mergeset aplicado tarde.
   Explicar cuándo una solución es elegible, si necesita testigo del estado,
   qué ocurre si un alta se deshace y cómo impedir que el orden de llegada
   cambie el resultado. Usar `C-GD-07`, `C-ORD-03/04` y `C-FIN-01` históricos
   como interfaz; no interpretar alturas lineales como slots.
3. Separar tres contabilidades: sectores lógicos activos, oportunidades PoAS
   y garantía castigable. Proponer funciones **simbólicas** de garantía por
   sector/capacidad y de recompensa retenida; comparar con C-BON-01…07 de
   `D-ZRX/SPEC.md`. Probar que ni depósito ni número declarado de sectores
   multiplican `blue_work` o sustituyen prueba PoAS. Cuantificar barrera de
   entrada, inmovilización y capacidad sin stake suficiente.
4. Definir quién contrae obligación: todo sector activo o solo sector que
   produjo/cobró; qué bloques del DAG la crean; qué sucede con rojo_U3,
   reorg, coinbase pendiente, auditoría tardía, recuperación y retirada.
   Separar suspensión por falta de prueba de confiscación por falta
   demostrada. No solapar con C-EVP/C-SLA sin regla explícita de prioridad.
5. Implementar un oráculo pequeño de estado y trazas adversarias: mismo
   pasado con distinto orden de llegada; alta y auditoría en ramas que se
   fusionan; reorg antes/después de madurez; partición honesta; múltiples
   sectores por clave; stake insuficiente; retirada y duplicados. Comprobar
   determinismo, conservación de valor, undo exacto y cotas de estado/CPU.

## Salida y criterio de cierre

Entregar `AUTOMATA.md`, `INVARIANTES.md`, `INFORME.md`, oráculo y trazas
reproducibles. Cerrar G3 como **superada**, **fallida** o **inconclusa**. Si
faltan `F_slots`, límites de red, emisión, madurez o tamaño de garantía,
dejarlos como variables y publicar las desigualdades que una elección deberá
satisfacer; no inventar parámetros.

Antes de un oráculo de cálculo, leer `V-ZRX/LINEO.md`. Julia CPU para
transiciones pequeñas y análisis; Rust solo si hace falta contrastar el
códec/estado real. No crear auditorías Python.
