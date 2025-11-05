# ifndef VERIFICADOR_H

# define VERIFICADOR_H

# include <hip/hip_runtime.h>

# include <iostream>

# include <string>

constexpr int exiterro = -1 ;

inline void verificador(hipError_t error , const std :: string & archivo , int linea) {

	if (error != hipSuccess) {

		std :: cerr << hipGetErrorString(error) << std :: endl ;

		std :: cerr << archivo << std :: endl ;

		std :: cerr << "Linea : " << linea << std :: endl ;

		std :: exit(exiterro) ;

	}

}

# define VERIFICADOR(error) verificador(error , __FILE__ , __LINE__)

# endif


# ifndef MALLOC_H

# define MALLOC_H

# include <hip/hip_runtime.h>

# include <memory>

struct Destructor { void operator()(void * crudo) const { if (crudo) VERIFICADOR(hipFree(crudo)) ; } } ;

template <typename tipo> using RAII = std :: unique_ptr<tipo , Destructor> ;

template <typename tipo>

RAII <tipo> HIPMALLOC(size_t cantidad) {

	tipo * crudo = nullptr ;

	VERIFICADOR(hipMalloc(&crudo , cantidad * sizeof(tipo))) ;

	return RAII <tipo> (crudo) ;

}

# endif
