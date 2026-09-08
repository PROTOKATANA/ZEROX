/* D8 ronda 10a · B.3 — ¿cuantas LINEAS de PoT simultaneas aguanta una maquina?
 *
 * La opcion (h) obliga al timekeeper a sostener `q = ceil(L/I)` cadenas de revelacion ADEMAS
 * de la cadena principal. La pregunta es si `q + 1` cadenas de AES corren a la misma velocidad
 * que una sola, o si compiten. El bench de Autonomys `pot-compare-cpu-cores.rs` NO responde a
 * esto: fija la afinidad a un nucleo cada vez y mide de UNO EN UNO (leido en el fuente).
 *
 * Aqui se replica LITERALMENTE el nucleo de `subspace-proof-of-time/src/aes/x86_64.rs:22-33`
 * (nueve `_mm_aesenc_si128` mas un `_mm_aesenclast_si128` encadenados sobre el mismo registro)
 * y se corre en N hilos simultaneos, cada uno con su propia cadena independiente. Se reporta
 * iteraciones por segundo y hilo, y el equivalente en segundos por slot con el
 * `pot_slot_iterations` del bench de Autonomys (200 032 000).
 *
 * Compilar:  gcc -O3 -maes -mavx2 -pthread -o r10a_b3_lineas r10a_b3_lineas.c
 * Uso:       ./r10a_b3_lineas <hilos> <iteraciones por hilo>
 */
#include <immintrin.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

static long ITER;

typedef struct { int id; __m128i out; double seg; } arg_t;

static void *linea(void *p) {
    arg_t *a = (arg_t *)p;
    /* claves distintas por hilo: cadenas independientes, como las q revelaciones en vuelo */
    __m128i k[11];
    for (int i = 0; i < 11; i++)
        k[i] = _mm_set_epi32(0x1234567 + i, 0x89abcdef + a->id, 0xfeed1234 + i * 7, 0x0badc0de + a->id * 13);
    __m128i xk = _mm_xor_si128(k[10], k[0]);
    __m128i s = _mm_set_epi32(a->id, 1, 2, 3);
    s = _mm_xor_si128(s, k[0]);
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (long i = 0; i < ITER; i++) {
        s = _mm_aesenc_si128(s, k[1]);
        s = _mm_aesenc_si128(s, k[2]);
        s = _mm_aesenc_si128(s, k[3]);
        s = _mm_aesenc_si128(s, k[4]);
        s = _mm_aesenc_si128(s, k[5]);
        s = _mm_aesenc_si128(s, k[6]);
        s = _mm_aesenc_si128(s, k[7]);
        s = _mm_aesenc_si128(s, k[8]);
        s = _mm_aesenc_si128(s, k[9]);
        s = _mm_aesenclast_si128(s, xk);
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    a->seg = (t1.tv_sec - t0.tv_sec) + 1e-9 * (t1.tv_nsec - t0.tv_nsec);
    a->out = s;
    return NULL;
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 1;
    ITER = argc > 2 ? atol(argv[2]) : 50000000L;
    pthread_t *th = malloc(n * sizeof(pthread_t));
    arg_t *ar = malloc(n * sizeof(arg_t));
    for (int i = 0; i < n; i++) { ar[i].id = i; pthread_create(&th[i], NULL, linea, &ar[i]); }
    double peor = 0, suma = 0;
    uint64_t acc = 0;
    for (int i = 0; i < n; i++) {
        pthread_join(th[i], NULL);
        if (ar[i].seg > peor) peor = ar[i].seg;
        suma += ar[i].seg;
        acc ^= (uint64_t)_mm_extract_epi64(ar[i].out, 0);   /* impide que el compilador lo borre */
    }
    double media = suma / n;
    double it_s_media = ITER / media, it_s_peor = ITER / peor;
    printf("%3d hilos | %10.3e it/s por hilo (media) %10.3e (el mas lento) | "
           "s/slot a 200 032 000 it: %6.3f (media) %6.3f (peor) | agregado %10.3e it/s | chk %016lx\n",
           n, it_s_media, it_s_peor, 200032000.0 / it_s_media, 200032000.0 / it_s_peor,
           n * it_s_media, (unsigned long)acc);
    return 0;
}
