#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=10
#SBATCH --nodes=1
#SBATCH --tasks-per-node=32
#SBATCH --constraint=haswell

#export JULIA_DEBUG="energyByCal,Main,IRMA"
#export NALLROWS=200000
srun julia --project=$HOME/IRMA/jobs/023_energyByCal --sysimage energyByCal.so energyByCal.jl
