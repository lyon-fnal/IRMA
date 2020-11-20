#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=1
#SBATCH --tasks-per-node=32
#SBATCH --constraint=haswell

module list

mkdir -p $CSCRATCH/darshan

rm -rf $CSCRATCH/darshan/helloworld

srun  ./helloworld $CSCRATCH/darshan