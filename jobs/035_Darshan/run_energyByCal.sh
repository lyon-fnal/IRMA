#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=15
#SBATCH --nodes=5
#SBATCH --tasks-per-node=10
#SBATCH --constraint=haswell

# Check for production
# [] Time limit
# [] OUTDIR
# [] JULIA_DEBUG
# [] no trace
# [] no -n
# [] Check -J
# [] Correct Julia script
# [] Notes
# [] OutPrefix
# [] Input file

module list
which julia

export JULIA_DEBUG="energyByCal,Main"
export DXT_ENABLE_IO_TRACE=1

export OUTDIR=$CSCRATCH/035_Darshan
mkdir -p $OUTDIR

date
date +"Time_before %s"

            #  --trace-compile=energyByCal_precompile.jl \
                #    -n 200000 \
            #  -J energyByCal.so \
            # HDF5_DEBUG=trace ? Doesn't seeem to work

srun    --export=ALL,LD_PRELOAD=libdarshan.so \
        julia --project=. -J energyByCal.so energyByCal.jl \
            --notes="compiled,collective,darshan" --collective \
            $CSCRATCH/irmaData2/merged_striped_large/irmaData_2C_merged.h5 $OUTDIR

date +"Time_after %s"
date