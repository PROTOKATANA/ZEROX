// Latencia de una cadena dependiente de AES-128, que es exactamente lo que hace el PoT:
// cur = AES128_encrypt(key, cur), N veces, cada una dependiente de la anterior.
#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <wmmintrin.h>
#include <smmintrin.h>

static inline double ahora(void){
  struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec*1e-9;
}

int main(void){
  // Clave expandida ficticia: los valores no importan para la latencia, solo la dependencia.
  __m128i rk[11];
  for (int i=0;i<11;i++) rk[i] = _mm_set_epi32(0x03020100+i,0x07060504,0x0b0a0908,0x0f0e0d0c);

  __m128i x = _mm_set_epi32(1,2,3,4);
  const long N = 50000000L;           // 50 M bloques AES-128

  // calentamiento
  for (long i=0;i<2000000L;i++){
    x = _mm_xor_si128(x, rk[0]);
    for (int r=1;r<10;r++) x = _mm_aesenc_si128(x, rk[r]);
    x = _mm_aesenclast_si128(x, rk[10]);
  }

  double t0 = ahora();
  for (long i=0;i<N;i++){
    x = _mm_xor_si128(x, rk[0]);
    for (int r=1;r<10;r++) x = _mm_aesenc_si128(x, rk[r]);
    x = _mm_aesenclast_si128(x, rk[10]);
  }
  double t1 = ahora();

  double seg = t1-t0;
  double ns_bloque = seg*1e9/N;
  printf("sumidero              %016llx\n", (unsigned long long)(uint64_t)_mm_cvtsi128_si64(x));
  printf("bloques AES-128       %ld\n", N);
  printf("tiempo                %.4f s\n", seg);
  printf("ns por bloque         %.4f ns\n", ns_bloque);
  printf("ns por ronda AESENC   %.4f ns\n", ns_bloque/10.0);
  return 0;
}
