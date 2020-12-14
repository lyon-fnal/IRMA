#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --constraint=haswell

which julia


date
date +"Time_before %s"

            #  --trace-compile=energyByCal_precompile.jl \
                #    -n 200000 \
            #  -J energyByCal.so \

srun  julia  --project willItAllocate.jl

date +"Time_after %s"
date