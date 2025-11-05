# include <vector>

# include <capnp/message.h>

# include <capnp/serialize.h>

# include <proto.h>

# include <excavadora.h>

# include <tera.capnp.h>

using namespace std ;

vector <uint8_t> mineria(

	vector <uint64_t> saje ,

	uint8_t talla ,

	uint8_t secuencia ,

	size_t dispositivo ,

	uint16_t setexe

) {

	Shackle tera = excavadora(saje , talla , secuencia , dispositivo , setexe) ;

	capnp :: MallocMessageBuilder terasaje ;

	Tera :: Builder proto = terasaje.initRoot <Tera>() ;

	proto.setHash(capnp :: Data :: Reader(tera.hash.get() , tera.size)) ;

	proto.setNonce(tera.nonce) ;

	kj :: Array <capnp :: word> plano = capnp :: messageToFlatArray(terasaje) ;

	kj :: ArrayPtr <const uint8_t> vista = plano.asBytes() ;

	std :: vector <uint8_t> protosaje(vista.begin() , vista.end()) ;

	return protosaje ;

}
