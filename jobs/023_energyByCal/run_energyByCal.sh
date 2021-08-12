#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --constraint=haswell

export JULIA_DEBUG="energyByCal,Main,IRMA"
export NALLROWS=200000
#--trace-compile=energyByCal_precompile.jl
srun julia --project=$HOME/IRMA/jobs/023_energyByCal  energyByCal.jl
