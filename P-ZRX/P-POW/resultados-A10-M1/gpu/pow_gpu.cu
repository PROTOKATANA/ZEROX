// ORDEN-A10-M1 — núcleo CUDA de Keccak-f[1600]/SHA3-256 de un solo bloque, para medir el hashrate
// GPU del `hash_pow` dev de ZEROX (Sha3Dev = SHA3-256 de `BlockHeader::preimagen_pow()`, 108 bytes,
// que caben en un único bloque de *rate* de 136 bytes — ver
// crates/zx-core/src/preimage/block.rs).
//
// No es código de consenso ni se migra: vive solo en `deepseek/A10M1/gpu/`. La preimagen exacta se
// recibe en hex por línea de comandos, generada por `bench_pow preimagen-hex` (el mismo binario
// Rust que sirve de referencia CPU), para no transcribir a mano los 108 bytes y evitar así una
// segunda fuente de verdad que pueda divergir en silencio.
//
// Contrato de consenso que este fichero respeta (C-HDR-04): el nonce ocupa exactamente los bytes
// [96, 104) de la preimagen, codificado little-endian. Esos 8 bytes son, además, exactamente el
// lane 12 de los 17 lanes de *rate* de SHA3-256 (96/8 = 12), así que variar el nonce es una única
// asignación `lanes[12] = nonce` sobre la plantilla precomputada — no hace falta reconstruir ni
// repadear el bloque en cada intento.

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <chrono>
#include <fstream>
#include <sstream>

#include <cuda_runtime.h>

#define CUDA_CHECK(expr)                                                                         \
    do {                                                                                          \
        cudaError_t _e = (expr);                                                                  \
        if (_e != cudaSuccess) {                                                                  \
            std::fprintf(stderr, "CUDA error %s:%d: %s\n", __FILE__, __LINE__,                    \
                         cudaGetErrorString(_e));                                                  \
            std::exit(1);                                                                          \
        }                                                                                          \
    } while (0)

// ───────────────────────────── Keccak-f[1600], 24 rondas ─────────────────────────────
// Constantes estándar (FIPS 202 / Keccak reference). Se autocomprueban en `selftest` contra
// SHA3-256("") = a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a y contra los
// vectores NIST CAVP de un bloque — no se publica ninguna cifra si esa comprobación falla.

__device__ __host__ __forceinline__ uint64_t rotl64(uint64_t x, int n) {
    return (x << n) | (x >> (64 - n));
}

__device__ __constant__ uint64_t d_rndc[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
    0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL};

static const uint64_t h_rndc[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
    0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL};

__device__ __host__ __forceinline__ void keccakf(uint64_t st[25], const uint64_t* rndc) {
    static const int rotc[24] = {1,  3,  6,  10, 15, 21, 28, 36, 45, 55, 2,  14,
                                  27, 41, 56, 8,  25, 43, 62, 18, 39, 61, 20, 44};
    static const int piln[24] = {10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4,
                                  15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1};
    uint64_t bc[5];
    for (int round = 0; round < 24; round++) {
        for (int i = 0; i < 5; i++) bc[i] = st[i] ^ st[i + 5] ^ st[i + 10] ^ st[i + 15] ^ st[i + 20];
        for (int i = 0; i < 5; i++) {
            uint64_t t = bc[(i + 4) % 5] ^ rotl64(bc[(i + 1) % 5], 1);
            for (int j = 0; j < 25; j += 5) st[j + i] ^= t;
        }
        uint64_t t = st[1];
        for (int i = 0; i < 24; i++) {
            int j = piln[i];
            uint64_t tmp = st[j];
            st[j] = rotl64(t, rotc[i]);
            t = tmp;
        }
        for (int j = 0; j < 25; j += 5) {
            uint64_t b0 = st[j], b1 = st[j + 1], b2 = st[j + 2], b3 = st[j + 3], b4 = st[j + 4];
            st[j] = b0 ^ (~b1 & b2);
            st[j + 1] = b1 ^ (~b2 & b3);
            st[j + 2] = b2 ^ (~b3 & b4);
            st[j + 3] = b3 ^ (~b4 & b0);
            st[j + 4] = b4 ^ (~b0 & b1);
        }
        st[0] ^= rndc[round];
    }
}

// Rate de SHA3-256: 136 bytes = 17 lanes de 64 bits. Capacity: 64 bytes = 8 lanes (quedan a 0 en
// un mensaje de un solo bloque). Hardware de referencia (x86 y NVIDIA) es little-endian, así que
// los 200 bytes del estado se tratan directamente como 25 uint64 sin conversión de endianness
// (igual que hace la implementación de referencia de Keccak).
__device__ __host__ __forceinline__ void sha3_256_1block_from_lanes(const uint64_t rate[17],
                                                                      const uint64_t* rndc,
                                                                      uint8_t out[32]) {
    uint64_t st[25];
    for (int i = 0; i < 17; i++) st[i] = rate[i];
    for (int i = 17; i < 25; i++) st[i] = 0;
    keccakf(st, rndc);
    std::memcpy(out, st, 32);
}

// Construye los 17 lanes de *rate* de un mensaje de longitud `len <= 135` con el relleno SHA3
// multi-rate (dominio 0x06, ceros, 0x80 en el último byte del rate) — C-HASH-01/FIPS 202 §B.2.
__host__ void construir_lanes_1block(const uint8_t* msg, size_t len, uint64_t rate[17]) {
    uint8_t buf[136];
    std::memset(buf, 0, sizeof(buf));
    std::memcpy(buf, msg, len);
    buf[len] ^= 0x06;
    buf[135] ^= 0x80;
    std::memcpy(rate, buf, 136);
}

// ───────────────────────────── utilidades de hex/host ─────────────────────────────

static std::vector<uint8_t> hex_a_bytes(const std::string& h) {
    std::vector<uint8_t> out(h.size() / 2);
    for (size_t i = 0; i < out.size(); i++) out[i] = (uint8_t)std::stoul(h.substr(i * 2, 2), nullptr, 16);
    return out;
}

static std::string bytes_a_hex(const uint8_t* b, size_t n) {
    static const char* d = "0123456789abcdef";
    std::string s(n * 2, '0');
    for (size_t i = 0; i < n; i++) {
        s[2 * i] = d[b[i] >> 4];
        s[2 * i + 1] = d[b[i] & 0xf];
    }
    return s;
}

// splitmix64 — idéntico al de `bench_pow.rs`, dominio público (Vigna 2015). Sirve solo para generar
// una secuencia de nonces determinista y reproducible entre CPU y GPU (validación (b)).
__device__ __host__ __forceinline__ uint64_t splitmix64_next(uint64_t& state) {
    state += 0x9E3779B97F4A7C15ULL;
    uint64_t z = state;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

// ───────────────────────────── kernels ─────────────────────────────

__device__ __forceinline__ void construir_lanes_1block_device(const uint8_t* msg, uint32_t len,
                                                                uint64_t rate[17]);

// Validación (a): un vector por hilo, mensaje de longitud variable (<=135) ya paddeado en `d_msgs`
// (cada uno ocupa 136 bytes fijos, con `d_lens` la longitud real).
__global__ void k_validar_vectores(const uint8_t* d_msgs, const uint32_t* d_lens, int n,
                                    uint8_t* d_out) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    uint64_t rate[17];
    construir_lanes_1block_device(d_msgs + i * 136, d_lens[i], rate);
    sha3_256_1block_from_lanes(rate, d_rndc, d_out + i * 32);
}

// Validación (b) y modo `dump`: nonce = splitmix64(seed) iterado `count` veces, hash_pow con ese
// nonce en el lane 12 de la plantilla fija.
__global__ void k_dump(uint64_t base_lanes12, const uint64_t* tpl, uint64_t seed, uint64_t count,
                        uint8_t* out) {
    uint64_t i = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= count) return;
    // Generador secuencial por índice: replica splitmix64 aplicado `i+1` veces desde `seed`.
    // Para no rehacer `i` iteraciones por hilo (coste O(n^2)), usamos la propiedad de que
    // splitmix64 es un contador con salto fijo: el i-ésimo estado interno es
    // seed + (i+1)*INC (mod 2^64), y el valor de salida se deriva solo del estado. Esto es
    // EXACTAMENTE lo que hace la referencia Rust, que llama splitmix64_next() n veces seguidas
    // desde el mismo `seed` mutable: el estado tras k llamadas es seed + k*INC.
    const uint64_t INC = 0x9E3779B97F4A7C15ULL;
    uint64_t state = seed + (i + 1) * INC;
    uint64_t z = state;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    uint64_t nonce = z ^ (z >> 31);

    uint64_t rate[17];
    for (int k = 0; k < 17; k++) rate[k] = tpl[k];
    rate[12] = nonce;
    sha3_256_1block_from_lanes(rate, d_rndc, out + i * 32);
}

// Validación (c): búsqueda del nonce mínimo cuyo hash (interpretado big-endian, C-POW-01) tiene al
// menos `bits_cero` bits altos a cero. Cada hilo prueba un nonce distinto; se reduce con atomicMin.
__global__ void k_search(const uint64_t* tpl, uint64_t max_nonce, uint32_t bits_cero,
                          unsigned long long* out_min_nonce) {
    uint64_t nonce = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (nonce >= max_nonce) return;
    uint64_t rate[17];
    for (int k = 0; k < 17; k++) rate[k] = tpl[k];
    rate[12] = nonce;
    uint8_t out[32];
    sha3_256_1block_from_lanes(rate, d_rndc, out);
    // Interpretación big-endian del digest (C-POW-01): el byte más significativo es out[31] porque
    // el squeeze de Keccak vuelca los lanes en little-endian nativo y el propio digest de 32 bytes
    // se compara "tal cual" contra el target en la implementación Rust (BlockHash::as_bytes(), que
    // son los bytes del array `[u8;32]` en el orden de salida de `Sha3_256::finalize()`, es decir,
    // MSB-first estándar de SHA3). Aquí replicamos la misma convención byte a byte.
    uint32_t cero = 0;
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
    if (cero >= bits_cero) {
        atomicMin(out_min_nonce, (unsigned long long)nonce);
    }
}

// Banco: bucle de rejilla, cada hilo prueba `iters` nonces consecutivos (paso = nº total de hilos),
// comparando contra un target imposible (como haría un minero real) para que el compilador no
// pueda eliminar el cálculo por código muerto. `d_hits` cuenta impactos (debería quedar en 0).
__global__ void k_bench(const uint64_t* tpl, uint64_t iters, uint64_t nonce_base,
                         unsigned long long* d_hits) {
    uint64_t tid = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    uint64_t stride = (uint64_t)gridDim.x * blockDim.x;
    uint64_t rate[17];
    for (int k = 0; k < 17; k++) rate[k] = tpl[k];
    uint64_t nonce = nonce_base + tid;
    unsigned long long impactos = 0;
    for (uint64_t it = 0; it < iters; it++) {
        rate[12] = nonce;
        uint8_t out[32];
        sha3_256_1block_from_lanes(rate, d_rndc, out);
        // Target imposible salvo colisión real de SHA3-256 (probabilidad ~0): los 32 bytes a cero.
        bool cero = true;
#pragma unroll
        for (int b = 0; b < 32; b++) cero &= (out[b] == 0);
        if (cero) impactos++;
        nonce += stride;
    }
    if (impactos) atomicAdd(d_hits, impactos);
}

// El `construir_lanes_1block` de host no sirve en __device__ (usa memset/memcpy de host en algunos
// toolkits sin problema, pero lo separamos explícito para claridad y para poder marcarlo con
// `__device__` sin depender de la implementación libc del host).
__device__ __forceinline__ void construir_lanes_1block_device(const uint8_t* msg, uint32_t len,
                                                                uint64_t rate[17]) {
    uint8_t buf[136];
#pragma unroll
    for (int i = 0; i < 136; i++) buf[i] = 0;
    for (uint32_t i = 0; i < len; i++) buf[i] = msg[i];
    buf[len] ^= 0x06;
    buf[135] ^= 0x80;
    uint64_t* lanes = (uint64_t*)buf;
#pragma unroll
    for (int i = 0; i < 17; i++) rate[i] = lanes[i];
}

// ───────────────────────────── host: modos ─────────────────────────────

static std::vector<uint64_t> preimagen_a_template(const std::string& hex) {
    auto bytes = hex_a_bytes(hex);
    if (bytes.size() != 108) {
        std::fprintf(stderr, "preimagen debe tener 108 bytes, tiene %zu\n", bytes.size());
        std::exit(1);
    }
    uint64_t rate[17];
    construir_lanes_1block(bytes.data(), bytes.size(), rate);
    return std::vector<uint64_t>(rate, rate + 17);
}

// Parser mínimo de .rsp NIST CAVP (Len/Msg/MD), sin Python, filtrando Len<=1080 bits (135 bytes:
// cabe en un solo bloque de rate junto con al menos 1 byte de padding).
struct Vector { std::vector<uint8_t> msg; std::vector<uint8_t> md; };

static std::vector<Vector> leer_rsp(const std::string& ruta) {
    std::vector<Vector> vs;
    std::ifstream f(ruta);
    if (!f) { std::fprintf(stderr, "no se pudo abrir %s\n", ruta.c_str()); std::exit(1); }
    std::string linea, msg_hex, md_hex;
    long len_bits = -1;
    bool tiene_msg = false;
    while (std::getline(f, linea)) {
        if (linea.rfind("Len = ", 0) == 0) { len_bits = std::stol(linea.substr(6)); tiene_msg = false; }
        else if (linea.rfind("Msg = ", 0) == 0) { msg_hex = linea.substr(6); tiene_msg = true; }
        else if (linea.rfind("MD = ", 0) == 0 && tiene_msg) {
            md_hex = linea.substr(5);
            if (len_bits >= 0 && len_bits <= 1080) {
                size_t nbytes = (size_t)((len_bits + 7) / 8);
                std::string mh = msg_hex.substr(0, nbytes * 2);
                Vector v;
                v.msg = hex_a_bytes(mh);
                v.msg.resize(nbytes);
                v.md = hex_a_bytes(md_hex);
                vs.push_back(v);
            }
            tiene_msg = false;
        }
    }
    return vs;
}

static void modo_selftest(const std::string& dir) {
    // 1) SHA3-256("") como ancla puntual (vector conocido, también está en ShortMsg.rsp Len=0).
    {
        uint64_t rate[17];
        construir_lanes_1block(nullptr, 0, rate);
        uint8_t out[32];
        sha3_256_1block_from_lanes(rate, h_rndc, out);
        std::string got = bytes_a_hex(out, 32);
        std::string exp = "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a";
        std::printf("ancla SHA3-256(\"\"): %s %s\n", got.c_str(), got == exp ? "OK" : "FALLO");
        if (got != exp) { std::exit(1); }
    }

    std::vector<std::string> ficheros = {
        dir + "/SHA3_256ShortMsg.rsp", dir + "/SHA3_256LongMsg.rsp"};
    std::vector<Vector> todos;
    for (auto& f : ficheros) {
        auto vs = leer_rsp(f);
        std::printf("%s: %zu vectores con Len<=1080 bits\n", f.c_str(), vs.size());
        for (auto& v : vs) todos.push_back(v);
    }
    int n = (int)todos.size();
    std::vector<uint8_t> h_msgs(n * 136, 0);
    std::vector<uint32_t> h_lens(n);
    for (int i = 0; i < n; i++) {
        std::memcpy(&h_msgs[i * 136], todos[i].msg.data(), todos[i].msg.size());
        h_lens[i] = (uint32_t)todos[i].msg.size();
    }
    uint8_t *d_msgs, *d_out; uint32_t* d_lens;
    CUDA_CHECK(cudaMalloc(&d_msgs, h_msgs.size()));
    CUDA_CHECK(cudaMalloc(&d_lens, h_lens.size() * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&d_out, (size_t)n * 32));
    CUDA_CHECK(cudaMemcpy(d_msgs, h_msgs.data(), h_msgs.size(), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_lens, h_lens.data(), h_lens.size() * sizeof(uint32_t), cudaMemcpyHostToDevice));
    int threads = 128, blocks = (n + threads - 1) / threads;
    k_validar_vectores<<<blocks, threads>>>(d_msgs, d_lens, n, d_out);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    std::vector<uint8_t> h_out((size_t)n * 32);
    CUDA_CHECK(cudaMemcpy(h_out.data(), d_out, h_out.size(), cudaMemcpyDeviceToHost));
    int ok = 0, fallo = 0;
    for (int i = 0; i < n; i++) {
        if (std::memcmp(&h_out[i * 32], todos[i].md.data(), 32) == 0) ok++;
        else { fallo++; if (fallo <= 5) std::printf("FALLO vector %d (len=%zu bytes)\n", i, todos[i].msg.size()); }
    }
    std::printf("validacion (a): %d/%d vectores NIST CAVP correctos (%d fallos)\n", ok, n, fallo);
    CUDA_CHECK(cudaFree(d_msgs)); CUDA_CHECK(cudaFree(d_lens)); CUDA_CHECK(cudaFree(d_out));
    if (fallo != 0) std::exit(1);
}

static void modo_dump(const std::string& preimagen_hex, uint64_t seed, uint64_t n, const std::string& outfile) {
    auto tpl = preimagen_a_template(preimagen_hex);
    uint64_t* d_tpl; uint8_t* d_out;
    CUDA_CHECK(cudaMalloc(&d_tpl, 17 * sizeof(uint64_t)));
    CUDA_CHECK(cudaMalloc(&d_out, n * 32));
    CUDA_CHECK(cudaMemcpy(d_tpl, tpl.data(), 17 * sizeof(uint64_t), cudaMemcpyHostToDevice));
    int threads = 256; uint64_t blocks = (n + threads - 1) / threads;
    k_dump<<<(unsigned)blocks, threads>>>(0, d_tpl, seed, n, d_out);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    std::vector<uint8_t> h_out(n * 32);
    CUDA_CHECK(cudaMemcpy(h_out.data(), d_out, h_out.size(), cudaMemcpyDeviceToHost));
    std::ofstream f(outfile, std::ios::binary);
    f.write((const char*)h_out.data(), h_out.size());
    std::printf("dump: %llu digests escritos en %s (seed=%llu)\n", (unsigned long long)n, outfile.c_str(), (unsigned long long)seed);
    CUDA_CHECK(cudaFree(d_tpl)); CUDA_CHECK(cudaFree(d_out));
}

static void modo_search(const std::string& preimagen_hex, uint32_t bits_cero, uint64_t max_nonce) {
    auto tpl = preimagen_a_template(preimagen_hex);
    uint64_t* d_tpl; unsigned long long* d_min;
    unsigned long long h_min = UINT64_MAX;
    CUDA_CHECK(cudaMalloc(&d_tpl, 17 * sizeof(uint64_t)));
    CUDA_CHECK(cudaMalloc(&d_min, sizeof(unsigned long long)));
    CUDA_CHECK(cudaMemcpy(d_tpl, tpl.data(), 17 * sizeof(uint64_t), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_min, &h_min, sizeof(h_min), cudaMemcpyHostToDevice));
    int threads = 256; uint64_t blocks = (max_nonce + threads - 1) / threads;
    k_search<<<(unsigned)blocks, threads>>>(d_tpl, max_nonce, bits_cero, d_min);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(&h_min, d_min, sizeof(h_min), cudaMemcpyDeviceToHost));
    if (h_min == UINT64_MAX) { std::printf("search: sin resultado hasta max_nonce=%llu\n", (unsigned long long)max_nonce); }
    else {
        uint64_t rate[17];
        std::memcpy(rate, tpl.data(), 17*sizeof(uint64_t));
        rate[12] = h_min;
        uint8_t out[32];
        sha3_256_1block_from_lanes(rate, h_rndc, out);
        std::printf("search: nonce=%llu hash=%s\n", h_min, bytes_a_hex(out,32).c_str());
    }
    CUDA_CHECK(cudaFree(d_tpl)); CUDA_CHECK(cudaFree(d_min));
}

static void modo_bench(const std::string& preimagen_hex, double duracion_s, int blocks, int threads, int reps) {
    auto tpl = preimagen_a_template(preimagen_hex);
    uint64_t* d_tpl; unsigned long long* d_hits;
    CUDA_CHECK(cudaMalloc(&d_tpl, 17 * sizeof(uint64_t)));
    CUDA_CHECK(cudaMalloc(&d_hits, sizeof(unsigned long long)));
    CUDA_CHECK(cudaMemcpy(d_tpl, tpl.data(), 17 * sizeof(uint64_t), cudaMemcpyHostToDevice));
    uint64_t total_hilos = (uint64_t)blocks * threads;

    // Calibración corta para fijar `iters` por lanzamiento (~0.5 s de kernel) y no perder tiempo en
    // sincronizaciones de host demasiado frecuentes ni pasarnos de la duración objetivo.
    uint64_t iters_lote = 20000;
    {
        unsigned long long zero = 0;
        CUDA_CHECK(cudaMemcpy(d_hits, &zero, sizeof(zero), cudaMemcpyHostToDevice));
        auto t0 = std::chrono::steady_clock::now();
        k_bench<<<blocks, threads>>>(d_tpl, iters_lote, 0, d_hits);
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaDeviceSynchronize());
        auto t1 = std::chrono::steady_clock::now();
        double s = std::chrono::duration<double>(t1 - t0).count();
        double objetivo = 0.5;
        double factor = objetivo / std::max(s, 1e-6);
        iters_lote = (uint64_t)std::max(1000.0, iters_lote * factor);
    }

    for (int r = 1; r <= reps; r++) {
        unsigned long long zero = 0;
        CUDA_CHECK(cudaMemcpy(d_hits, &zero, sizeof(zero), cudaMemcpyHostToDevice));
        uint64_t total_hashes = 0;
        uint64_t nonce_base = 0;
        auto t0 = std::chrono::steady_clock::now();
        double transcurrido = 0;
        while (transcurrido < duracion_s) {
            k_bench<<<blocks, threads>>>(d_tpl, iters_lote, nonce_base, d_hits);
            CUDA_CHECK(cudaGetLastError());
            CUDA_CHECK(cudaDeviceSynchronize());
            total_hashes += total_hilos * iters_lote;
            nonce_base += total_hilos * iters_lote;
            transcurrido = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
        }
        unsigned long long hits = 0;
        CUDA_CHECK(cudaMemcpy(&hits, d_hits, sizeof(hits), cudaMemcpyDeviceToHost));
        std::printf("rep=%d blocks=%d threads=%d hashes=%llu segundos=%.6f hs=%.3f hits=%llu\n",
                    r, blocks, threads, (unsigned long long)total_hashes, transcurrido,
                    total_hashes / transcurrido, hits);
    }
    CUDA_CHECK(cudaFree(d_tpl)); CUDA_CHECK(cudaFree(d_hits));
}

int main(int argc, char** argv) {
    if (argc < 2) { std::fprintf(stderr, "modo requerido\n"); return 1; }
    std::string modo = argv[1];
    if (modo == "selftest") {
        modo_selftest(argv[2]);
    } else if (modo == "dump") {
        modo_dump(argv[2], std::stoull(argv[3]), std::stoull(argv[4]), argv[5]);
    } else if (modo == "search") {
        modo_search(argv[2], (uint32_t)std::stoul(argv[3]), std::stoull(argv[4]));
    } else if (modo == "bench") {
        modo_bench(argv[2], std::stod(argv[3]), std::stoi(argv[4]), std::stoi(argv[5]), std::stoi(argv[6]));
    } else {
        std::fprintf(stderr, "modo desconocido: %s\n", modo.c_str());
        return 1;
    }
    return 0;
}
