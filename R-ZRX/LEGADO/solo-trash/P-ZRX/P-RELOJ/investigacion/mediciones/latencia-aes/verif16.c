// verif16.c — ¿Cuál es el factor REAL de paralelismo de la verificación del PoT?
//
// `verif8.c` mide el paralelismo por tramos: 8 tramos independientes. Pero la implementación real
// de Autonomys (`subspace-proof-of-time/src/aes/x86_64.rs:169-233`,
// `verify_sequential_avx512f_vaes`) NO encadena los tramos en el tiempo: los 8 valores de entrada
// se cargan a la vez y avanzan en paralelo por la misma instrucción VAES, y además
// `checkpoint_iterations/2` cifra y descifra a la vez (8 valores de ida + 8 de vuelta = 16
// cadenas de 16 B por iteración de VAES de 512 bits = 4 zmm).
//
// Este programa mide las cuatro configuraciones para separar «lo que da el ISH» de «lo que da la
// ley de la cadena»: el bloque de 10 rondas SIEMPRE es serial dentro de su carril, así que el
// paralelismo sólo puede venir de tener varios carriles en vuelo.
//
// Uso: ./verif16 <bloques_por_carril> [repeticiones]

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

// ---------------------------------------------------------------- configuraciones
// Cada función hace `iters` bloques de 10 rondas EN CADA carril. Devuelve el número de carriles.

#define CLAVES512()                                                              \
    const __m512i ek = _mm512_set_epi32(0x13121110,0x17161514,0x1b1a1918,0x1f1e1d1c, \
                                        0x13121110,0x17161514,0x1b1a1918,0x1f1e1d1c, \
                                        0x13121110,0x17161514,0x1b1a1918,0x1f1e1d1c, \
                                        0x13121110,0x17161514,0x1b1a1918,0x1f1e1d1c); \
    const __m512i kk = _mm512_set_epi32(0x03020107,0x07060504,0x0b0a0908,0x0f0e0d0c, \
                                        0x03020106,0x07060504,0x0b0a0908,0x0f0e0d0c, \
                                        0x03020105,0x07060504,0x0b0a0908,0x0f0e0d0c, \
                                        0x03020104,0x07060504,0x0b0a0908,0x0f0e0d0c)

__attribute__((target("avx512f,vaes")))
static long lanes1(long iters, uint64_t *sink) {
    CLAVES512();
    __m512i a = _mm512_set1_epi32(1);
    for (long i = 0; i < iters; i++) {
        a = _mm512_xor_si512(a, kk);
        for (int r = 0; r < 9; r++) a = _mm512_aesenc_epi128(a, ek);
        a = _mm512_aesenclast_epi128(a, ek);
    }
    _mm512_storeu_si512((void *)sink, a);
    return 4;                                  // un zmm = 4 bloques por instrucción
}

__attribute__((target("avx512f,vaes")))
static long lanes2(long iters, uint64_t *sink) {
    CLAVES512();
    __m512i a = _mm512_set1_epi32(1), b = _mm512_set1_epi32(2);
    for (long i = 0; i < iters; i++) {
        a = _mm512_xor_si512(a, kk); b = _mm512_xor_si512(b, kk);
        for (int r = 0; r < 9; r++) { a = _mm512_aesenc_epi128(a, ek); b = _mm512_aesenc_epi128(b, ek); }
        a = _mm512_aesenclast_epi128(a, ek); b = _mm512_aesenclast_epi128(b, ek);
    }
    _mm512_storeu_si512((void *)sink,     _mm512_xor_si512(a, b));
    _mm512_storeu_si512((void *)(sink+8), a);
    return 8;
}

__attribute__((target("avx512f,vaes")))
static long lanes3(long iters, uint64_t *sink) {
    CLAVES512();
    __m512i a = _mm512_set1_epi32(1), b = _mm512_set1_epi32(2), c = _mm512_set1_epi32(3);
    for (long i = 0; i < iters; i++) {
        a = _mm512_xor_si512(a, kk); b = _mm512_xor_si512(b, kk); c = _mm512_xor_si512(c, kk);
        for (int r = 0; r < 9; r++) {
            a = _mm512_aesenc_epi128(a, ek);
            b = _mm512_aesenc_epi128(b, ek);
            c = _mm512_aesenc_epi128(c, ek);
        }
        a = _mm512_aesenclast_epi128(a, ek);
        b = _mm512_aesenclast_epi128(b, ek);
        c = _mm512_aesenclast_epi128(c, ek);
    }
    _mm512_storeu_si512((void *)sink,     _mm512_xor_si512(_mm512_xor_si512(a, b), c));
    _mm512_storeu_si512((void *)(sink+8), a);
    return 12;
}

__attribute__((target("avx512f,vaes")))
static long lanes4(long iters, uint64_t *sink) {
    CLAVES512();
    __m512i a = _mm512_set1_epi32(1), b = _mm512_set1_epi32(2);
    __m512i c = _mm512_set1_epi32(3), d = _mm512_set1_epi32(4);
    for (long i = 0; i < iters; i++) {
        a = _mm512_xor_si512(a, kk); b = _mm512_xor_si512(b, kk);
        c = _mm512_xor_si512(c, kk); d = _mm512_xor_si512(d, kk);
        for (int r = 0; r < 9; r++) {
            a = _mm512_aesenc_epi128(a, ek); b = _mm512_aesenc_epi128(b, ek);
            c = _mm512_aesenc_epi128(c, ek); d = _mm512_aesenc_epi128(d, ek);
        }
        a = _mm512_aesenclast_epi128(a, ek); b = _mm512_aesenclast_epi128(b, ek);
        c = _mm512_aesenclast_epi128(c, ek); d = _mm512_aesenclast_epi128(d, ek);
    }
    __m512i t = _mm512_xor_si512(_mm512_xor_si512(a, b), _mm512_xor_si512(c, d));
    _mm512_storeu_si512((void *)sink, t);
    return 16;                                 // 4 zmm = 16 bloques en vuelo
}

// La MISMA forma que usa Autonomys en AVX-512: 4 carriles cifrando + 4 descifrando = 8 bloques
// en vuelo, con AESENC y AESDEC mezclados (dos puertos distintos si el hardware los tiene).
__attribute__((target("avx512f,vaes")))
static long lanes_mixto8(long iters, uint64_t *sink) {
    const __m512i ek = _mm512_set1_epi32(0x13121110);
    const __m512i dk = _mm512_set1_epi32(0x2f2e2d2c);
    __m512i a = _mm512_set1_epi32(1), d = _mm512_set1_epi32(9);
    for (long i = 0; i < iters; i++) {
        for (int r = 0; r < 10; r++) {
            a = (r == 9) ? _mm512_aesenclast_epi128(a, ek) : _mm512_aesenc_epi128(a, ek);
            d = (r == 9) ? _mm512_aesdeclast_epi128(d, dk) : _mm512_aesdec_epi128(d, dk);
        }
    }
    _mm512_storeu_si512((void *)sink, _mm512_xor_si512(a, d));
    return 8;
}

// 8 carriles descifrando (AESDEC) — la mitad que Autonomys usa para verificar.
__attribute__((target("avx512f,vaes")))
static long lanes_dec8(long iters, uint64_t *sink) {
    const __m512i dk = _mm512_set1_epi32(0x2f2e2d2c);
    __m512i a = _mm512_set1_epi32(1);
    for (long i = 0; i < iters; i++) {
        for (int r = 0; r < 9; r++) a = _mm512_aesdec_epi128(a, dk);
        a = _mm512_aesdeclast_epi128(a, dk);
    }
    _mm512_storeu_si512((void *)sink, a);
    return 4;
}

// 16 carriles descifrando: 4 zmm de AESDEC.
__attribute__((target("avx512f,vaes")))
static long lanes_dec16(long iters, uint64_t *sink) {
    const __m512i dk = _mm512_set1_epi32(0x2f2e2d2c);
    __m512i a = _mm512_set1_epi32(1), b = _mm512_set1_epi32(2);
    __m512i c = _mm512_set1_epi32(3), d = _mm512_set1_epi32(4);
    for (long i = 0; i < iters; i++) {
        for (int r = 0; r < 9; r++) {
            a = _mm512_aesdec_epi128(a, dk); b = _mm512_aesdec_epi128(b, dk);
            c = _mm512_aesdec_epi128(c, dk); d = _mm512_aesdec_epi128(d, dk);
        }
        a = _mm512_aesdeclast_epi128(a, dk); b = _mm512_aesdeclast_epi128(b, dk);
        c = _mm512_aesdeclast_epi128(c, dk); d = _mm512_aesdeclast_epi128(d, dk);
    }
    _mm512_storeu_si512((void *)sink,
        _mm512_xor_si512(_mm512_xor_si512(a, b), _mm512_xor_si512(c, d)));
    return 16;
}

// ---------------------------------------------------------------- medida

typedef long (*fn_t)(long, uint64_t *);

static long mejor_lanes = 0;
static double mejor_ns_bloque = 0.0;

/// Imprime una fila y, si es la mejor de la configuracion, la recuerda.
static void una(const char *nombre, fn_t fn, long iters, int fd, int rep) {
    uint64_t sink[32] __attribute__((aligned(64))) = {0};
    long lanes = fn(1, sink);
    double mejor = 1e30; uint64_t mejor_ciclos = 0;
    for (int r = 0; r < rep; r++) {
        fn(iters / 10 > 0 ? iters / 10 : 1, sink);          // calentamiento
        if (fd >= 0) { ioctl(fd, PERF_EVENT_IOC_RESET, 0); ioctl(fd, PERF_EVENT_IOC_ENABLE, 0); }
        double s0 = ahora();
        fn(iters, sink);
        double s1 = ahora();
        if (fd >= 0) ioctl(fd, PERF_EVENT_IOC_DISABLE, 0);
        uint64_t ciclos = perf_leer(fd);
        if (s1 - s0 < mejor) { mejor = s1 - s0; mejor_ciclos = ciclos; }
    }
    long bloques = lanes * iters;
    double ns_bloque = mejor * 1e9 / (double)bloques;
    double ciclos_bl = mejor_ciclos > 0 ? (double)mejor_ciclos / (double)bloques : 0.0;
    double ghz = mejor_ciclos > 0 ? (double)mejor_ciclos / mejor / 1e9 : 0.0;
    printf("%-28s carriles=%-3ld %8.4f ns/bloque  %8.4f ciclos/bloque  %6.3f GHz  "
           "(%.4f ns por VAES-512)\n",
           nombre, lanes, ns_bloque, ciclos_bl, ghz, ns_bloque * 10.0 / ((double)lanes * 4.0));
    // Línea resumen parseable: se guarda la MEJOR por número de carriles.
    printf("  resumen carriles=%ld ns_bloque=%.6f ciclos_bloque=%.6f\n", lanes, ns_bloque, ciclos_bl);
    if (lanes > mejor_lanes || mejor_ns_bloque == 0.0) { mejor_lanes = lanes; mejor_ns_bloque = ns_bloque; }
}

int main(int argc, char **argv) {
    long iters = argc > 1 ? atol(argv[1]) : 400000L;
    int rep    = argc > 2 ? atoi(argv[2]) : 3;
    int fd = perf_abrir(PERF_COUNT_HW_CPU_CYCLES);

    printf("verif16 — paralelismo real de la verificación del PoT (mismo bloque de 10 rondas)\n");
    printf("bloques por carril=%ld, repeticiones=%d, %s PMU\n", iters, rep, fd >= 0 ? "con" : "SIN");
    printf("cada 'bloque' = 10 rondas encadenadas dentro de su carril\n\n");

    una("1 zmm AESENC  (4 carriles)",   lanes1,      iters, fd, rep);
    una("2 zmm AESENC  (8 carriles)",   lanes2,      iters, fd, rep);
    una("3 zmm AESENC (12 carriles)",   lanes3,      iters, fd, rep);
    una("4 zmm AESENC (16 carriles)",   lanes4,      iters, fd, rep);
    una("4+4 ENC/DEC   (8 carriles)",   lanes_mixto8,iters, fd, rep);
    una("1 zmm AESDEC  (4 carriles)",   lanes_dec8,  iters, fd, rep);
    una("4 zmm AESDEC (16 carriles)",   lanes_dec16, iters, fd, rep);
    printf("MEJOR carriles=%ld ns_bloque=%.6f\n", mejor_lanes, mejor_ns_bloque);
    if (fd >= 0) close(fd);
    return 0;
}
