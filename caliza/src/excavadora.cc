# include <hip/hip_runtime.h>

# include <iostream>

# include <vector>

# include <memory>

# include <verificador.h>

# include <sha3.h>

# include <proto.h>

template <uint8_t TASA>

__global__ void kernel(

	uint64_t * bitsaje ,

	uint64_t sizesaje ,

	uint8_t secuencia ,

	uint8_t * hash ,

	uint64_t * nonce ,

	uint32_t * bandera

) {

	extern __shared__ uint64_t puente[] ;

	__shared__ uint8_t exito ;

	int index = blockIdx.x * blockDim.x + threadIdx.x ;

	if (threadIdx.x == 0) {

		exito = 0x00 ;

		for (uint8_t i = 0 ; i < sizesaje ; i++) {

			puente[i] = bitsaje[i] ;

		}

	}

	__syncthreads() ;

	uint64_t saje[TASA] ;

	for (uint8_t iter = 0 ; iter < sizesaje ; iter++) { saje[iter] = puente[iter] ; }

	uint64_t x = 0xFFFFFFFFFFFFFFFF ;

	uint32_t y = gridDim.x * blockDim.x ;

	uint64_t k = x / y ;

	uint64_t v = index * k ;

	uint64_t z = (index == y - 1) ? (x) : ((index + 1) * k - 1) ;

	for (uint64_t iter = v ; iter <= z ; iter++) {

		uint8_t bit[8] ;

		for (uint8_t l = 0 ; l < 8 ; l++) { bit[l] = (iter >> (8 * l)) & 0xFF ; }

		for (uint8_t t = 48 ; t < 56 ; t++) {

			uint8_t j = t % 8 ;

			uint8_t f = t / 8 ;

			uint64_t clean = ~(0xFFULL << (j * 8)) ;

			uint64_t conversion = static_cast <uint64_t> (bit[j]) << (j * 8) ;

			saje[f] = (saje[f] & clean) | conversion ;

	 	}

		bool ganador = sha3(saje , sizesaje , secuencia , hash , TASA , nonce , iter) ;

		if (ganador) { atomicCAS(bandera , 0x00 , 0xFF) ; }

		if (iter % 1024 == 0) {

			if (threadIdx.x == 0 && iter % 2048 == 0) {

				uint32_t global = * bandera ;

				exito = (global != 0) ? 0xFF : 0x00 ;

			}

			__syncthreads() ;

			if (exito == 0xFF) { break ; }

		}

	}

}

template <uint8_t TASA>

Shackle lanzador(

	std :: vector <uint64_t> saje ,

	uint8_t talla ,

	uint8_t secuencia ,

	size_t dispositivo ,

	uint16_t setexe

) {

    int device_total ;

    VERIFICADOR(hipGetDeviceCount(&device_total)) ;

	for (uint32_t iter = 0 ; iter < device_total ; iter++) {

		if (dispositivo == iter) {

		    hipDeviceProp_t dispositivo ;

			VERIFICADOR(hipGetDeviceProperties(&dispositivo , iter)) ;

			int x = dispositivo.multiProcessorCount * dispositivo.maxThreadsPerMultiProcessor ;

			int y = dispositivo.maxThreadsPerBlock ;

			uint32_t r = dispositivo.multiProcessorCount * dispositivo.maxBlocksPerMultiProcessor ;

			const uint32_t z = x / r ;

			if (setexe > 0 && setexe <= r && z > 0 && z <= y) {

				RAII<uint64_t> bitsaje = HIPMALLOC<uint64_t>(saje.size()) ;

				VERIFICADOR(hipMemcpy(bitsaje.get() , saje.data() , saje.size() * sizeof(uint64_t) , hipMemcpyHostToDevice)) ;

				RAII<uint8_t> hash = HIPMALLOC<uint8_t>(talla) ;

				RAII<uint64_t> nonce = HIPMALLOC<uint64_t>(1) ;

				RAII<uint32_t> bandera = HIPMALLOC<uint32_t>(1) ;

				hipLaunchKernelGGL(

					kernel<TASA> ,

					dim3(setexe) ,

					dim3(z) ,

					saje.size() * sizeof(uint64_t) ,

					0 ,

					bitsaje.get() ,

					saje.size() ,

					secuencia ,

					hash.get() ,

					nonce.get() ,

					bandera.get()

				);

				VERIFICADOR(hipGetLastError()) ;

				VERIFICADOR(hipDeviceSynchronize()) ;

				Shackle tera(talla) ;

				VERIFICADOR(hipMemcpy(tera.hash.get() , hash.get() , talla * sizeof(uint8_t) , hipMemcpyDeviceToHost)) ;

				VERIFICADOR(hipMemcpy(&tera.nonce , nonce.get() , sizeof(uint64_t) , hipMemcpyDeviceToHost)) ;

				return tera ;

			} else { std :: cerr << "fallo/inicializacion/kernel" << std :: endl ; return Shackle() ; }

		} else { std :: cerr << "identificador/dispositivo/invalido" << std :: endl ; return Shackle() ; }

	}

}

Shackle excavadora(

	std :: vector <uint64_t> saje ,

	uint8_t talla ,

	uint8_t secuencia ,

	size_t dispositivo ,

	uint16_t setexe

) {

	switch(talla * 8) {

		case 224 : return lanzador<18>(saje , talla , secuencia , dispositivo , setexe) ; break ;

		case 256 : return lanzador<17>(saje , talla , secuencia , dispositivo , setexe) ; break ;

		case 384 : return lanzador<13>(saje , talla , secuencia , dispositivo , setexe) ; break ;

		case 512 : return lanzador<9>(saje , talla , secuencia , dispositivo , setexe) ; break ;

		default : std :: cerr << "fallo/size/sha3" << std :: endl ; return Shackle() ; break ;

	}

}
