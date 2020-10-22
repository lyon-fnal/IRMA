#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=2
#SBATCH --tasks-per-node=32
#SBATCH --constraint=haswell

export JULIA_DEBUG="strongScalingJob,IRMA"
srun julia --project=$HOME/IRMA/jobs/003_StrongScaling strongScalingJob.jl
