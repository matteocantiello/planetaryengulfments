# Source this before ./mk, ./rn or ./re:  source mesa_env.sh
# Keep the MESA SDK apart from Lmod compiler/MPI modules and conda in the same shell.
export MESASDK_ROOT=/mnt/home/mcantiello/mesasdk-26.6.1
source "$MESASDK_ROOT/bin/mesasdk_init.sh"
export MESA_DIR=/mnt/home/mcantiello/mesa-26.04.1
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-8}
