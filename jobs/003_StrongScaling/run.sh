sbatch -W --nodes=3 run_strongScalingJob_compiled.sh
sbatch -W --nodes=4 run_strongScalingJob_compiled.sh
sbatch -W --nodes=5 run_strongScalingJob_compiled.sh
sbatch -W --nodes=6 run_strongScalingJob_compiled.sh
sbatch -W --nodes=8 run_strongScalingJob_compiled.sh
sbatch -W --nodes=10 run_strongScalingJob_compiled.sh
sbatch -W --nodes=12 run_strongScalingJob_compiled.sh
sbatch -W --nodes=15 run_strongScalingJob_compiled.sh
sbatch -W --nodes=20 run_strongScalingJob_compiled.sh

sbatch -W --nodes=5 --tasks-per-node=16 run_strongScalingJob_compiled.sh
sbatch -W --nodes=5 --tasks-per-node=8 run_strongScalingJob_compiled.sh
sbatch -W --nodes=5 --tasks-per-node=4 run_strongScalingJob_compiled.sh
sbatch -W --nodes=5 --tasks-per-node=2 run_strongScalingJob_compiled.sh
sbatch -W --nodes=5 --tasks-per-node=1 run_strongScalingJob_compiled.sh
