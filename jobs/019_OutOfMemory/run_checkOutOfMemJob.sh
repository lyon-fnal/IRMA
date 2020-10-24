#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=00:10:00
#SBATCH --nodes=1
#SBATCH --tasks-per-node=2
#SBATCH --constraint=haswell
#SBATCH --perf=vtune

module load vtune

export JULIA_DEBUG="outOfMemJob,IRMA"
vtune -finalization-mode=deferred -collect memory-consumption -r $PWD/vtune_mem srun julia --project=$HOME/IRMA/jobs/019_OutOfMemory outOfMemJob.jl
