/* CORRECCION-A10-M1-A — anfitrion en C puro (gcc -std=c11): compila el kernel de
 * deepseek/A10M1/gpu/kernel_nvrtc.cu en tiempo de ejecucion con NVRTC 12.9
 * (--gpu-architecture=compute_61), lo carga con cuModuleLoadData y lo lanza con cuLaunchKernel.
 * No usa nvcc en absoluto (ese era el bloqueo de la ronda 1: gcc 15 es incompatible con el
 * anfitrion C++ de nvcc 12.9). cuda.h y nvrtc.h son cabeceras C, no arrastran libstdc++.
 *
 * La preimagen fija de 108 bytes (misma cabecera que la ronda 1) se obtiene en caliente del
 * binario Rust de referencia (`bench_pow preimagen-hex`), para no transcribirla a mano dos veces.
 */

#define _POSIX_C_SOURCE 200809L
#include <cuda.h>
#include <nvrtc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CU_CHECK(expr)                                                                          \
    do {                                                                                        \
        CUresult _r = (expr);                                                                   \
        if (_r != CUDA_SUCCESS) {                                                               \
            const char* _s = NULL;                                                              \
            cuGetErrorString(_r, &_s);                                                          \
            fprintf(stderr, "CUDA driver error %s:%d: %s (%d)\n", __FILE__, __LINE__,           \
                    _s ? _s : "?", (int)_r);                                                     \
            exit(1);                                                                            \
        }                                                                                        \
    } while (0)

#define NVRTC_CHECK(expr)                                                                        \
    do {                                                                                          \
        nvrtcResult _r = (expr);                                                                  \
        if (_r != NVRTC_SUCCESS) {                                                                \
            fprintf(stderr, "NVRTC error %s:%d: %s\n", __FILE__, __LINE__,                        \
                    nvrtcGetErrorString(_r));                                                     \
            exit(1);                                                                              \
        }                                                                                          \
    } while (0)

static char* leer_fichero(const char* ruta, size_t* out_len) {
    FILE* f = fopen(ruta, "rb");
    if (!f) { fprintf(stderr, "no se pudo abrir %s\n", ruta); exit(1); }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char* buf = malloc((size_t)n + 1);
    if (fread(buf, 1, (size_t)n, f) != (size_t)n) { fprintf(stderr, "lectura corta\n"); exit(1); }
    buf[n] = '\0';
    fclose(f);
    if (out_len) *out_len = (size_t)n;
    return buf;
}

static void hex_a_bytes(const char* hex, unsigned char* out, size_t nbytes) {
    for (size_t i = 0; i < nbytes; i++) {
        unsigned int b;
        sscanf(hex + 2 * i, "%2x", &b);
        out[i] = (unsigned char)b;
    }
}

static void bytes_a_hex(const unsigned char* b, size_t n, char* out) {
    static const char* d = "0123456789abcdef";
    for (size_t i = 0; i < n; i++) { out[2*i] = d[b[i]>>4]; out[2*i+1] = d[b[i]&0xf]; }
    out[2*n] = '\0';
}

/* Obtiene la preimagen fija (108 bytes, hex) del binario Rust de referencia: una unica fuente de
 * verdad para la cabecera, sin transcribirla a mano. */
static void obtener_preimagen_hex(const char* bench_pow_bin, char out_hex[217]) {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "%s preimagen-hex", bench_pow_bin);
    FILE* p = popen(cmd, "r");
    if (!p) { fprintf(stderr, "no se pudo ejecutar %s\n", cmd); exit(1); }
    if (!fgets(out_hex, 217, p)) { fprintf(stderr, "sin salida de %s\n", cmd); exit(1); }
    pclose(p);
    /* quitar salto de linea */
    size_t n = strlen(out_hex);
    while (n > 0 && (out_hex[n-1] == '\n' || out_hex[n-1] == '\r')) out_hex[--n] = '\0';
    if (n != 216) { fprintf(stderr, "preimagen-hex inesperada (%zu chars): %s\n", n, out_hex); exit(1); }
}

/* ---- estado global CUDA/NVRTC ---- */
static CUcontext g_ctx;
static CUmodule g_mod;
static CUfunction g_f_validar, g_f_dump, g_f_search, g_f_bench;

static void inicializar_cuda_y_compilar(const char* ruta_kernel) {
    CU_CHECK(cuInit(0));
    CUdevice dev;
    CU_CHECK(cuDeviceGet(&dev, 0));
    char nombre[256];
    CU_CHECK(cuDeviceGetName(nombre, sizeof(nombre), dev));
    int cc_major, cc_minor;
    CU_CHECK(cuDeviceGetAttribute(&cc_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CU_CHECK(cuDeviceGetAttribute(&cc_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    fprintf(stderr, "GPU: %s (CC %d.%d)\n", nombre, cc_major, cc_minor);
    CU_CHECK(cuCtxCreate(&g_ctx, 0, dev));

    size_t src_len;
    char* src = leer_fichero(ruta_kernel, &src_len);

    nvrtcProgram prog;
    NVRTC_CHECK(nvrtcCreateProgram(&prog, src, "kernel_nvrtc.cu", 0, NULL, NULL));
    const char* opts[] = {"--gpu-architecture=compute_61"};
    nvrtcResult rc = nvrtcCompileProgram(prog, 1, opts);

    size_t log_size = 0;
    nvrtcGetProgramLogSize(prog, &log_size);
    if (log_size > 1) {
        char* log = malloc(log_size);
        nvrtcGetProgramLog(prog, log);
        fprintf(stderr, "== log de NVRTC ==\n%s\n===================\n", log);
        free(log);
    }
    if (rc != NVRTC_SUCCESS) {
        fprintf(stderr, "NVRTC no pudo compilar el nucleo: %s\n", nvrtcGetErrorString(rc));
        exit(1);
    }

    size_t ptx_size;
    NVRTC_CHECK(nvrtcGetPTXSize(prog, &ptx_size));
    char* ptx = malloc(ptx_size);
    NVRTC_CHECK(nvrtcGetPTX(prog, ptx));
    nvrtcDestroyProgram(&prog);
    free(src);

    CU_CHECK(cuModuleLoadData(&g_mod, ptx));
    free(ptx);
    CU_CHECK(cuModuleGetFunction(&g_f_validar, g_mod, "k_validar_vectores"));
    CU_CHECK(cuModuleGetFunction(&g_f_dump, g_mod, "k_dump"));
    CU_CHECK(cuModuleGetFunction(&g_f_search, g_mod, "k_search"));
    CU_CHECK(cuModuleGetFunction(&g_f_bench, g_mod, "k_bench"));
    fprintf(stderr, "NVRTC: compilado y cargado OK (compute_61, sin nvcc)\n");
}

static CUdeviceptr subir(const void* datos, size_t n) {
    CUdeviceptr d;
    CU_CHECK(cuMemAlloc(&d, n));
    CU_CHECK(cuMemcpyHtoD(d, datos, n));
    return d;
}

/* ==================== selftest: validacion (a) ==================== */

typedef struct { unsigned char msg[136]; unsigned int len; unsigned char md[32]; } Vector;

static int leer_rsp(const char* ruta, Vector** out, int* out_n) {
    size_t flen; char* buf = leer_fichero(ruta, &flen);
    int cap = 4096, n = 0;
    Vector* vs = malloc(sizeof(Vector) * cap);
    long len_bits = -1;
    char msg_hex[512] = {0};
    int tiene_msg = 0;
    char* linea = strtok(buf, "\n");
    while (linea) {
        if (strncmp(linea, "Len = ", 6) == 0) { len_bits = atol(linea + 6); tiene_msg = 0; }
        else if (strncmp(linea, "Msg = ", 6) == 0) {
            strncpy(msg_hex, linea + 6, sizeof(msg_hex) - 1);
            msg_hex[sizeof(msg_hex)-1] = '\0';
            /* quitar \r si lo hay */
            size_t l = strlen(msg_hex); while (l>0 && (msg_hex[l-1]=='\r')) msg_hex[--l]='\0';
            tiene_msg = 1;
        } else if (strncmp(linea, "MD = ", 5) == 0 && tiene_msg) {
            if (len_bits >= 0 && len_bits <= 1080) {
                size_t nbytes = (size_t)((len_bits + 7) / 8);
                if (n >= cap) { cap *= 2; vs = realloc(vs, sizeof(Vector) * cap); }
                memset(&vs[n], 0, sizeof(Vector));
                hex_a_bytes(msg_hex, vs[n].msg, nbytes);
                vs[n].len = (unsigned int)nbytes;
                char md_hex[80]; strncpy(md_hex, linea + 5, sizeof(md_hex)-1); md_hex[sizeof(md_hex)-1]='\0';
                size_t l = strlen(md_hex); while (l>0 && (md_hex[l-1]=='\r')) md_hex[--l]='\0';
                hex_a_bytes(md_hex, vs[n].md, 32);
                n++;
            }
            tiene_msg = 0;
        }
        linea = strtok(NULL, "\n");
    }
    free(buf);
    *out = vs; *out_n = n;
    return 0;
}

static void modo_selftest(const char* dir) {
    const char* nombres[2] = {"SHA3_256ShortMsg.rsp", "SHA3_256LongMsg.rsp"};
    Vector* todos = malloc(sizeof(Vector) * 200000);
    int total = 0;
    for (int f = 0; f < 2; f++) {
        char ruta[1024]; snprintf(ruta, sizeof(ruta), "%s/%s", dir, nombres[f]);
        Vector* vs; int n;
        leer_rsp(ruta, &vs, &n);
        fprintf(stdout, "%s: %d vectores con Len<=1080 bits\n", ruta, n);
        memcpy(todos + total, vs, sizeof(Vector) * n);
        total += n;
        free(vs);
    }

    unsigned char* h_msgs = malloc(136 * total);
    unsigned int* h_lens = malloc(sizeof(unsigned int) * total);
    for (int i = 0; i < total; i++) {
        memset(h_msgs + i * 136, 0, 136);
        memcpy(h_msgs + i * 136, todos[i].msg, todos[i].len);
        h_lens[i] = todos[i].len;
    }
    CUdeviceptr d_msgs = subir(h_msgs, (size_t)136 * total);
    CUdeviceptr d_lens = subir(h_lens, sizeof(unsigned int) * total);
    CUdeviceptr d_out; CU_CHECK(cuMemAlloc(&d_out, (size_t)32 * total));

    int threads = 128, blocks = (total + threads - 1) / threads;
    void* args[] = {&d_msgs, &d_lens, &total, &d_out};
    CU_CHECK(cuLaunchKernel(g_f_validar, blocks, 1, 1, threads, 1, 1, 0, 0, args, 0));
    CU_CHECK(cuCtxSynchronize());

    unsigned char* h_out = malloc((size_t)32 * total);
    CU_CHECK(cuMemcpyDtoH(h_out, d_out, (size_t)32 * total));

    int ok = 0, fallo = 0;
    for (int i = 0; i < total; i++) {
        if (memcmp(h_out + i * 32, todos[i].md, 32) == 0) ok++;
        else { fallo++; if (fallo <= 5) fprintf(stdout, "FALLO vector %d (len=%u bytes)\n", i, todos[i].len); }
    }
    fprintf(stdout, "validacion (a): %d/%d vectores NIST CAVP correctos (%d fallos)\n", ok, total, fallo);
    cuMemFree(d_msgs); cuMemFree(d_lens); cuMemFree(d_out);
    free(h_msgs); free(h_lens); free(h_out); free(todos);
    if (fallo != 0) exit(1);
}

/* ==================== dump: validacion (b) ==================== */

static void modo_dump(const unsigned long long tpl[17], unsigned long long seed, unsigned long long n,
                       const char* outfile) {
    CUdeviceptr d_tpl = subir(tpl, 17 * sizeof(unsigned long long));
    CUdeviceptr d_out; CU_CHECK(cuMemAlloc(&d_out, n * 32));
    int threads = 256; unsigned long long blocks = (n + threads - 1) / threads;
    void* args[] = {&d_tpl, &seed, &n, &d_out};
    CU_CHECK(cuLaunchKernel(g_f_dump, (unsigned)blocks, 1, 1, threads, 1, 1, 0, 0, args, 0));
    CU_CHECK(cuCtxSynchronize());
    unsigned char* h_out = malloc(n * 32);
    CU_CHECK(cuMemcpyDtoH(h_out, d_out, n * 32));
    FILE* f = fopen(outfile, "wb");
    fwrite(h_out, 1, n * 32, f);
    fclose(f);
    printf("dump: %llu digests escritos en %s (seed=%llu)\n", n, outfile, seed);
    free(h_out); cuMemFree(d_tpl); cuMemFree(d_out);
}

/* ==================== search: validacion (c) ==================== */

static void modo_search(const unsigned long long tpl[17], unsigned int bits_cero, unsigned long long max_nonce) {
    CUdeviceptr d_tpl = subir(tpl, 17 * sizeof(unsigned long long));
    unsigned long long h_min = 0xFFFFFFFFFFFFFFFFULL;
    CUdeviceptr d_min = subir(&h_min, sizeof(h_min));
    int threads = 256; unsigned long long blocks = (max_nonce + threads - 1) / threads;
    void* args[] = {&d_tpl, &max_nonce, &bits_cero, &d_min};
    CU_CHECK(cuLaunchKernel(g_f_search, (unsigned)blocks, 1, 1, threads, 1, 1, 0, 0, args, 0));
    CU_CHECK(cuCtxSynchronize());
    CU_CHECK(cuMemcpyDtoH(&h_min, d_min, sizeof(h_min)));
    if (h_min == 0xFFFFFFFFFFFFFFFFULL) printf("search: sin resultado hasta max_nonce=%llu\n", max_nonce);
    else printf("search: nonce=%llu\n", h_min);
    cuMemFree(d_tpl); cuMemFree(d_min);
}

/* ==================== bench ==================== */

static void modo_bench(const unsigned long long tpl[17], double duracion_s, int blocks, int threads, int reps) {
    CUdeviceptr d_tpl = subir(tpl, 17 * sizeof(unsigned long long));
    unsigned long long h_hits = 0;
    CUdeviceptr d_hits = subir(&h_hits, sizeof(h_hits));
    unsigned long long total_hilos = (unsigned long long)blocks * threads;

    unsigned long long iters_lote = 20000ULL;
    {
        h_hits = 0; CU_CHECK(cuMemcpyHtoD(d_hits, &h_hits, sizeof(h_hits)));
        struct timespec t0, t1;
        unsigned long long nonce_base = 0;
        clock_gettime(CLOCK_MONOTONIC, &t0);
        void* args[] = {&d_tpl, &iters_lote, &nonce_base, &d_hits};
        CU_CHECK(cuLaunchKernel(g_f_bench, blocks, 1, 1, threads, 1, 1, 0, 0, args, 0));
        CU_CHECK(cuCtxSynchronize());
        clock_gettime(CLOCK_MONOTONIC, &t1);
        double s = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
        double objetivo = 0.5;
        double factor = objetivo / (s > 1e-6 ? s : 1e-6);
        double nueva = iters_lote * factor;
        iters_lote = (unsigned long long)(nueva < 1000.0 ? 1000.0 : nueva);
    }

    for (int r = 1; r <= reps; r++) {
        h_hits = 0; CU_CHECK(cuMemcpyHtoD(d_hits, &h_hits, sizeof(h_hits)));
        unsigned long long total_hashes = 0, nonce_base = 0;
        struct timespec t0, tnow;
        clock_gettime(CLOCK_MONOTONIC, &t0);
        double transcurrido = 0;
        while (transcurrido < duracion_s) {
            void* args[] = {&d_tpl, &iters_lote, &nonce_base, &d_hits};
            CU_CHECK(cuLaunchKernel(g_f_bench, blocks, 1, 1, threads, 1, 1, 0, 0, args, 0));
            CU_CHECK(cuCtxSynchronize());
            total_hashes += total_hilos * iters_lote;
            nonce_base += total_hilos * iters_lote;
            clock_gettime(CLOCK_MONOTONIC, &tnow);
            transcurrido = (tnow.tv_sec - t0.tv_sec) + (tnow.tv_nsec - t0.tv_nsec) / 1e9;
        }
        CU_CHECK(cuMemcpyDtoH(&h_hits, d_hits, sizeof(h_hits)));
        printf("rep=%d blocks=%d threads=%d hashes=%llu segundos=%.6f hs=%.3f hits=%llu\n",
               r, blocks, threads, total_hashes, transcurrido, total_hashes / transcurrido, h_hits);
        fflush(stdout);
    }
    cuMemFree(d_tpl); cuMemFree(d_hits);
}

int main(int argc, char** argv) {
    if (argc < 4) {
        fprintf(stderr, "uso: %s <kernel.cu> <bench_pow_bin> <selftest dir | dump seed n fichero | "
                         "search bits max_nonce | bench dur blocks threads reps>\n", argv[0]);
        return 1;
    }
    const char* ruta_kernel = argv[1];
    const char* bench_pow_bin = argv[2];
    const char* modo = argv[3];

    inicializar_cuda_y_compilar(ruta_kernel);

    char hex[217];
    obtener_preimagen_hex(bench_pow_bin, hex);
    unsigned char bytes[108];
    hex_a_bytes(hex, bytes, 108);
    /* construir plantilla de 17 lanes con relleno SHA3 de un bloque, igual que el host original */
    unsigned char buf[136]; memset(buf, 0, 136);
    memcpy(buf, bytes, 108);
    buf[108] ^= 0x06;
    buf[135] ^= 0x80;
    unsigned long long tpl[17];
    memcpy(tpl, buf, 136);

    if (strcmp(modo, "selftest") == 0) {
        modo_selftest(argv[4]);
    } else if (strcmp(modo, "dump") == 0) {
        modo_dump(tpl, strtoull(argv[4], NULL, 10), strtoull(argv[5], NULL, 10), argv[6]);
    } else if (strcmp(modo, "search") == 0) {
        modo_search(tpl, (unsigned int)strtoul(argv[4], NULL, 10), strtoull(argv[5], NULL, 10));
    } else if (strcmp(modo, "bench") == 0) {
        modo_bench(tpl, atof(argv[4]), atoi(argv[5]), atoi(argv[6]), atoi(argv[7]));
    } else {
        fprintf(stderr, "modo desconocido: %s\n", modo);
        return 1;
    }
    return 0;
}
