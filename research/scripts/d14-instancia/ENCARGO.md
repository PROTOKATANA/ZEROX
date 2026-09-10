# Ronda 14B — Capa de comité con instancias continuas: el mínimo de irreversibilidad y su techo de gossip

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio). Prioridad declarada: **bajar el
tiempo de irreversibilidad lo más posible**. El cliente ligero es secundario.

**Pregunta.** La capa P-040 (estilo F3) hereda la época de 30 s de Filecoin (`fip-0086.md:39`) y
una instancia por época (`:54`, `:704`). El FIP admite finalizar dentro de la época (`:938`).
¿Cuál es el **mínimo de irreversibilidad** de una capa de comité derivada del espacio con cadencia
`c < 30 s`, dado el techo de ancho de banda del gossip? ¿Y qué motor (GossiPBFT, Simplex, BA\*,
Cordial Miners) da ese mínimo con menos supuestos?

**Datos verificados que hay que usar (no re-derivar de cero):**
- Voto de PoAS = 484 B (`d12-quorum/informe.md` §F.1); certificado BLS agregado = 724 B y Ed25519 =
  264 128 B a `K=4000` (`f1-p040-latencia.md` §6.2, verificado por D9).
- Gossip a `K=4000`/30 s = **2,04 TB/año** con 1 voto de 484 B; 6,1–8,1 con 3–4 votos
  (`audita-d9.md` cifra 19). Escala lineal con la cadencia: a 5 s son 12,2 TB/año, a 1 s 61 TB/año.
- Latencia = espera `[0, c]` + `T_cons` (3–4 entregas BFT); media `c/2 + T_cons`
  (`audita-d9.md` §3.3). `Δ` inicial de F3 = 6 s (`fip-0086.md:713`); timeout `2Δ` (`:441`).
- Umbrales: viveza `p ≥ (2/3)/(1−α)`; seguridad `α < ⅓`; `α ≤ 28,2 %` para riesgo anual 1e-6 a
  `K=4000` y 30 s (`verifica_d13.py`).

**Trabajo.**
1. **Modelo de tráfico por nodo** en función de `c`, `K`, tamaño de mensaje y topología:
   (a) gossip completo de votos; (b) líder/agregador por instancia (K votos al líder + certificado
   de 724 B difundido); (c) agregación jerárquica. Con presupuestos de subida de 50 Mbps, 1 Gbps y
   10 Gbps, calcula el **mínimo `c` viable** para `K ∈ {500, 1000, 2000, 4000}`.
2. **Modelo de latencia**: `c/2 + T_cons` y cota `c + T_cons` para `c ∈ {30,10,5,2,1}` y
   `Δ ∈ {1,4,6,16}`. Tabla de irreversibilidad mínima y media.
3. **Motores**: compara GossiPBFT, Simplex (ePrint 2023/463), BA\* (arXiv:1607.01341) y Cordial
   Miners (arXiv:2205.09174): rondas, complejidad de mensajes, recuperación tras parada,
   targetabilidad del comité (BA\* con sortición secreta por paso), y si alguno permite cadencia
   corta sin multiplicar el gossip.
4. **Seguridad y viveza**: umbral ⅓, `p` de encendido, probabilidad de parada por instancia y
   recuperación; qué pasa con el comité público (targeteable) y con `m` anclas.
5. **Frontera de Pareto**: para cada presupuesto de red, la tupla `(c, K, motor)` que minimiza la
   irreversibilidad sin romper el umbral. Di explícitamente el punto que recomiendas y su coste.

**Entregable:** `research/scripts/d14-instancia/informe.md` incremental (commit por punto, solo tu
directorio, sin push), scripts y salidas, `AUDITA_SCRIPTS.py` pasado, `## Veredicto` con etiquetas
y `## Errores propios`. Devuelve el mínimo de irreversibilidad alcanzable con número y condiciones.
