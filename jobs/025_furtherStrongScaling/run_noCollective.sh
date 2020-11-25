# set -x
# sbatch -W --nodes=10 --tasks-per-node=2 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=10 --tasks-per-node=8 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=10 --tasks-per-node=16 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=10 --tasks-per-node=32 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=10 --tasks-per-node=64 run_energyByCal_noCollective_bb.sh

sbatch -W --nodes=4 --tasks-per-node=1 run_energyByCal_noCollective.sh
sbatch -W --nodes=4 --tasks-per-node=2 run_energyByCal_noCollective.sh
sbatch -W --nodes=4 --tasks-per-node=4 run_energyByCal_noCollective.sh

# sbatch -W --nodes=4 --tasks-per-node=2 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=4 --tasks-per-node=8 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=4 --tasks-per-node=16 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=4 --tasks-per-node=32 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=4 --tasks-per-node=64 run_energyByCal_noCollective_bb.sh

# sbatch -W --nodes=20 --tasks-per-node=2 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=20 --tasks-per-node=8 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=20 --tasks-per-node=16 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=20 --tasks-per-node=32 run_energyByCal_noCollective_bb.sh
# sbatch -W --nodes=20 --tasks-per-node=64 run_energyByCal_noCollective_bb.sh