#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=1
#SBATCH --nodes=1
#SBATCH --constraint=haswell
#BB create_persistent name=irma capacity=250GB access_mode=striped type=scratch