# Procedencia de los vectores v0.1 — transición (W02b)

Copiados **sin editar** desde
`P-ZRX/P-TRANSICION/T01/resultados/vectores-transicion-v0.1.txt` y
`…-negativos-v0.1.txt` (T01-D, corrección F-15). Sus `sha256` coinciden con los fijados en
`P-ZRX/P-FORMATO/ENTRADA-W02b.sha256`:

```
0faec4a330b0ab96052b97c919b9e7bfa9ef494c2dd8fde25f38738658aa5527  vectores-transicion-v0.1.txt
9ca55abde96702f61ac0762e22f0a861d9ab0603a4090eda04ccd818eb0326ad  vectores-transicion-negativos-v0.1.txt
```

Los consumen `crates/zx-consensus/tests/diferencial_t01.rs` (tests `diferencial_t01` y
`diferencial_t01_negativos`). No se regeneran desde Rust.
