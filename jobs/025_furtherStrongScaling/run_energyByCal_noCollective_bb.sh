#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=15
#SBATCH --nodes=5
#SBATCH --tasks-per-node=10
#SBATCH --constraint=haswell
#DW jobdw capacity=300GB access_mode=striped type=scratch
#DW stage_in source=/global/cscratch1/sd/lyon/irmaData2/merged_striped_large/irmaData_2C_merged.h5 destination=$DW_JOB_STRIPED/irmaData_2C_merged.h5 type=file

# Check for production
# [] Time limit
# [] Burst buffer (and below for input)
# [] OUTDIR
# [] JULIA_DEBUG
# [] no trace
# [] no -n
# [] Check -J
# [] Correct Julia program
# [] Notes
# [] Input file

module list
which julia

export JULIA_DEBUG="energyByCal,Main"

export OUTDIR=$CSCRATCH/025_futherStrongScaling/2C_noCollective_bbin
#export OUTDIR=$CSCRATCH/025_futherStrongScaling/test
mkdir -p $OUTDIR

date
date +"Time_before %s"

            #  --trace-compile=energyByCal_precompile.jl \
                #    -n 200000 \
            #  -J energyByCal.so \

srun  julia  --project=. \
             -J energyByCal_noCollective.so \
              energyByCal_noCollective.jl \
                   --notes="compiled,bbin" \
                   $DW_JOB_STRIPED/irmaData_2C_merged.h5 \
                   $OUTDIR

date +"Time_after %s"
date