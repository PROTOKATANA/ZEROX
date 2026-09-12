# Método de las rondas históricas: sustituido

Este archivo fue el método de trabajo de las rondas DAG/PoST de septiembre de 2026.
Sus instrucciones anteriores ya no rigen nuevas tareas: incluían ejecución de auditorías Python,
uso indiscriminado de núcleos y reglas de trabajo que no corresponden al flujo actual.

Por instrucción actual del usuario, **no se crean ni ejecutan nuevas auditorías o tests de cálculo
en Python**. Antes de una auditoría o prueba se consulta
[veritas/LINEO.md](../../veritas/LINEO.md) y se aplica su método: Julia en CPU; C++/CUDA para GPU
cuando el problema y las mediciones lo justifiquen. La instrucción del usuario prevalece sobre
cualquier excepción histórica que permitiera usar Python.

Los scripts Python existentes y sus resultados se conservan **sin ejecutar** como evidencia
histórica: permiten rastrear parámetros, errores, dependencias y contraejemplos. Que un informe
antiguo ordene ejecutarlos, cite este método o declare un resultado verificado no autoriza su
ejecución ni convierte sus constantes en reglas actuales.

Las nuevas verificaciones deben distinguir el modelo, la implementación y los parámetros del
destino PoSpace-Time + DAG. No se transfiere un veredicto entre modelos sin justificar esa
transferencia. Se conservan los informes originales para mantener la trazabilidad de las
correcciones; las nuevas auditorías viven en el entorno reproducible indicado por LINEO.

Consultar [el índice de investigación](../README.md) y
[el estado de migración](../../MIGRACION.md) para identificar piezas útiles, legado retirado y
trabajo pendiente. El vault externo desactualizado no es autoridad de vigencia para ZEROX.
