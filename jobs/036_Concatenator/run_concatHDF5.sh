#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=10
#SBATCH --tasks-per-node=1
#SBATCH --constraint=haswell

which julia

export JULIA_DEBUG="all"

egrep --color 'Mem|Cache|Swap' /proc/meminfo

date
t1=`date +"%s"`
echo "t1 $t1"

            #  --trace-compile=energyByCal_shared_precompile.jl \
                #    -n 200000 \
            #  -J energyByCal_shared.so \

srun  julia  --project=. \
             concatHDF5.jl \
                 -l \
                 -m 0.8 \
                 -n 0 \
                 bla.toml \
                 bla.out \
                 $CSCRATCH/irmaData2/2C/irmaData_14019*.h5

t2=`date +"%s"`
date
echo "t2 $t2"
tt=`expr $t2 - $t1`
awk "BEGIN {print \"total_time\", $tt, $tt / 60}"