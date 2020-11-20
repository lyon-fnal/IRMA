set -x
sbatch -W --nodes=10 --tasks-per-node=1 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=2 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=4 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=6 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=10 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=14 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=16 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=20 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=24 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=28 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=32 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=48 run_energyByCal.sh
sbatch -W --nodes=10 --tasks-per-node=64 run_energyByCal.sh