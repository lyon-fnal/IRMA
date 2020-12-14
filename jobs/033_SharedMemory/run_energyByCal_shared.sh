#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=5
#SBATCH --tasks-per-node=31
#SBATCH --constraint=haswell

which julia

export JULIA_DEBUG=""

export OUTDIR=$CSCRATCH/033_energyByCal_shared
mkdir -p $OUTDIR

egrep --color 'Mem|Cache|Swap' /proc/meminfo

date
t1=`date +"%s"`
echo "t1 $t1"

            #  --trace-compile=energyByCal_shared_precompile.jl \
                #    -n 200000 \
            #  -J energyByCal_shared.so \

srun  julia  -J energyByCal_shared.so --project=. \
             energyByCal_shared.jl \
                 --notes="testRun" \
                 --nReaders=6 \
                 $CSCRATCH/irmaData2/merged_striped_large/irmaData_2C_merged.h5 \
                 $OUTDIR

t2=`date +"%s"`
date
echo "t2 $t2"
tt=`expr $t2 - $t1`
awk "BEGIN {print \"total_time\", $tt, $tt / 60}"