# ifndef SHA3_H

# define SHA3_H

# include <hip/hip_runtime.h>

# include <verificador.h>

# define ROTL64(x , y) (((x) << (y)) | ((x) >> (64 - (y))))

__constant__ static const uint64_t RC[24] = {

	0x0000000000000001, 0x0000000000008082, 0x800000000000808A,

	0x8000000080008000, 0x000000000000808B, 0x0000000080000001,

	0x8000000080008081, 0x8000000000008009, 0x000000000000008A,

	0x0000000000000088, 0x0000000080008009, 0x000000008000000A,

	0x000000008000808B, 0x800000000000008B, 0x8000000000008089,

	0x8000000000008003, 0x8000000000008002, 0x8000000000000080,

	0x000000000000800A, 0x800000008000000A, 0x8000000080008081,

	0x8000000000008080, 0x0000000080000001, 0x8000000080008008

};

__constant__ static const int r[24] = { 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44 } ;

__constant__ static const int piln[24] = { 10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1 } ;

__device__ bool sha3(

	uint64_t * saje ,

	uint64_t sizesaje ,

	uint8_t secuencia ,

	uint8_t * hash ,

	uint8_t talla ,

	uint64_t * nonce ,

	uint64_t iter

) {

	uint64_t esponja[25] = {0} ;

	for (uint8_t i = 0 ; i < sizesaje ; i++) { esponja[i] ^= saje[i] ; }

	uint8_t i = 0 , j = 0 ;

	uint64_t temp = {0} , C[5] = {0} ;

	for (uint8_t ronda = 0 ; ronda < 24 ; ronda++) {

		for (i = 0 ; i < 5 ; i++) { C[i] = esponja[i] ^ esponja[i + 5] ^ esponja[i + 10] ^ esponja[i + 15] ^ esponja[i + 20] ; }

		for (i = 0 ; i < 5 ; i++) {

			temp = C[(i + 4) % 5] ^ ROTL64(C[(i + 1) % 5] , 1) ;

			for (j = 0 ; j < 25 ; j += 5) { esponja[j + i] ^= temp ; }

		}

		temp = esponja[1] ;

		for (i = 0 ; i < 24 ; i++) {

			j = piln[i] ;

			C[0] = esponja[j] ;

			esponja[j] = ROTL64(temp , r[i]) ;

			temp = C[0] ;

		}

		for (j = 0 ; j < 25 ; j += 5) {

			for(i = 0 ; i < 5 ; i++) { C[i] = esponja[j + i] ; }

			for (i = 0 ; i < 5 ; i++) { esponja[j + i] ^= (~C[(i + 1) % 5]) & C[(i + 2) % 5] ; }

		}

		esponja[0] ^= RC[ronda] ;

	}

	uint8_t rango = 0 ;

	uint8_t exudacion[32] ;

	for (uint8_t i = 0 ; i < talla / 8 ; i++) {

		uint64_t k = esponja[i] ;

		for (uint64_t j = 0 ; j < 8 ; j++) {

			exudacion[i * 8 + j] = (k >> (j * 8)) & 0xFF ;

		}

	}

	for (uint8_t i = 0 ; i < secuencia ; i++) { if (exudacion[i] == 0x00) { rango += 1 ; } }

	if (rango == secuencia) {

		for (uint8_t i = 0 ; i < talla ; i++) { hash[i] = exudacion[i] ; }

		* nonce = iter ;

		return true ;

	}

	return false ;

}

# endif
