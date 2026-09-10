#!/usr/bin/env python3
r"""
d14k_lib.py — Núcleo FIEL de DAGKNIGHT (Alg. 3/5/6) para D14B.

La primera pasada (informe.md) midió un `k*` crudo = "mínimo k con cobertura global
>= 50 %" (adaptación propia). El paper define otra cosa:

  · Alg. 5 K-Colouring(C,G,k,free_search): coloración voraz recursiva que devuelve el
    k-cluster de past_G(C) y su k-chain.
  · Alg. 6 UMC-Voting(G,U,e): votación en cascada (SPECTRE) que decide si U es un
    e-UMC de G (Def. 6: genesis(G) ∈ U y para todo B ∈ U,
    |future(B)∩U| + e >= |future(B)∩(G\U)|).
  · Alg. 3 Calculate-Rank(P,G): mínimo k tal que para algún representante r de P,
    C_k(r) cumple UMC-Voting(G\future(r), C_k(r), g(k)) > 0, con g(k)=isqrt(k).
  · Alg. 4 Tie-Breaking: desempate por el número de bloques del cluster libre F_{g(k)}
    cuyo anticono corta la k-chain del candidato más de k' veces.

Fidelidad y simplificaciones declaradas (afectan a Order-DAG, no al rank):
  S1 · `agrees(B,C)` = "B está en la cadena de C" (Def. 3: {B,C} yace sobre una sola
       cadena). La cadena global usada es la sp de GHOSTDAG (r8c_gd, fiel a
       rusty-kaspa), no la cadena que elegiría Order-DAG.
  S2 · rank_G(C) de la línea 9 de Alg. 5 se toma = +inf: los padres que no están en
       la cadena solo se heredan con free_search.
  S3 · Calculate-Rank usa como representantes los propios tips de P (los maximales);
       la Def. 4 admite todo past(P)\past(otros tips). Menos representantes solo puede
       SUBIR el rank medido (cota superior).
  S4 · El desempate "hash-based" usa el id de creación del bloque (proxy de hash).
  S5 · Order-DAG (Alg. 2) completo NO se ejecuta; Tie-Breaking (Alg. 4) se implementa
       de forma aislada para D8b (mitigación).
"""
import math

GEN = 0


def popcount(x):
    return bin(x).count("1")


def iter_bits(mask):
    """Bits de menor a mayor = orden topológico (los ids se asignan en orden topológico)."""
    while mask:
        low = mask & -mask
        yield low.bit_length() - 1
        mask ^= low


class KDag:
    """DAG inmutable con reachability por máscaras. Ids en orden topológico, 0 = genesis."""

    def __init__(self, parents, times=None, creators=None):
        self.n = len(parents)
        self.parents = [tuple(p) for p in parents]
        self.times = list(times) if times is not None else [0.0] * self.n
        self.creators = list(creators) if creators is not None else ["h"] * self.n
        children = [[] for _ in range(self.n)]
        for i, ps in enumerate(self.parents):
            for p in ps:
                children[p].append(i)
        self.children = children
        past = [0] * self.n
        for i in range(self.n):
            m = 0
            for p in self.parents[i]:
                m |= past[p] | (1 << p)
            past[i] = m
        self.past = past
        fut = [0] * self.n
        for i in range(self.n - 1, -1, -1):
            m = 0
            for c in children[i]:
                m |= fut[c] | (1 << c)
            fut[i] = m
        self.future = fut
        self.chain_parent = [None] * self.n
        self.chain_depth = [0] * self.n
        self.full = (1 << self.n) - 1

    # ---------- cadena ----------
    def set_chain(self, cp):
        """cp[i] = id del chain-parent de i (None solo para genesis)."""
        self.chain_parent = list(cp)
        d = [0] * self.n
        for i in range(1, self.n):
            p = cp[i]
            d[i] = 0 if p is None else d[p] + 1
        self.chain_depth = d

    def in_chain(self, a, b):
        """¿a está en la cadena de b (incluido a == b)?"""
        while b is not None:
            if b == a:
                return True
            b = self.chain_parent[b]
        return False

    def agrees(self, a, b):
        """Def. 3 para el par {a,b}: yacen sobre una sola cadena."""
        if a == b:
            return True
        return self.in_chain(a, b) or self.in_chain(b, a)

    def chain_lca(self, a, b):
        da, db = self.chain_depth[a], self.chain_depth[b]
        while da > db:
            a = self.chain_parent[a]
            da -= 1
        while db > da:
            b = self.chain_parent[b]
            db -= 1
        while a != b:
            a = self.chain_parent[a]
            b = self.chain_parent[b]
        return a

    # ---------- conjuntos ----------
    def anticone(self, x, ctx):
        return ctx & ~self.past[x] & ~self.future[x] & ~(1 << x)

    def tips_mask(self, ctx=None):
        ctx = self.full if ctx is None else ctx
        m = 0
        for i in range(self.n):
            if (ctx >> i) & 1 and not (self.future[i] & ctx):
                m |= 1 << i
        return m


class KColouring:
    """Alg. 5 + Alg. 6 + Alg. 3 sobre un KDag con cadena fijada (S1-S3)."""

    def __init__(self, d):
        self.d = d
        self._clu = {}          # (C,k,free,ctx) -> (blue_mask, chain_mask)

    # ---------------- Alg. 5 ----------------
    def _agrees(self, a, b, g):
        """Def. 3 relativa al conflict genesis g: a y b comparten un ancestro de cadena
        estrictamente por encima de g (mismo 'next chain ancestor' tras g)."""
        if a == b or a == g or b == g:
            return True
        l = self.d.chain_lca(a, b)
        return l != g

    def cluster(self, C, k, free, ctx=None, g=0):
        """K-Colouring(C, G, k, free). ctx por defecto = past(C); g = conflict genesis."""
        d = self.d
        if ctx is None:
            ctx = d.past[C]
        key = (C, k, free, ctx, g)
        hit = self._clu.get(key)
        if hit is not None:
            return hit
        if (d.past[C] & ctx) == 0:
            self._clu[key] = (0, 0)
            return 0, 0
        P = []
        for B in d.parents[C]:
            if not ((ctx >> B) & 1):
                continue
            if self._agrees(B, C, g):
                blueB, chainB = self.cluster(B, k, free, d.past[B] & ctx, g)
                P.append((B, blueB, chainB))
            elif free:                       # S2: rank_G(C) = +inf
                blueB, chainB = self.cluster(B, k, True, d.past[B] & ctx, g)
                P.append((B, blueB, chainB))
        if not P:
            self._clu[key] = (0, 0)
            return 0, 0
        Bmax, blueMax, chainMax = max(P, key=lambda t: (popcount(t[1]), -t[0]))
        blue = blueMax | (1 << Bmax)
        chain = chainMax | (1 << Bmax)
        for B in iter_bits(d.anticone(Bmax, ctx)):
            if popcount(chain & d.anticone(B, ctx)) <= k and \
               popcount(blue & d.anticone(Bmax, ctx)) < k:
                blue |= 1 << B
        self._clu[key] = (blue, chain)
        return blue, chain

    # ---------------- Alg. 6 ----------------
    def _vote_rec(self, B, ctx, S, e, memo):
        key = (B, S, ctx, e)
        hit = memo.get(key)
        if hit is not None:
            return hit
        fb = self.d.future[B] & ctx
        Sb = S & fb
        val = 0
        if Sb:
            for C in iter_bits(Sb):
                val += self._vote_rec(C, ctx, S, e, memo)
        res = 1 if val - popcount(fb & ~S) + e >= 0 else -1
        memo[key] = res
        return res

    def umc_voting(self, ctx, S, e):
        """Alg. 6: v = suma_B∈U UMC-Voting(future(B), U∩future(B), e);
        devuelve sign(v − |ctx\\U| + e)."""
        if S == 0:
            return 1 if e >= 0 else -1
        memo = {}
        v = 0
        for B in iter_bits(S):
            v += self._vote_rec(B, ctx, S, e, memo)
        return 1 if v - popcount(ctx & ~S) + e >= 0 else -1

    # ---------------- Alg. 3 ----------------
    def rank_tips(self, tips_mask, ctx=None, kmax=80):
        """Calculate-Rank(tips, G). Devuelve (k, r, blue) o (None, None, None)."""
        d = self.d
        if ctx is None:
            ctx = d.full
        reps = [i for i in iter_bits(tips_mask) if (ctx >> i) & 1]
        for k in range(kmax + 1):
            e = math.isqrt(k)
            for r in reps:
                blue, _ = self.cluster(r, k, False, d.past[r] & ctx)
                if self.umc_voting(ctx & ~d.future[r], blue, e) > 0:
                    return k, r, blue
        return None, None, None

    def rank_dag(self, ctx=None, kmax=80):
        """Rank de la vista G = Calculate-Rank(tips(G), G)."""
        d = self.d
        if ctx is None:
            ctx = d.full
        return self.rank_tips(d.tips_mask(ctx), ctx, kmax)

    # ---------------- Alg. 6 con bloques GRISES (implementación práctica) ----------------
    def _vote_rec_gray(self, B, ctx, blue, red, e, memo):
        key = (B, blue, red, ctx, e)
        hit = memo.get(key)
        if hit is not None:
            return hit
        fb = self.d.future[B] & ctx
        Sb = blue & fb
        val = 0
        if Sb:
            for C in iter_bits(Sb):
                val += self._vote_rec_gray(C, ctx, blue, red, e, memo)
        res = 1 if val - popcount(fb & red) + e >= 0 else -1
        memo[key] = res
        return res

    def umc_voting_gray(self, ctx, blue, gray, e):
        """UMC-Voting con grises neutros: los no-azules que AGREGAN con el subgrupo
        no cuentan en contra (wiki DAGKnight cap. 03/06/08; equivalente práctico de los
        representantes de Alg. 3). Devuelve sign(Σ votos azules − |rojos| + e)."""
        red = ctx & ~blue & ~gray
        if blue == 0:
            return -1          # Def. 6 exige genesis(G) ∈ U
        memo = {}
        v = 0
        for B in iter_bits(blue):
            v += self._vote_rec_gray(B, ctx, blue, red, e, memo)
        return 1 if v - popcount(red) + e >= 0 else -1

    def rank_gray(self, ctx=None, kmax=80, g=None):
        """Rank de la vista G por subgrupos de tips que acuerdan, con el VSP de cada uno
        y bloques grises. `g` = conflict genesis (por defecto, LCA de cadena de los tips).
        Devuelve (k, vsp, blue, gray) del subgrupo de menor rank, o (None, ...)."""
        d = self.d
        if ctx is None:
            ctx = d.full
        tips = list(iter_bits(d.tips_mask(ctx)))
        if not tips:
            return 0, None, 0, 0
        if len(tips) == 1:
            cg = 0
        else:
            cg = tips[0]
            for t in tips[1:]:
                cg = d.chain_lca(cg, t)                     # sin conflicto: el rank se mide desde genesis
        if g is not None:
            cg = g

        def next_after(x):
            cur, prev = x, x
            while cur is not None and cur != cg:
                prev = cur
                cur = d.chain_parent[cur]
            return prev

        groups = {}
        for t in tips:
            groups.setdefault(next_after(t), []).append(t)
        # zona de conflicto = bloques >= cg (Future(CG) ∩ past(tips), CG incluido)
        zone = ctx & ~d.past[cg]
        best = None
        for gts in groups.values():
            vsp = max(gts, key=lambda t: (popcount(d.past[t] & zone), -t))
            for k in range(kmax + 1):
                blue, _ = self.cluster(vsp, k, False, d.past[vsp] & zone, cg)
                gray = 0
                for x in iter_bits(zone & ~blue):
                    if x != cg and d.chain_lca(x, vsp) != cg:
                        gray |= 1 << x
                e = math.isqrt(k)
                if self.umc_voting_gray(zone, blue, gray, e) > 0:
                    if best is None or k < best[0]:
                        best = (k, vsp, blue, gray)
                    break
        if best is None:
            return None, None, None, None
        return best


class VirtualColouring(KColouring):
    """Alg. 1 (vanilla M_kMC): cluster libre del bloque virtual, todos los tips como
    padres, free_search=True. Sirve de comparación con el rank de Alg. 3."""

    def cluster_virtual(self, k, free, ctx):
        d = self.d
        tips = [i for i in iter_bits(d.tips_mask(ctx))]
        key = ("V", k, free, ctx)
        hit = self._clu.get(key)
        if hit is not None:
            return hit
        if not tips:
            self._clu[key] = (0, 0)
            return 0, 0
        P = []
        for B in tips:
            blueB, chainB = self.cluster(B, k, free, d.past[B] & ctx)
            P.append((B, blueB, chainB))
        Bmax, blueMax, chainMax = max(P, key=lambda t: (popcount(t[1]), -t[0]))
        blue = blueMax | (1 << Bmax)
        chain = chainMax | (1 << Bmax)
        for B in iter_bits(d.anticone(Bmax, ctx)):
            if popcount(chain & d.anticone(B, ctx)) <= k and \
               popcount(blue & d.anticone(Bmax, ctx)) < k:
                blue |= 1 << B
        self._clu[key] = (blue, chain)
        return blue, chain

    def kmmc(self, ctx=None, kmax=80, frac=0.5):
        d = self.d
        if ctx is None:
            ctx = d.full
        total = popcount(ctx)
        for k in range(kmax + 1):
            blue, _ = self.cluster_virtual(k, True, ctx)
            if popcount(blue) >= frac * total:
                return k, blue
        return None, None


# =============================================================================================
# Constructores de DAG
# =============================================================================================
def paper_honest_dag(lam, T, D, seed):
    """DAG solo-honesto del paper (vista del cliente, atacante invisible): cada bloque
    referencia TODAS las puntas visibles; un honesto creado en t lo ven los demás en t+D.
    Tasa de creación = lam. Devuelve KDag (sin cadena; usar set_chain)."""
    import random
    rng = random.Random(seed)
    ev = []
    t = 0.0
    while True:
        t += rng.expovariate(lam)
        if t > T:
            break
        ev.append(t)
    parents = [tuple()]
    times = [0.0]
    vis = {GEN: 0.0}
    ids = {GEN: 0}
    for t in ev:
        visibles = {b for b in vis if vis[b] <= t}
        ref = set()
        for b in visibles:
            ref.update(parents[ids[b]])
        tips = sorted(visibles - ref, key=lambda b: ids[b])
        bid = len(parents)
        parents.append(tuple(ids[b] for b in tips))
        times.append(t)
        vis[bid] = t + D
        ids[bid] = bid
    return KDag(parents, times, ["g"] + ["h"] * (len(parents) - 1))


def kdag_from_r8c(d):
    """Convierte un DAG de r8c_gd (Mundo.corre) a KDag con la cadena sp de GHOSTDAG.
    Devuelve (kdag, mapa bid->id)."""
    order = list(d.B.keys())                # orden de inserción = topológico
    idx = {b: i for i, b in enumerate(order)}
    parents = [tuple(idx[p] for p in d.B[b].parents) for b in order]
    times = [d.B[b].t for b in order]
    creators = [d.B[b].creator for b in order]
    kd = KDag(parents, times, creators)
    cp = []
    for b in order:
        sp = d.gd[b].sp
        cp.append(None if sp is None else idx[sp])
    kd.set_chain(cp)
    return kd, idx


def chain_from_ghostdag(kdag):
    """Cadena por 'padre más pesado' (blue_work = nº de ancestros + 1) cuando no hay
    r8c_gd disponible. Se usa solo como fallback."""
    cp = [None] * kdag.n
    for i in range(1, kdag.n):
        ps = kdag.parents[i]
        if not ps:
            continue
        cp[i] = max(ps, key=lambda p: (popcount(kdag.past[p]) + 1, -p))
    kdag.set_chain(cp)
    return kdag


# =============================================================================================
# Cadenas honestas del atacante (máscaras por creador)
# =============================================================================================
def mask_honest(kd):
    m = 0
    for i in range(kd.n):
        if kd.creators[i] == "h":
            m |= 1 << i
    return m


def mask_attacker(kd):
    m = 0
    for i in range(kd.n):
        if kd.creators[i] == "a":
            m |= 1 << i
    return m


def cluster_honesty(blue, kd):
    """Fracción del cluster que es honesta (oráculo, solo para análisis)."""
    if blue == 0:
        return float("nan")
    h = popcount(blue & mask_honest(kd))
    return h / popcount(blue)

