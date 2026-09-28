# Encargo 02 — auditorías, regeneración y fallos honestos

**Tipo:** investigación adversarial y prototipo aislado.
**Dependencia:** resultado de 01 que defina el objeto exacto; si G1 falla,
estudiar auditorías solo como experimento de coste, sin reivindicar retención.
**Zona de entrega:** `P-ZRX/P-REGISTRO-SECTORES/investigacion/02-auditorias/`.
**Prohibido:** fijar plazos por analogía con Filecoin o penalizar ausencias en consenso.

## Pregunta falsable

¿Qué combinación de reto, plazo y número de aperturas obliga a conservar el
sector o encarece materialmente regenerarlo, para un adversario declarado,
sin expulsar con frecuencia excesiva a un granjero honesto?

## Trabajo

1. Comparar R0 sin auditorías, R1 identidad/fecha, R2 raíz exacta y R3
   raíz más auditorías. Especificar aleatoriedad futura derivada del pasado
   DAG validado, instante en que un atacante con PoT acelerado puede conocerla,
   capacidad de sesgarla, selección de sector/hojas, respuesta y deadline.
   No copiar la aleatoriedad, las 48 ventanas ni el SNARK de WindowPoSt.
2. Construir estrategias adversarias: no guardar nada y regenerar al reto;
   guardar solo metadatos o hojas frecuentes; comprimir; compartir bytes entre
   registros; guardar sector tras ganar; alquiler temporal; lotes de claves y
   sectores; rama privada. Para cada una medir trabajo, latencia crítica,
   RAM, I/O y paralelo CPU/GPU. Separar coste agregado de suelo secuencial.
3. Construir un oráculo pequeño y simulación reproducible de auditorías
   sucesivas. Probar con parcela/verificador reales las rutas donde el formato
   afecta al resultado. Medir también pérdida honesta: disco defectuoso,
   apagado, ancho de banda, latencia, partición, censura y reorganización.
   Ausencia de respuesta no identifica por sí sola la causa.
4. Para cada política de respuesta, comparar: pérdida temporal de
   elegibilidad, retención de recompensa, prueba de recuperación, retirada
   voluntaria y eventual pérdida de garantía. Calcular falsos positivos,
   persistencia del estado y tiempo de recuperación. Si no puede defenderse
   una sanción por ausencia con la red modelada, recomendar solo suspensión
   reversible u otra consecuencia limitada.
5. Expresar la frontera de seguridad como función de ventana de adelanto,
   plazo, tasa de regeneración adversarial, número de retos y capacidad
   declarada. Publicar sensibilidad y contraejemplo más barato encontrado.
   No convertir percentiles en una cota absoluta ni declarar preexistencia.

## Salida y criterio de cierre

Entregar `MODELO.md`, `METODO.md`, `INFORME.md`, resultados y
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. La tabla final debe dar por
ataque **impide / encarece / detecta bajo supuestos / no afecta**, más coste
honesto, coste adversarial e intervalo o cota correspondiente. Cerrar G2 con
el riesgo aceptable declarado *antes* de mirar resultados; si nadie ha fijado
ese riesgo, dar curva de decisión y dejar el veredicto condicional.

Leer `V-ZRX/LINEO.md` íntegro antes de programar el instrumento. Julia en
CPU; C++/CUDA para GPU solo con perfil que justifique el gasto. Sin auditorías
Python.
