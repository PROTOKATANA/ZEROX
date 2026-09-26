#!/usr/bin/env bash
# Resume los crudos medir-P*.tsv en una tabla por grupo (mediana, p99 y medias).
# Sin Python: awk + sort. Columnas crudas:
#   1 modo 2 piezas 3 hilos 4 estrategia 5 L 6 apertura 7 posicion 8 tablas 9 hojas
#   10 wall_ns 11 cpu_ns 12 verif 13 almacenamiento_bytes 14 vmhwm_kib
set -u
cd "$(dirname "$0")"
mkdir -p resultados
{
  printf 'piezas\thilos\testrategia\tL\tN\talmacenamiento_bytes\ttablas_media\ttablas_max\thojas_max\twall_mediana_us\twall_p99_us\tcpu_mediana_us\tverif_ok\tram_kib\n'
  awk -F'\t' '
    FNR==1{next}
    $1=="modo"{next}
    {
      g=$2"\t"$3"\t"$4"\t"$5;
      n[g]++;
      w[g,n[g]]=$10; c[g,n[g]]=$11; h[g,n[g]]=$9; tb[g,n[g]]=$8;
      st[g]=$13; ram[g]=$14; vf[g]+=$12; sumtb[g]+=$8;
    }
    END{
      for (g in n) {
        m=n[g];
        for(i=1;i<=m;i++){ a[i]=w[g,i]+0; b[i]=c[g,i]+0; }
        for(i=2;i<=m;i++){
          va=a[i]; vb=b[i]; j=i-1;
          while(j>=0 && a[j]>va){ a[j+1]=a[j]; b[j+1]=b[j]; j--; }
          a[j+1]=va; b[j+1]=vb;
        }
        med=a[int((m+1)/2)];
        idx=int(0.99*m); if(idx<1) idx=1;
        p99=a[idx];
        medcpu=b[int((m+1)/2)];
        tbmax=0; hmax=0;
        for(i=1;i<=m;i++){ if(tb[g,i]+0>tbmax) tbmax=tb[g,i]+0; if(h[g,i]+0>hmax) hmax=h[g,i]+0; }
        printf "%s\t%d\t%d\t%.1f\t%d\t%d\t%.1f\t%.1f\t%.1f\t%d\t%d\n", g, m, st[g], sumtb[g]/m, tbmax, hmax, med/1000, p99/1000, medcpu/1000, vf[g], ram[g];
      }
    }' resultados/medir-P*.tsv | sort -t $'\t' -k1,1n -k2,2n -k3,3 -k4,4n
} > resultados/resumen-mediciones.tsv
cat resultados/resumen-mediciones.tsv
