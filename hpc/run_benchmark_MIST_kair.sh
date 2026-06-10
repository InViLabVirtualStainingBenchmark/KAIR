#!/bin/bash
#SBATCH --job-name=infer_kair_MIST
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH -A ap_invilab
#SBATCH -p pascal_gpu
#SBATCH --gpus=1
#SBATCH -o /data/antwerpen/212/vsc21216/projects/logs/infer_kair_MIST_%j.out
#SBATCH -e /data/antwerpen/212/vsc21216/projects/logs/infer_kair_MIST_%j.err

set -euo pipefail

STAIN=${1:-ER}   # pass stain as arg: ER, HER2, Ki67, PR

SHARED=/scratch/antwerpen/grp/ap_invilab_td_thesis
SQSH=${SHARED}/MIST_${STAIN}_neutral.sqsh
CONTAINER=${VSC_SCRATCH}/containers/basicsr_nvidia.sif
CODE_DIR=${VSC_DATA}/projects/code
OUTPUT_BASE=${SHARED}/benchmark_inference

WEIGHTS=${VSC_DATA}/projects/outputs/kair_MIST_${STAIN}_vaughan/swinir_HE2IHC_MIST_${STAIN}/models/90000_G.pth

echo "========================================"
echo " Job     : ${SLURM_JOB_ID}"
echo " Model   : KAIR"
echo " Stain   : ${STAIN}"
echo " Weights : ${WEIGHTS}"
echo "========================================"

srun apptainer exec \
    --nv \
    -B ${SQSH}:/data:image-src=/ \
    -B ${CODE_DIR}:/code \
    -B ${OUTPUT_BASE}:/output \
    --env VSC_DATA=${VSC_DATA} \
    ${CONTAINER} \
    python3 /code/benchmark_inference.py \
        --model   kair \
        --dataset MIST_${STAIN} \
        --weights ${WEIGHTS} \
        --output_base /output

echo "Done — results at: ${OUTPUT_BASE}/kair_MIST_${STAIN}"
