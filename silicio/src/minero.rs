use flutter_rust_bridge :: frb ;

use std :: {

	sync :: Arc ,

	time :: Instant

};

use tokio :: {

	spawn ,

	time :: { interval , Duration }

};

use sha3 :: { Digest , Sha3_256 } ;

use serde :: { Serialize , Deserialize } ;

use atenas :: erromacro ;

use crate :: core :: tonico :: silicio :: {

	colectivo :: {

		extraer_rango_mineria ,

		extraer_hilos_mineria ,

		insertar_estado_mineria ,

		extraer_estado_mineria ,

		insertar_estado_silicio ,

		extraer_estado_silicio

	}

};

# [derive(Clone , Debug , Serialize , Deserialize)]

struct Bloque {

	aleatorio : String ,

	tiempo : String ,

	posicion : u64 ,

	bits : u8 ,

	pago : u16

}

# [frb(ignore)]

pub async fn mineria() {

	// lanzar esta funcion con rayon

	let excavadora = spawn(

		async move {

			let hilos = extraer_hilos_mineria().await ;

			if hilos >= 1 && (hilos <= num_cpus :: get() as u32)

			&& extraer_estado_silicio().await

			&& !extraer_estado_mineria().await {

				// let (inicio , fin) : (u128 , u128) = extraer_rango_mineria().await ;

				let mut rango : Vec <(u32 , u128 , u128)> = Vec :: new() ;

				let (inicio , fin) : (u128 , u128) = (0 , u128 :: MAX) ;

				let bloque : u128 = (fin - inicio) / (hilos as u128) ;

				for iter in 0..hilos {

					let principio = inicio + (iter as u128 * bloque) ;

					let finalizacion = if iter == hilos - 1 { fin } else { principio + bloque } ;

					rango.push((iter , principio , finalizacion)) ;

				}

				let bloque = Bloque {

					aleatorio : String :: from("zeZ5XGq0Q2bfHIMhMPJjMzMVZjWQH6dq3YL8UpWtWTk4f5yqiur3ykp5") ,

					tiempo : String :: from("2024-10-17 00:00:00") ,

					posicion : 0 ,

					bits : 8 ,

					pago : 5

				};

				let bloque_atomico : Arc <Bloque> = Arc	:: new(bloque.clone()) ;

				let serializacion : Arc <[u8]> = match bincode :: serialize(&bloque) {

					Ok(bytes) => Arc :: from(bytes) ,

					Err(erro) => { erromacro!(erro) ; return }

					// LOS LIMITES DE LAS SUMAS PARCIALES DE T SOBRE UN SUBRANGO DE K SON INMUTABLES POR NATURALEZA

					// LO QUE VERDADERAMENTE IMPORTA ES ESCRIBIR A UN RITMO CONSTANTE Y DE LA FORMA CORRECTA :)

					// POR TNATO SI ESCRIBES DE LA FORMA CORRECTA PODRAS HACER LAS COSAS DE UNA FORMA MUCHO MAS FLUIDA.

				};

				let mut intervalo = interval(Duration :: from_millis(250)) ;

				let mut tareas = vec![] ;

				let rango_atomico : Arc < Vec < (u32 , u128 , u128) > > = Arc :: new(rango.clone()) ;

				let mut controlador_tarea : bool = false ;

				loop {

					if !controlador_tarea {

						controlador_tarea = true ;

						insertar_estado_mineria(true).await ;

						let rango_atomico_referencia : Arc < Vec <(u32 , u128 , u128)> > = Arc :: clone(&rango_atomico) ;

						for &(iter , inicializacion , finalizacion) in rango_atomico_referencia.iter() {

							let bitelock : Arc <[u8]> = Arc :: clone(&serializacion) ;

							let bloque_referencia : Arc <Bloque> = Arc :: clone(&bloque_atomico) ;

							tareas.push(

								spawn(

									async move {

										let mut hasher = Sha3_256 :: new() ;

										let mut foriter : u64 = 0 ;

										for nonce in inicializacion ..= finalizacion {

											hasher.update(&bitelock) ;

											hasher.update(&nonce.to_le_bytes()) ;

											let resultado = hasher.finalize_reset() ;

											let mut contador : u8 = 0 ;

											let limite : u8 = bloque_referencia.bits / 4 ;

											if !extraer_estado_mineria().await { break ; }

										}

									}

			            		)

							);

						}

					}

					if !extraer_estado_mineria().await {

						// diferencias entre abort y shutdown

						for tarea in &tareas { tarea.abort() ; }

						tareas.clear() ; // ?? es necesario si el programa finaliza ?

						insertar_estado_silicio(false).await ;

						println!("finalizando mineria") ;

						break ;

					}

					intervalo.tick().await ;

				}

			} else { erromacro!("fallo/reparticion/hilos") ; }

		}

	);

	let _ = excavadora.await ;

}

// let pool = rayon :: ThreadPoolBuilder :: new().num_threads(8).build().unwrap() ;


/*for &byte in &resultado {

	if contador < limite {

		if byte == 0x00 { contador += 1 ; } else { break ; }

	} else { break }

}

if contador == limite {

	let mut tiempo = Instant :: now() ;

	// enviar datos al servidor

}*/
