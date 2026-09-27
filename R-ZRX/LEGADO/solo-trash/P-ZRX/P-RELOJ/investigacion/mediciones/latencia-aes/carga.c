// carga.c — Latencia de la MISMA cadena AES del PoT bajo carga conocida.
//
// Para qué: `aesinst` mide 4,0 ciclos por ronda AESENC con el contador de rendimiento, y 0,777 ns
// por bloque. Si el tiempo por bloque sube cuando la máquina tiene carga, pero los CICLOS no
// suben, entonces la ronda NO se hace más lenta: lo que baja es la FRECUENCIA. Eso es exactamente
// la distinción que decide si el «tercio de latencia» del encargo es arquitectural o de reloj.
//
// Uso: ./carga <n_hilos_ocupados> [n_bloques]
// Compilación exacta en run-medicion.sh.

#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <sched.h>
#include <linux/perf_event.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <wmmintrin.h>

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

// ---------------------------------------------------------------- hilos de carga

typedef struct { int cpu; volatile int seguir; __m128i a, b, k; } Carga;

static void *cargar(void *arg) {
    Carga *c = (Carga *)arg;
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(c->cpu, &set);
    pthread_setaffinity_np(pthread_self(), sizeof(set), &set);
    // FMA/AVX2 saturado: carga real de núcleo, no una espera.
    while (c->seguir) {
        for (int i = 0; i < 20000; i++) {
            c->a = _mm_add_epi64(c->a, c->b);
            c->b = _mm_xor_si128(c->b, c->k);
            c->a = _mm_mul_epu32(c->a, c->k);
        }
    }
    return NULL;
}

// ---------------------------------------------------------------- cadena AES del PoT

typedef struct { double seg; uint64_t tics; uint64_t ciclos; long bloques; } Res;

// Igual que `lat bloque PoT xmm` de aesinst: pxor + 9 aesenc + aesenclast, todo encadenado.
static Res cadena_aes(long bloques, int fd_ciclos) {
    __m128i k0 = _mm_set_epi32(0x03020100, 0x07060504, 0x0b0a0908, 0x0f0e0d0c);
    __m128i k1 = _mm_set_epi32(0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c);
    __m128i x  = _mm_set_epi32(1, 2, 3, 4);
    long n = bloques;
    volatile uint64_t sink;

    // calentamiento
    long w = bloques / 10 > 0 ? bloques / 10 : 1;
    {   long m = w;
        __asm__ __volatile__("1:\n\tpxor %[k0], %[x]\n\t.rept 9\naesenc %[k1], %[x]\n.endr\n\t"
                             "aesenclast %[k1], %[x]\n\tdec %[m]\n\tjnz 1b\n\t"
                             : [x] "+x"(x), [m] "+r"(m) : [k0] "x"(k0), [k1] "x"(k1) : "cc");
    }
    if (fd_ciclos >= 0) { ioctl(fd_ciclos, PERF_EVENT_IOC_RESET, 0); ioctl(fd_ciclos, PERF_EVENT_IOC_ENABLE, 0); }
    uint64_t t0 = rdtsc();
    double s0 = ahora();
    __asm__ __volatile__("1:\n\tpxor %[k0], %[x]\n\t.rept 9\naesenc %[k1], %[x]\n.endr\n\t"
                         "aesenclast %[k1], %[x]\n\tdec %[n]\n\tjnz 1b\n\t"
                         : [x] "+x"(x), [n] "+r"(n) : [k0] "x"(k0), [k1] "x"(k1) : "cc");
    double s1 = ahora();
    uint64_t t1 = rdtscp_ordenado();
    if (fd_ciclos >= 0) ioctl(fd_ciclos, PERF_EVENT_IOC_DISABLE, 0);
    sink = (uint64_t)_mm_cvtsi128_si64(x);

    Res r;
    r.seg = s1 - s0; r.tics = t1 - t0; r.ciclos = perf_leer(fd_ciclos); r.bloques = bloques;
    (void)sink;
    return r;
}

int main(int argc, char **argv) {
    int nhilos = argc > 1 ? atoi(argv[1]) : 0;
    long bloques = argc > 2 ? atol(argv[2]) : 20000000L;
    if (nhilos < 0) nhilos = 0;

    int fd_ciclos = perf_abrir(PERF_COUNT_HW_CPU_CYCLES);

    // El hilo medido va SIEMPRE al core 8; los de carga, a los cores 16..16+nhilos-1 (CCD1, que no
    // comparte L3 con el 8 en este 9950X3D de dos CCD). Se declara en el informe.
    cpu_set_t set;
    CPU_ZERO(&set); CPU_SET(8, &set);
    sched_setaffinity(0, sizeof(set), &set);

    pthread_t *th = calloc(nhilos > 0 ? nhilos : 1, sizeof(pthread_t));
    Carga *cg = calloc(nhilos > 0 ? nhilos : 1, sizeof(Carga));
    for (int i = 0; i < nhilos; i++) {
        cg[i].cpu = 16 + i;
        cg[i].seguir = 1;
        cg[i].a = _mm_set_epi32(i + 1, i + 2, i + 3, i + 4);
        cg[i].b = _mm_set_epi32(i + 5, i + 6, i + 7, i + 8);
        cg[i].k = _mm_set_epi32(0x9e3779b9, 0x85ebca6b, 0xc2b2ae35, 0x27d4eb2f);
        pthread_create(&th[i], NULL, cargar, &cg[i]);
    }
    // Dejar que los hilos de carga arranquen y suban frecuencia
    usleep(300000);

    Res r = cadena_aes(bloques, fd_ciclos);

    double ns_bloque   = r.seg * 1e9 / (double)r.bloques;
    double ciclos_bl   = r.ciclos > 0 ? (double)r.ciclos / (double)r.bloques : 0.0;
    double ghz_pmu     = r.ciclos > 0 ? (double)r.ciclos / r.seg / 1e9 : 0.0;
    double ghz_tsc     = (double)r.tics / r.seg / 1e9;
    int carga = 0;
    { FILE *f = fopen("/proc/loadavg", "r"); if (f) { if (fscanf(f, "%d", &carga) != 1) carga = -1; fclose(f); } }

    printf("hilos_de_carga=%d  bloques=%ld  ns/bloque=%.4f  ciclos/bloque=%.3f  "
           "GHz_PMU=%.3f  GHz_TSC=%.3f\n",
           nhilos, r.bloques, ns_bloque, ciclos_bl, ghz_pmu, ghz_tsc);

    for (int i = 0; i < nhilos; i++) cg[i].seguir = 0;
    for (int i = 0; i < nhilos; i++) pthread_join(th[i], NULL);
    free(th); free(cg);
    if (fd_ciclos >= 0) close(fd_ciclos);
    return 0;
}
