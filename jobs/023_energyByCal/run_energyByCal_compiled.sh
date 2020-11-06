#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=10
#SBATCH --nodes=10
#SBATCH --tasks-per-node=32
#SBATCH --constraint=haswell

#export JULIA_DEBUG="energyByCal,Main,IRMA"
#export NALLROWS=200000
export GM2_ERA=2E
srun julia --project=$HOME/IRMA/jobs/023_energyByCal --sysimage energyByCal.so energyByCal.jl
