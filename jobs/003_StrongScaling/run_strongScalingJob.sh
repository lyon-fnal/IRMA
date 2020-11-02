#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --constraint=haswell

export JULIA_DEBUG="strongScalingJob,IRMA"
export NALLROWS=200000
srun julia --project=$HOME/IRMA/jobs/003_StrongScaling strongScalingJob.jl
