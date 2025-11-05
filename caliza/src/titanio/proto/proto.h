# ifndef TERAPLEX_H

# define TERAPLEX_H

# include <memory>

struct Shackle {

	std :: unique_ptr <uint8_t[]> hash ;

	uint64_t nonce = 0 ;

	size_t size ;

	Shackle() = default ;

	explicit Shackle(size_t talla) : hash(capacidad(talla)) , size(talla) {}

	private : static std :: unique_ptr <uint8_t[]> capacidad(size_t talla) {

		if (talla == 0) { throw std :: invalid_argument("Error/proporcion/vector") ; }

		return std :: make_unique <uint8_t[]> (talla) ;

	}

};

# endif
