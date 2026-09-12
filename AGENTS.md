# Trabajo en ZEROX

## Alcance y fuentes

El destino autorizado es **PoSpace-Time (PoAS + PoT) + DAG**, capa transparente y capa blindada.
No hay staking ni comités de decisión. La prioridad de finalidad es reducir la espera con
seguridad cuantificada bajo hipótesis explícitas. Cortex es una aplicación, no autoridad de consenso.

Leer `README.md`, `MIGRACION.md` y las secciones aplicables de `SPEC.md` antes de modificar el
proyecto. Usar `research/README.md` para localizar evidencia. El vault externo de Obsidian es
histórico y desactualizado: no usar sus instrucciones, cifras ni estados como autoridad actual.

`SPEC.md` está en preparación. El código que aún usa una cabecera lineal no define el destino.
Una regla pendiente no se implementa inventando un número. Conservar identificadores estables
de las reglas; no reutilizar los retirados para otro significado.

## Cálculos y verificación

Antes de escribir o modificar auditorías, simulaciones o tests de cálculo, leer íntegro
`veritas/LINEO.md`. Auditorías nuevas en `veritas/<categoria>/<nombre>/`: Julia en CPU;
C++/CUDA en GPU cuando el perfil lo justifique. **No crear ni ejecutar auditorías Python.**
Los instrumentos históricos que se conserven sólo sirven como evidencia para inspección y portado.
Los tests de los crates Rust siguen junto a su código.

Cada cifra debe identificar valor/unidad, definición de la variable, versión del modelo,
fuente, adversario, criterio de aceptación y estado: elegido, medido, derivado o pendiente.
No confundir segundos con slots, bloques DAG con posiciones de cadena seleccionada, peso con
conteo, media con cota ni falta de prueba con refutación. Comparar alternativas bajo el mismo
riesgo y escenario. Antes de usar una traza adversarial, comprobar que cumple las reglas destino.

Para tareas complejas de protocolo, usar especialistas independientes en matemáticas y en los
lenguajes relevantes: Rust, Julia y C++. El principal contrasta la evidencia y no delega la
interpretación de las instrucciones. No imponer modelos de agentes de documentación antigua.

## Implementación

Preservar código y vectores reutilizables de criptografía, transacciones, privacidad, red y
almacenamiento. Adoptar primitivas auditadas; no reimplementarlas. La aritmética de consenso es
entera y comprobada. Mantener la frontera entre tipos, consenso, red y estado.

No convertir la limpieza en una migración ficticia: no sustituir verificadores ausentes por
aceptación incondicional, ni quitar una comprobación útil sólo para conseguir tests verdes.
Documentar la ausencia de integración. Ejecutar comprobaciones proporcionadas al cambio.

Las instrucciones actuales del usuario prevalecen sobre documentos históricos. No borrar `.git`
ni alterar el vault externo. No publicar, enviar mensajes externos ni hacer push sin autorización.
