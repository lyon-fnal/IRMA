set -x
sbatch -W --nodes=10 run_energyByCal_compiled.sh
sbatch -W --nodes=10 --tasks-per-node=16 run_energyByCal_compiled.sh
sbatch -W --nodes=10 --tasks-per-node=8 run_energyByCal_compiled.sh
sbatch -W --nodes=10 --tasks-per-node=4 run_energyByCal_compiled.sh
sbatch -W --nodes=10 --tasks-per-node=2 run_energyByCal_compiled.sh
sbatch -W --nodes=10 --tasks-per-node=1 run_energyByCal_compiled.sh