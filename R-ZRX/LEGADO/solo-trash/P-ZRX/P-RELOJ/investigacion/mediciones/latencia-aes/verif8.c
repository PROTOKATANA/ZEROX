// verif8.c — Coste de VERIFICAR un slot de PoT, medido en las tres rutas reales.
//
// Para qué: el PoT se verifica en 8 tramos INDEPENDIENTES (PotCheckpoints::NUM_CHECKPOINTS = 8,
// verificado en fuente en subspace-core-primitives). Verificar es paralelizable; producir no. Este
// programa mide el factor real de esa asimetría en esta máquina, para poder escribir
// N_max(presupuesto, τ) con una cifra medida en vez de con una estimación.
//
// Mide, para el MISMO trabajo (8 tramos × I bloques de AES-128 encadenado):
//   - ruta 7 (verificación AVX-512 + VAES): 8 tramos en paralelo, un tramo por carril de 128 bits
//     de un zmm. Es la ruta que Autonomys llama verify_sequential_avx512f_vaes.
//   - ruta 1 (verificación escalar): los 8 tramos en SECUENCIA, un bloque a la vez (AES-NI xmm).
// También mide la producción (ruta secuencial pura) para poder dar la asimetría prove/verify.
//
// Uso: ./verif8 <bloques_por_tramo> [repeticiones]
// Compilación exacta en run-medicion.sh.

#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <linux/perf_event.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <wmmintrin.h>
#include <immintrin.h>

#define NCHK 8

static inline uint64_t rdtsc(void) {
    unsigned lo, hi;
    __asm__ __volatile__("lfence\n\trdtsc" : "=a"(lo), "=d"(hi) :: "memory");
    return ((uint64_t)hi << 32) | lo;
}
static inline uint64_t rdtscp_ordenado(void) {
    unsigned lo, hi, aux;
    __asm__ __volatile__("rdtscp" : "=a"(lo), "=d"(hi), "=c"(aux) :: "memory");
    __asm__ __volatile__("lfence" ::: "memory");
    return ((uint64_t)hi << 32) | lo;
}
static double ahora(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}
static int perf_abrir(uint64_t config) {
    struct perf_event_attr pe;
    memset(&pe, 0, sizeof(pe));
    pe.type = PERF_TYPE_HARDWARE; pe.size = sizeof(pe); pe.config = config;
    pe.disabled = 1; pe.exclude_kernel = 1; pe.exclude_hv = 1;
    return (int)syscall(__NR_perf_event_open, &pe, 0, -1, -1, 0);
}
static uint64_t perf_leer(int fd) {
    uint64_t v = 0;
    if (fd >= 0 && read(fd, &v, sizeof(v)) != (ssize_t)sizeof(v)) v = 0;
    return v;
}
static uint64_t pmu_ini(int fd) {
    if (fd >= 0) { ioctl(fd, PERF_EVENT_IOC_RESET, 0); ioctl(fd, PERF_EVENT_IOC_ENABLE, 0); }
    return 0;
}
static uint64_t pmu_fin(int fd) {
    if (fd >= 0) ioctl(fd, PERF_EVENT_IOC_DISABLE, 0);
    return perf_leer(fd);
}

// ---------------------------------------------------------------- ruta escalar (AES-NI xmm)
// 8 tramos en secuencia. Cada tramo: I bloques de (9 aesenc + 1 aesenclast + xor del checkpoint).
static void escalar(long iters, uint64_t *sink) {
    __m128i k[NCHK];
    for (int i = 0; i < NCHK; i++)
        k[i] = _mm_set_epi32(0x03020100 + i, 0x07060504, 0x0b0a0908, 0x0f0e0d0c);
    __m128i ek = _mm_set_epi32(0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c);
    for (int c = 0; c < NCHK; c++) {
        __m128i x = _mm_set_epi32(1, 2, 3, 4);
        for (long i = 0; i < iters; i++) {
            x = _mm_xor_si128(x, k[c]);
            for (int r = 0; r < 9; r++) x = _mm_aesenc_si128(x, ek);
            x = _mm_aesenclast_si128(x, ek);
        }
        sink[c] = (uint64_t)_mm_cvtsi128_si64(x);
    }
}

// ---------------------------------------------------------------- ruta AVX-512 + VAES
// Los 8 tramos avanzan a la vez: un tramo por carril de 128 bits. Cada instrucción VAESENC
// ejecuta una ronda en los 8 tramos. Sólo se implementa el camino AVX-512 (el AVX2 haría 2
// registros ymm); se declara como límite.
__attribute__((target("avx512f,vaes")))
static void avx512_8tramos(long iters, uint64_t *sink) {
    __m512i x = _mm512_set_epi32(8,8,8,8,7,7,7,7,6,6,6,6,5,5,5,5);
    __m512i ek = _mm512_set_epi32(0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c,
                                  0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c,
                                  0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c,
                                  0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c);
    __m512i k = _mm512_set_epi32(0x03020107, 0x07060504, 0x0b0a0908, 0x0f0e0d0c,
                                 0x03020106, 0x07060504, 0x0b0a0908, 0x0f0e0d0c,
                                 0x03020105, 0x07060504, 0x0b0a0908, 0x0f0e0d0c,
                                 0x03020104, 0x07060504, 0x0b0a0908, 0x0f0e0d0c);
    for (long i = 0; i < iters; i++) {
        x = _mm512_xor_si512(x, k);
        for (int r = 0; r < 9; r++) x = _mm512_aesenc_epi128(x, ek);
        x = _mm512_aesenclast_epi128(x, ek);
    }
    _mm512_storeu_si512((void *)sink, x);
}

// ---------------------------------------------------------------- producción (secuencial pura)
// I bloques de un único tramo: es el camino del productor, no paralelizable.
static void producir(long iters, uint64_t *sink) {
    __m128i x = _mm_set_epi32(1, 2, 3, 4);
    __m128i k = _mm_set_epi32(0x03020100, 0x07060504, 0x0b0a0908, 0x0f0e0d0c);
    __m128i ek = _mm_set_epi32(0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c);
    for (long i = 0; i < iters; i++) {
        x = _mm_xor_si128(x, k);
        for (int r = 0; r < 9; r++) x = _mm_aesenc_si128(x, ek);
        x = _mm_aesenclast_si128(x, ek);
    }
    *sink = (uint64_t)_mm_cvtsi128_si64(x);
}

// ---------------------------------------------------------------- medida

typedef struct { const char *nombre; long bloques; double seg; uint64_t tics, ciclos; } Res;

static Res medir(const char *nombre, void (*fn)(long, uint64_t *), long iters, int fd) {
    uint64_t sink[8] __attribute__((aligned(64))) = {0};
    fn(iters / 10 > 0 ? iters / 10 : 1, sink);   // calentamiento
    pmu_ini(fd);
    uint64_t t0 = rdtsc();
    double s0 = ahora();
    fn(iters, sink);
    double s1 = ahora();
    uint64_t t1 = rdtscp_ordenado();
    uint64_t ciclos = pmu_fin(fd);
    Res r;
    r.nombre = nombre;
    r.bloques = (long)NCHK * iters;
    if (!strcmp(nombre, "producir")) r.bloques = iters;
    r.seg = s1 - s0; r.tics = t1 - t0; r.ciclos = ciclos;
    return r;
}

static void imprimir(const Res *r) {
    double ns_bloque = r->seg * 1e9 / (double)r->bloques;
    double ciclos_bl = r->ciclos > 0 ? (double)r->ciclos / (double)r->bloques : 0.0;
    double ghz = r->ciclos > 0 ? (double)r->ciclos / r->seg / 1e9 : 0.0;
    printf("%-26s bloques=%-11ld %8.4f ns/bloque  %8.3f ciclos/bloque  (%.3f GHz real)\n",
           r->nombre, r->bloques, ns_bloque, ciclos_bl, ghz);
}

int main(int argc, char **argv) {
    long iters = argc > 1 ? atol(argv[1]) : 2000000L;   // bloques por tramo
    int rep = argc > 2 ? atoi(argv[2]) : 3;
    int fd = perf_abrir(PERF_COUNT_HW_CPU_CYCLES);

    printf("verif8 — coste de verificar 8 tramos de PoT, medido\n");
    printf("bloques por tramo=%ld, repeticiones=%d, %s PMU\n\n",
           iters, rep, fd >= 0 ? "con" : "SIN");

    // Se conserva la MEJOR (menor) de las repeticiones: es la menos contaminada por el resto
    // del sistema. Se declaran todas.
    Res mejor[3];
    const char *nombres[3] = { "verificar escalar (8 seq)", "verificar AVX512+VAES (8 par)", "producir (1 seq)" };
    void (*fns[3])(long, uint64_t *) = { escalar, NULL, producir };
    // avx512_8tramos necesita atributo de target; se llama a través de un puntero normal
    fns[1] = (void (*)(long, uint64_t *))avx512_8tramos;

    for (int v = 0; v < 3; v++) {
        mejor[v].seg = 1e30;
        for (int r = 0; r < rep; r++) {
            Res x = medir(nombres[v], fns[v], iters, fd);
            if (x.seg < mejor[v].seg) mejor[v] = x;
            imprimir(&x);
        }
        printf("  --> mejor %s: %.4f ns/bloque\n\n", nombres[v],
               mejor[v].seg * 1e9 / (double)mejor[v].bloques);
    }

    double esc = mejor[0].seg * 1e9 / (double)mejor[0].bloques;
    double avx = mejor[1].seg * 1e9 / (double)mejor[1].bloques;
    double pro = mejor[2].seg * 1e9 / (double)mejor[2].bloques;
    printf("ASIMETRIA medida (mismo trabajo: %d tramos x %ld bloques):\n", NCHK, iters);
    printf("  producir (secuencial)        %8.4f ns/bloque\n", pro);
    printf("  verificar escalar            %8.4f ns/bloque  (factor %.3fx vs producir)\n", esc, esc / pro);
    printf("  verificar AVX512+VAES        %8.4f ns/bloque  (factor %.3fx vs producir)\n", avx, avx / pro);
    printf("  aceleracion por paralelismo 8 tramos: %.3fx (escalar/avx512)\n", esc / avx);
    if (fd >= 0) close(fd);
    return 0;
}
