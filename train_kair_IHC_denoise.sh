#!/bin/bash
CONFIG=${1:-options/swinir/train_swinir_IHC_denoise_HPC.json}
export PYTHONPATH=/code/KAIR:/usr/local/lib64/python3.9/site-packages:$PYTHONPATH
cd /code/KAIR
python3 main_train_psnr.py \
    --opt $CONFIG \
    2>&1 | tee /output/train_log.txt
