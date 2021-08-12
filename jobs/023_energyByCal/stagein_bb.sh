#!/bin/bash
#SBATCH --qos=debug
#SBATCH --time=5
#SBATCH --nodes=1
#SBATCH --constraint=haswell
#DW persistentdw name=irma
#DW stage_in source=/global/cscratch1/sd/lyon/irmaData/irma_2D.h5 destination=$DW_PERSISTENT_STRIPED_irma/irma_2D.h5 type=file

ls $DW_PERSISTENT_STRIPED_irma/