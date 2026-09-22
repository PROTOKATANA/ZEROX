# perfil.jl — perfil estadístico del barrido representativo (LINEO §6)
using Profile
using RevelacionV1
const RV = RevelacionV1
cfg = Config{Float64}(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                      Lrev = 7050.0, con_h = true, espera = false, cruce = true, lead_h = 4.0,
                      j_ini = 150)
kw = (rhos = [1.05, 1.5, 2.0, 3.0, 5.0, 9.0], n_rep = 64, J = 1500, alpha = 0.33,
      seed = UInt64(0x5a5a), nb = 4096, bin = 32.0, v_lo = -1024.0, boot_ref = 0.0,
      modo_off = :geom)
barrer!(cfg; kw..., nthreads = 1)          # calentar JIT
Profile.clear()
@profile for _ in 1:5
    barrer!(cfg; kw..., nthreads = 1)
end
Profile.print(format = :flat, sortedby = :count, mincount = 20)
