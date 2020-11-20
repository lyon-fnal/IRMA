#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=20
#SBATCH --nodes=5
#SBATCH --tasks-per-node=10
#SBATCH --constraint=haswell

# Check for production
# [] Time limit
# [] OUTDIR
# [] JULIA_DEBUG
# [] no trace
# [] no -n
# [] Notes
# [] Input file

module list
which julia

export JULIA_DEBUG="energyByCal,Main"

export OUTDIR=$CSCRATCH/025_futherStrongScaling/tenNodes_2C_mpio
#export OUTDIR=$CSCRATCH/025_futherStrongScaling/test
mkdir -p $OUTDIR

date
date +"Time_before %s"

            #  --trace-compile=energyByCal_precompile.jl \
                #    -n 200000 \

srun  julia  --project=. \
             -J energyByCal.so \
              energyByCal.jl \
                   --notes="compiled,mpio" \
                   $CSCRATCH/irmaData2/merged_striped_large/irmaData_2C_merged.h5 \
                   $OUTDIR

date +"Time_after %s"
date