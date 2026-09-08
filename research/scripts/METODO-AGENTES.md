# Método obligatorio para todo agente de las rondas DAG/PoST (vigente 2026-09-08)

1. **Directorio propio y nada más.** Trabajas SOLO en tu directorio `research/scripts/<ronda>/`. No editas ningún otro
   fichero del repositorio (ni la propuesta `research/dag-poas-ancla-de-orden.md`, ni informes, ni el vault). Nada en `/tmp`.
2. **Volcado incremental.** Escribes `informe.md` en tu directorio desde el primer punto y lo actualizas al cerrar cada
   punto. Commiteas por punto (`git add research/scripts/<ronda>/ && git commit -m "<ronda>: <punto> — <resultado>"`),
   solo tu directorio. **`git push` prohibido.** Si mueres a mitad, lo escrito sobrevive.
3. **Sin presupuesto de tiempo: resultado completo.** Katana prefiere un resultado completo a uno rápido (decidido
   2026-09-08, noche). No recortes rejillas, semillas, filas de tabla ni configuraciones para acabar antes. Las corridas
   largas se lanzan en segundo plano (`nohup … &`) y se sigue con otro punto mientras terminan; se releen al final. Sí se
   mantiene, porque no pierde precisión: rejilla gruesa para localizar y fina (o `brentq`) para refinar, y
   `multiprocessing.Pool` para usar todos los núcleos. La etiqueta LAGUNA es solo para lo que no se puede saber con las
   fuentes y los instrumentos disponibles (y entonces se dice qué haría falta), **nunca por falta de tiempo**.
4. **Criterio α.** Todo resultado de simulación debe cambiar al cambiar `α` (y al cambiar el parámetro que se estudia).
   Control positivo antes de medir: reproduce primero un número ya publicado con el mismo instrumento.
5. **≥ 12 semillas** en todo lo estocástico; reporta media e intervalo. Contadores de cobertura de rama (si la rama que
   distingue A de B no se ejecuta, la comparación no vale).
6. **Cinco etiquetas, siempre:** DEMOSTRADO (argumento cerrado), VERIFICADO (medido y reproducible), PLAUSIBLE (argumento
   sin cerrar), REFUTADO, LAGUNA (no se sabe; decir qué haría falta). Cota ≠ realidad: distingue lo que acota de lo que mide.
7. **Citas con fichero y línea.** Papers en `research/fuentes/`; Kaspa en `/home/katana/zeo/fuentes/rusty-kaspa`; Autonomys
   en `/home/katana/zeo/fuentes/subspace` (@ `f8842d0`); Chia en `PDF/chia-blockchain/` (v2.7.4). Nunca de memoria: si no
   encuentras la fuente, LAGUNA.
8. **Adversario del paper, sin retardo:** el atacante ve todo al instante, no paga `Δ`; los honestos sí.
9. **Errores propios declarados** en una sección final del informe, con lo que cambió.
10. **Al entregar:** ejecuta `python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/<ronda>/` y pega su salida en el
    informe, leyendo cada marca. Cierra con `## Veredicto` (una tabla punto → etiqueta → número) y `## Errores propios`.
11. **Idioma:** español. Números con coma decimal en el informe.
