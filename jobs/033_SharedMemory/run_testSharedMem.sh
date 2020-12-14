#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=2
#SBATCH --tasks-per-node=31
#SBATCH --constraint=haswell

which julia

export JULIA_DEBUG="testSharedMem_mpi,Main,IRMA"

egrep --color 'Mem|Cache|Swap' /proc/meminfo
date
date +"Time_before %s"


            #  --trace-compile=energyByCal_precompile.jl \
                #    -n 200000 \
            #  -J energyByCal.so \

srun  julia  --project=. \
             testSharedMem_mpi.jl

date +"Time_after %s"
date