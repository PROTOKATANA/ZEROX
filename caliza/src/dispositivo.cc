# include <hip/hip_runtime.cc>

# include <verificador.h>

using namespace std ;

vector <uint8_t> dispositivo() {

	// retornar un mensaje capnp en formato de bytes

    int device_total ;

    VERIFICADOR(hipGetDeviceCount(&device_total)) ;

	for (uint32_t iter = 0 ; iter < device_total ; iter++) {

	    hipDeviceProp_t dispositivo ;

		VERIFICADOR(hipGetDeviceProperties(&dispositivo , iter)) ;

		uint32_t bloques = dispositivo.multiProcessorCount * dispositivo.maxBlocksPerMultiProcessor ;

	}

}

// int n = dispositivo.name ; // char[256]

// int i = dispositivo.uuid ; // hipUUID
