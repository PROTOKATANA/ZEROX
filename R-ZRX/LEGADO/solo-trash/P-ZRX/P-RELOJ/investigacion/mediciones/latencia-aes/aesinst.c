// aesinst.c — Latencia y rendimiento de las INSTRUCCIONES AES-NI / VAES, aisladas.
//
// DESVIACIÓN AUTORIZADA DE veritas/LINEO.md: LINEO asigna Julia a CPU y C++/CUDA a GPU (§5.7).
// Este programa NO es un kernel numérico ni Monte Carlo: mide LATENCIA DE INSTRUCCIÓN, que exige
// intrínsecos y ensamblador en línea, y que Julia sólo expresaría con `llvmcall`. La desviación
// está argumentada en CONTRATO.md y METODO.md del instrumento `reloj-adaptativo-v1`.
//
// Qué mide, por variante:
//   lat-*  = latencia de la instrucción (cadena dependiente, 1 acumulador)
//   thr-*  = rendimiento recíproco (varios acumuladores independientes)
// en ciclos de CONTADOR DE RENDIMIENTO (perf_event_open, hardware) y en tics de TSC, de modo que
// la frecuencia real bajo carga se MIDE en vez de suponerse.
//
// Uso: ./aesinst [--n-iter N]
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

// ---------------------------------------------------------------- reloj y PMU

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
    pe.type = PERF_TYPE_HARDWARE;
    pe.size = sizeof(pe);
    pe.config = config;
    pe.disabled = 1;
    pe.exclude_kernel = 1;
    pe.exclude_hv = 1;
    return (int)syscall(__NR_perf_event_open, &pe, 0, -1, -1, 0);
}

static uint64_t perf_leer(int fd) {
    uint64_t v = 0;
    if (fd >= 0 && read(fd, &v, sizeof(v)) != (ssize_t)sizeof(v)) v = 0;
    return v;
}

#define PERF_RESET(fd) do { if ((fd) >= 0) ioctl((fd), PERF_EVENT_IOC_RESET, 0); } while (0)
#define PERF_ON(fd)    do { if ((fd) >= 0) ioctl((fd), PERF_EVENT_IOC_ENABLE, 0); } while (0)
#define PERF_OFF(fd)   do { if ((fd) >= 0) ioctl((fd), PERF_EVENT_IOC_DISABLE, 0); } while (0)

// ---------------------------------------------------------------- núcleos de medida

// Cada núcleo devuelve los tics de TSC consumidos y deja un sumidero en *sink.
typedef uint64_t (*nucleo_fn)(long n, void *sink, uint64_t *ciclos);

// TSC con serialización: 'lfence; rdtsc' al principio y 'rdtscp; lfence' al final impiden que el
// compilador o la CPU muevan el reloj respecto del bloque medido.
#define TSC_INI uint64_t _t0 = rdtsc()
#define TSC_FIN uint64_t _t1 = rdtscp_ordenado(); return _t1 - _t0

// latencia xmm con la dependencia EXACTA del PoT: xor + 9 aesenc + aesenclast por bloque.
static uint64_t lat_bloque_xmm(long n, void *sink, uint64_t *ciclos) {
    __m128i k0 = _mm_set_epi32(0x03020100, 0x07060504, 0x0b0a0908, 0x0f0e0d0c);
    __m128i k1 = _mm_set_epi32(0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c);
    __m128i x  = _mm_set_epi32(1, 2, 3, 4);
    TSC_INI;
    __asm__ __volatile__(
        "1:\n\t"
        "pxor %[k0], %[x]\n\t"
        ".rept 9\n\t"
        "aesenc %[k1], %[x]\n\t"
        ".endr\n\t"
        "aesenclast %[k1], %[x]\n\t"
        "dec %[n]\n\t"
        "jnz 1b\n\t"
        : [x] "+x"(x), [n] "+r"(n)
        : [k0] "x"(k0), [k1] "x"(k1)
        : "cc");
    *(uint64_t *)sink = (uint64_t)_mm_cvtsi128_si64(x);
    if (ciclos) *ciclos = 10;
    TSC_FIN;
}

// latencia de AESENC aislado: 16 aesenc encadenados por iteración.
static uint64_t lat_aesenc_xmm(long n, void *sink, uint64_t *ciclos) {
    __m128i k1 = _mm_set_epi32(0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c);
    __m128i x  = _mm_set_epi32(1, 2, 3, 4);
    TSC_INI;
    __asm__ __volatile__(
        "1:\n\t"
        ".rept 16\n\t"
        "aesenc %[k1], %[x]\n\t"
        ".endr\n\t"
        "dec %[n]\n\t"
        "jnz 1b\n\t"
        : [x] "+x"(x), [n] "+r"(n)
        : [k1] "x"(k1)
        : "cc");
    *(uint64_t *)sink = (uint64_t)_mm_cvtsi128_si64(x);
    if (ciclos) *ciclos = 16;
    TSC_FIN;
}

// latencia de AESENCLAST aislado.
static uint64_t lat_aesenclast_xmm(long n, void *sink, uint64_t *ciclos) {
    __m128i k1 = _mm_set_epi32(0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c);
    __m128i x  = _mm_set_epi32(1, 2, 3, 4);
    TSC_INI;
    __asm__ __volatile__(
        "1:\n\t"
        ".rept 16\n\t"
        "aesenclast %[k1], %[x]\n\t"
        ".endr\n\t"
        "dec %[n]\n\t"
        "jnz 1b\n\t"
        : [x] "+x"(x), [n] "+r"(n)
        : [k1] "x"(k1)
        : "cc");
    *(uint64_t *)sink = (uint64_t)_mm_cvtsi128_si64(x);
    if (ciclos) *ciclos = 16;
    TSC_FIN;
}

// latencia de PXOR aislado (control: debería ser 1 ciclo).
static uint64_t lat_pxor_xmm(long n, void *sink, uint64_t *ciclos) {
    __m128i k1 = _mm_set_epi32(0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c);
    __m128i x  = _mm_set_epi32(1, 2, 3, 4);
    TSC_INI;
    __asm__ __volatile__(
        "1:\n\t"
        ".rept 16\n\t"
        "pxor %[k1], %[x]\n\t"
        ".endr\n\t"
        "dec %[n]\n\t"
        "jnz 1b\n\t"
        : [x] "+x"(x), [n] "+r"(n)
        : [k1] "x"(k1)
        : "cc");
    *(uint64_t *)sink = (uint64_t)_mm_cvtsi128_si64(x);
    if (ciclos) *ciclos = 16;
    TSC_FIN;
}

// rendimiento recíproco de AESENC: 8 cadenas independientes.
static uint64_t thr_aesenc_xmm(long n, void *sink, uint64_t *ciclos) {
    __m128i k1 = _mm_set_epi32(0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c);
    __m128i a0 = _mm_set_epi32(1,1,1,1), a1 = _mm_set_epi32(2,2,2,2);
    __m128i a2 = _mm_set_epi32(3,3,3,3), a3 = _mm_set_epi32(4,4,4,4);
    __m128i a4 = _mm_set_epi32(5,5,5,5), a5 = _mm_set_epi32(6,6,6,6);
    __m128i a6 = _mm_set_epi32(7,7,7,7), a7 = _mm_set_epi32(8,8,8,8);
    TSC_INI;
    __asm__ __volatile__(
        "1:\n\t"
        ".rept 4\n\t"
        "aesenc %[k], %[a0]\n\t" "aesenc %[k], %[a1]\n\t"
        "aesenc %[k], %[a2]\n\t" "aesenc %[k], %[a3]\n\t"
        "aesenc %[k], %[a4]\n\t" "aesenc %[k], %[a5]\n\t"
        "aesenc %[k], %[a6]\n\t" "aesenc %[k], %[a7]\n\t"
        ".endr\n\t"
        "dec %[n]\n\t"
        "jnz 1b\n\t"
        : [a0] "+x"(a0), [a1] "+x"(a1), [a2] "+x"(a2), [a3] "+x"(a3),
          [a4] "+x"(a4), [a5] "+x"(a5), [a6] "+x"(a6), [a7] "+x"(a7), [n] "+r"(n)
        : [k] "x"(k1)
        : "cc");
    a0 = _mm_xor_si128(a0,a1); a2 = _mm_xor_si128(a2,a3);
    a4 = _mm_xor_si128(a4,a5); a6 = _mm_xor_si128(a6,a7);
    *(uint64_t *)sink = (uint64_t)_mm_cvtsi128_si64(
        _mm_xor_si128(_mm_xor_si128(a0,a2), _mm_xor_si128(a4,a6)));
    if (ciclos) *ciclos = 32;   // 4 repeticiones × 8 aesenc
    TSC_FIN;
}

// latencia de VAESENC ymm (2 bloques por instrucción), 8 encadenados por iteración.
static uint64_t lat_vaesenc_ymm(long n, void *sink, uint64_t *ciclos) {
    __m256i k1 = _mm256_set_epi32(7,6,5,4,3,2,1,0);
    __m256i x  = _mm256_set_epi32(1,2,3,4,5,6,7,8);
    TSC_INI;
    for (long i = 0; i < n; i++)
        for (int r = 0; r < 8; r++) x = _mm256_aesenc_epi128(x, k1);
    *(uint64_t *)sink = (uint64_t)_mm256_extract_epi64(x, 0);
    if (ciclos) *ciclos = 8;
    TSC_FIN;
}

// rendimiento de VAESENC ymm: 4 cadenas independientes.
static uint64_t thr_vaesenc_ymm(long n, void *sink, uint64_t *ciclos) {
    __m256i k1 = _mm256_set_epi32(7,6,5,4,3,2,1,0);
    __m256i a0 = _mm256_set1_epi32(1), a1 = _mm256_set1_epi32(2);
    __m256i a2 = _mm256_set1_epi32(3), a3 = _mm256_set1_epi32(4);
    TSC_INI;
    for (long i = 0; i < n; i++) {
        a0 = _mm256_aesenc_epi128(a0, k1); a1 = _mm256_aesenc_epi128(a1, k1);
        a2 = _mm256_aesenc_epi128(a2, k1); a3 = _mm256_aesenc_epi128(a3, k1);
    }
    a0 = _mm256_xor_si256(a0,a1); a2 = _mm256_xor_si256(a2,a3);
    *(uint64_t *)sink = (uint64_t)_mm256_extract_epi64(_mm256_xor_si256(a0,a2), 0);
    if (ciclos) *ciclos = 4;
    TSC_FIN;
}

// latencia de VAESENC zmm (4 bloques por instrucción).
static uint64_t lat_vaesenc_zmm(long n, void *sink, uint64_t *ciclos) {
    __m512i k1 = _mm512_set_epi32(15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0);
    __m512i x  = _mm512_set_epi32(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16);
    TSC_INI;
    for (long i = 0; i < n; i++)
        for (int r = 0; r < 8; r++) x = _mm512_aesenc_epi128(x, k1);
    *(uint64_t *)sink = (uint64_t)_mm512_cvtsi512_si32(x);
    if (ciclos) *ciclos = 8;
    TSC_FIN;
}

// rendimiento de VAESENC zmm: 4 cadenas independientes.
static uint64_t thr_vaesenc_zmm(long n, void *sink, uint64_t *ciclos) {
    __m512i k1 = _mm512_set_epi32(15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0);
    __m512i a0 = _mm512_set1_epi32(1), a1 = _mm512_set1_epi32(2);
    __m512i a2 = _mm512_set1_epi32(3), a3 = _mm512_set1_epi32(4);
    TSC_INI;
    for (long i = 0; i < n; i++) {
        a0 = _mm512_aesenc_epi128(a0, k1); a1 = _mm512_aesenc_epi128(a1, k1);
        a2 = _mm512_aesenc_epi128(a2, k1); a3 = _mm512_aesenc_epi128(a3, k1);
    }
    a0 = _mm512_xor_si512(a0,a1); a2 = _mm512_xor_si512(a2,a3);
    *(uint64_t *)sink = (uint64_t)_mm512_cvtsi512_si32(_mm512_xor_si512(a0,a2));
    if (ciclos) *ciclos = 4;
    TSC_FIN;
}

// ---------------------------------------------------------------- medida

static int fd_ciclos = -1;
static int fd_ref    = -1;

typedef struct {
    const char *nombre;
    long        n_iter;      // cuántas veces se ejecuta el núcleo
    long        ops_por_iter;
    const char *unidad;
    double      ns_total;
    uint64_t    tics;
    uint64_t    ciclos;
    uint64_t    ref;
} Medida;

static Medida medir(const char *nombre, nucleo_fn fn, long n, long ops_por_iter,
                    const char *unidad) {
    Medida m;
    memset(&m, 0, sizeof(m));
    m.nombre = nombre; m.n_iter = n; m.ops_por_iter = ops_por_iter; m.unidad = unidad;
    uint64_t sink = 0, dummy;
    // Calentamiento: misma ruta de código, 1/10 del trabajo.
    fn(n / 10 > 0 ? n / 10 : 1, &sink, &dummy);
    PERF_RESET(fd_ciclos); PERF_RESET(fd_ref);
    double t0 = ahora();
    PERF_ON(fd_ciclos); PERF_ON(fd_ref);
    m.tics = fn(n, &sink, &dummy);
    PERF_OFF(fd_ciclos); PERF_OFF(fd_ref);
    double t1 = ahora();
    (void)sink;
    m.ns_total = (t1 - t0) * 1e9;
    m.ciclos = perf_leer(fd_ciclos);
    m.ref    = perf_leer(fd_ref);
    return m;
}

static void imprimir(const Medida *m, int tiene_pmu) {
    double ops = (double)m->n_iter * (double)m->ops_por_iter;
    printf("%-20s %10.4f ns/%-8s", m->nombre, m->ns_total / ops, m->unidad);
    if (tiene_pmu && m->ciclos > 0) {
        printf(" %8.3f ciclos/%-8s (%.3f GHz reloj real, %.3f GHz TSC)\n",
               (double)m->ciclos / ops, m->unidad,
               (double)m->ciclos / (m->ns_total * 1e-9) / 1e9,
               (double)m->tics / (m->ns_total * 1e-9) / 1e9);
    } else {
        printf(" (PMU no disponible; %.3f GHz TSC)\n",
               (double)m->tics / (m->ns_total * 1e-9) / 1e9);
    }
}

int main(int argc, char **argv) {
    long n = 2000000L;   // iteraciones del núcleo; ×ops_por_iter = operaciones

    for (int i = 1; i < argc; i++)
        if (!strcmp(argv[i], "--n-iter") && i + 1 < argc) n = atol(argv[++i]);

    fd_ciclos = perf_abrir(PERF_COUNT_HW_CPU_CYCLES);
    fd_ref    = perf_abrir(PERF_COUNT_HW_REF_CPU_CYCLES);
    int tiene_pmu = fd_ciclos >= 0;

    printf("aesinst v1 — latencia y rendimiento de instrucciones AES/VAES\n");
    printf("CPU: %s\n", "ver /proc/cpuinfo");
    printf("n-iter=%ld por núcleo; %s PMU hardware (perf_event_open)\n\n",
           n, tiene_pmu ? "con" : "SIN");

    Medida v[10];
    int k = 0;
    v[k++] = medir("lat pxor xmm [ctl]",   lat_pxor_xmm,      n, 16, "pxor");
    v[k++] = medir("lat AESENC xmm",       lat_aesenc_xmm,    n, 16, "aesenc");
    v[k++] = medir("lat AESENCLAST xmm",   lat_aesenclast_xmm,n, 16, "aesenclast");
    v[k++] = medir("lat bloque PoT xmm",   lat_bloque_xmm,    n, 10, "instr");
    v[k++] = medir("thr AESENC xmm",       thr_aesenc_xmm,    n, 32, "aesenc");
    v[k++] = medir("lat VAESENC ymm",      lat_vaesenc_ymm,   n,  8, "vaesenc");
    v[k++] = medir("thr VAESENC ymm",      thr_vaesenc_ymm,   n,  4, "vaesenc");
    v[k++] = medir("lat VAESENC zmm",      lat_vaesenc_zmm,   n,  8, "vaesenc");
    v[k++] = medir("thr VAESENC zmm",      thr_vaesenc_zmm,   n,  4, "vaesenc");

    for (int i = 0; i < k; i++) imprimir(&v[i], tiene_pmu);

    printf("\n");
    printf("CONTROL DE COHERENCIA: 'lat pxor xmm' debe salir ~1 ciclo/pxor.\n");
    printf("'lat bloque PoT xmm' debe dar ~10x la latencia de una ronda si la cadena manda.\n");
    return 0;
}
