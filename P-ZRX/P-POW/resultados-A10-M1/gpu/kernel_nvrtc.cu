// ORDEN-A10-M1 / CORRECCION-A10-M1-A — núcleo Keccak-f[1600]/SHA3-256 de un bloque, para compilar en
// tiempo de ejecución con NVRTC (`--gpu-architecture=compute_61`). A propósito **no incluye ninguna
// cabecera**, ni siquiera de CUDA: NVRTC ya expone `__global__`, `__device__`, los tipos enteros de
// ancho fijo y las funciones atómicas como builtins del compilador, y la ORDEN pide explícitamente
// que el núcleo no arrastre cabeceras del sistema (el problema de la ronda 1 era el *anfitrión*
// C++/nvcc, no el núcleo).
//
// Misma matemática, mismos offsets y misma convención de bytes que
// `deepseek/A10M1/gpu/pow_gpu.cu` (ronda 1, nunca compilado) y que la referencia Rust
// `deepseek/A10M1/repo/crates/zx-core/examples/bench_pow.rs`: hardware little-endian (x86 y NVIDIA),
// así que los 200 bytes de estado se tratan como 25 palabras de 64 bits sin conversión de
// endianness. El nonce (C-HDR-04) ocupa exactamente el lane 12 de los 17 lanes de *rate*.

typedef unsigned char u8;
typedef unsigned int u32;
typedef unsigned long long u64;

__device__ __forceinline__ u64 rotl64(u64 x, int n) { return (x << n) | (x >> (64 - n)); }

__device__ __constant__ u64 RNDC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
    0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL};

__device__ __forceinline__ void keccakf(u64 st[25]) {
    const int rotc[24] = {1,  3,  6,  10, 15, 21, 28, 36, 45, 55, 2,  14,
                           27, 41, 56, 8,  25, 43, 62, 18, 39, 61, 20, 44};
    const int piln[24] = {10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4,
                           15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1};
    u64 bc[5];
    for (int round = 0; round < 24; round++) {
        for (int i = 0; i < 5; i++) bc[i] = st[i] ^ st[i + 5] ^ st[i + 10] ^ st[i + 15] ^ st[i + 20];
        for (int i = 0; i < 5; i++) {
            u64 t = bc[(i + 4) % 5] ^ rotl64(bc[(i + 1) % 5], 1);
            for (int j = 0; j < 25; j += 5) st[j + i] ^= t;
        }
        u64 t = st[1];
        for (int i = 0; i < 24; i++) {
            int j = piln[i];
            u64 tmp = st[j];
            st[j] = rotl64(t, rotc[i]);
            t = tmp;
        }
        for (int j = 0; j < 25; j += 5) {
            u64 b0 = st[j], b1 = st[j + 1], b2 = st[j + 2], b3 = st[j + 3], b4 = st[j + 4];
            st[j] = b0 ^ (~b1 & b2);
            st[j + 1] = b1 ^ (~b2 & b3);
            st[j + 2] = b2 ^ (~b3 & b4);
            st[j + 3] = b3 ^ (~b4 & b0);
            st[j + 4] = b4 ^ (~b0 & b1);
        }
        st[0] ^= RNDC[round];
    }
}

__device__ __forceinline__ void sha3_256_from_lanes(const u64 rate[17], u8 out[32]) {
    u64 st[25];
    for (int i = 0; i < 17; i++) st[i] = rate[i];
    for (int i = 17; i < 25; i++) st[i] = 0;
    keccakf(st);
    u8* p = (u8*)st;
    for (int i = 0; i < 32; i++) out[i] = p[i];
}

// Construye los 17 lanes de un mensaje de longitud `len<=135` con el relleno multi-rate de SHA3
// (dominio 0x06, ceros, 0x80 en el último byte del bloque de 136).
__device__ __forceinline__ void lanes_1block(const u8* msg, u32 len, u64 rate[17]) {
    u8 buf[136];
    for (int i = 0; i < 136; i++) buf[i] = 0;
    for (u32 i = 0; i < len; i++) buf[i] = msg[i];
    buf[len] ^= 0x06;
    buf[135] ^= 0x80;
    u64* lanes = (u64*)buf;
    for (int i = 0; i < 17; i++) rate[i] = lanes[i];
}

// ── Validación (a): vectores NIST CAVP de un bloque, uno por hilo ──
extern "C" __global__ void k_validar_vectores(const u8* d_msgs, const u32* d_lens, int n, u8* d_out) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    u64 rate[17];
    lanes_1block(d_msgs + i * 136, d_lens[i], rate);
    sha3_256_from_lanes(rate, d_out + i * 32);
}

// ── Validación (b) / modo dump: nonce = splitmix64(seed) tras (i+1) pasos, aplicado al lane 12 ──
extern "C" __global__ void k_dump(const u64* tpl, u64 seed, u64 count, u8* out) {
    u64 i = (u64)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= count) return;
    const u64 INC = 0x9E3779B97F4A7C15ULL;
    u64 state = seed + (i + 1) * INC;
    u64 z = state;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    u64 nonce = z ^ (z >> 31);

    u64 rate[17];
    for (int k = 0; k < 17; k++) rate[k] = tpl[k];
    rate[12] = nonce;
    sha3_256_from_lanes(rate, out + i * 32);
}

// ── Validación (c): nonce mínimo con >= bits_cero bits altos a cero (C-POW-01, big-endian) ──
extern "C" __global__ void k_search(const u64* tpl, u64 max_nonce, u32 bits_cero,
                                     unsigned long long* out_min_nonce) {
    u64 nonce = (u64)blockIdx.x * blockDim.x + threadIdx.x;
    if (nonce >= max_nonce) return;
    u64 rate[17];
    for (int k = 0; k < 17; k++) rate[k] = tpl[k];
    rate[12] = nonce;
    u8 out[32];
    sha3_256_from_lanes(rate, out);
    u32 cero = 0;
    for (int b = 0; b < 32; b++) {
        if (out[b] == 0) {
            cero += 8;
        } else {
            for (int bit = 7; bit >= 0; bit--) {
                if (out[b] & (1 << bit)) break;
                cero++;
            }
            break;
        }
    }
    if (cero >= bits_cero) atomicMin(out_min_nonce, (unsigned long long)nonce);
}

// ── Banco: cada hilo prueba `iters` nonces consecutivos (paso = nº total de hilos), comparando
// contra un target imposible (todo ceros) como un minero real, para que el compilador no pueda
// eliminar el cálculo por código muerto. ──
extern "C" __global__ void k_bench(const u64* tpl, u64 iters, u64 nonce_base,
                                    unsigned long long* d_hits) {
    u64 tid = (u64)blockIdx.x * blockDim.x + threadIdx.x;
    u64 stride = (u64)gridDim.x * blockDim.x;
    u64 rate[17];
    for (int k = 0; k < 17; k++) rate[k] = tpl[k];
    u64 nonce = nonce_base + tid;
    unsigned long long impactos = 0;
    for (u64 it = 0; it < iters; it++) {
        rate[12] = nonce;
        u8 out[32];
        sha3_256_from_lanes(rate, out);
        int cero = 1;
        for (int b = 0; b < 32; b++) cero &= (out[b] == 0);
        if (cero) impactos++;
        nonce += stride;
    }
    if (impactos) atomicAdd(d_hits, impactos);
}
