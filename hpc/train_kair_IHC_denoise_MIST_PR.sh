#!/bin/bash
#SBATCH --job-name=kair_IHC_den
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=60G
#SBATCH --time=23:00:00
#SBATCH -A ap_invilab
#SBATCH -p ampere_gpu
#SBATCH --gpus-per-node=1
#SBATCH -o /data/antwerpen/212/vsc21216/projects/logs/kair_IHC_denoise_%j.out
#SBATCH -e /data/antwerpen/212/vsc21216/projects/logs/kair_IHC_denoise_%j.err

set -euo pipefail

CONTAINER="$VSC_SCRATCH/containers/uformer_nvidia.sif"
CODE_DIR="$VSC_DATA/projects/code"
DATA_SQSH="$VSC_SCRATCH/MIST_PR.sqsh"
OUTPUT_DIR="$VSC_DATA/projects/outputs/kair_IHC_denoise_MIST_PR"

mkdir -p "$OUTPUT_DIR"

nvidia-smi --query-gpu=timestamp,index,utilization.gpu,utilization.memory,memory.used,memory.total \
           --format=csv -l 5 > "$OUTPUT_DIR/gpu_usage.csv" &
GPU_LOG_PID=$!

srun apptainer exec \
    --nv \
    -B "$CODE_DIR":/code \
    -B "$DATA_SQSH":/data:image-src=/ \
    -B "$OUTPUT_DIR":/output \
    "$CONTAINER" \
    bash /code/KAIR/train_kair_IHC_denoise.sh options/swinir/train_swinir_IHC_denoise_MIST_PR_HPC.json

kill $GPU_LOG_PID || true
