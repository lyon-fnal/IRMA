#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=1
#SBATCH --tasks-per-node=2
#SBATCH --constraint=haswell

export JULIA_DEBUG="outOfMemJob,IRMA"
srun julia --project=$HOME/IRMA/jobs/019_OutOfMemory outOfMemJob.jl
