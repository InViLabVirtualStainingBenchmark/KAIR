--- 
# KAIR/SwinIR: HPC Virtual Staining Benchmark
H&E → IHC Translation · BCI & MIST Datasets · CalcUA HPC (Vaughan A100)

> This documents HPC training, inference, and evaluation for KAIR/SwinIR as part of the InViLab Virtual Staining Benchmark. For local setup and initial experiments, see [DOCUMENTATION.md](DOCUMENTATION.md).

---

## Table of Contents
- [Overview](#overview)
- [Environment](#environment)
- [Cluster Structure](#cluster-structure)
- [Dataset Preparation](#dataset-preparation)
- [Training](#training)
- [Inference](#inference)
- [Evaluation](#evaluation)
- [Results](#results)
- [Modifications](#modifications)
- [Notes](#notes)

---

## Overview

SwinIR uses a Swin Transformer backbone for image restoration. In this benchmark it is applied to paired H&E → IHC virtual staining using Charbonnier loss. Training is done via the KAIR framework using `main_train_psnr.py`.

**Datasets:**

| Dataset | Task | Train | Val | Test |
|---------|------|-------|-----|------|
| BCI | H&E → IHC | 3896 | 488 | 489 |
| MIST ER | H&E → ER IHC | 4153 | 500 | 500 |
| MIST HER2 | H&E → HER2 IHC | 4642 | 500 | 500 |
| MIST Ki67 | H&E → Ki67 IHC | 4361 | 500 | 500 |
| MIST PR | H&E → PR IHC | 4139 | 500 | 500 |

**Key training settings:**

| Parameter | Value |
|-----------|-------|
| Architecture | SwinIR (embed_dim=128, depths=[6×6]) |
| Input patch size | 128 × 128 |
| Batch size | 8 |
| Total iterations | 100,000 |
| Loss function | Charbonnier |
| Optimizer | Adam (lr=2e-4) |
| LR scheduler | MultiStepLR (milestone=50k, gamma=0.5) |

---

## Environment

Training runs inside an Apptainer container on the **CalcUA Vaughan cluster** (NVIDIA A100 40GB, `ampere_gpu` partition).

**Container:** `basicsr_nvidia.sif`
- Base image: `pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime`
- PyTorch: 2.1.2+cu121
- Python: 3.9

**Container location:**
```
$VSC_SCRATCH/containers/basicsr_nvidia.sif
```

---

## Cluster Structure

**Compute nodes used:**

| Partition | Node | GPU | Used for |
|-----------|------|-----|----------|
| ampere_gpu | nvam1.vaughan | 4× A100 40GB | BCI + MIST training |

**Key paths:**
```
$VSC_DATA/projects/code/KAIR/              ← repository
$VSC_DATA/projects/jobs/                   ← SLURM job scripts (also in hpc/)
$VSC_DATA/projects/logs/                   ← job logs
$VSC_DATA/projects/outputs/                ← training checkpoints
$VSC_SCRATCH/containers/                   ← Apptainer containers
/scratch/antwerpen/grp/ap_invilab_td_thesis/  ← shared group storage
```

---

## Dataset Preparation

All datasets are stored as **SquashFS images** (`.sqsh`) for fast HPC I/O using a neutral folder structure:

```
dataset.sqsh (mounted at /data)
├── train/
│   ├── HE/        ← H&E input images
│   └── IHC/       ← IHC ground truth images
├── val/
│   ├── HE/
│   └── IHC/
└── test/
    ├── HE/
    └── IHC/
```

**Squashfs locations (shared group storage):**
```
/scratch/antwerpen/grp/ap_invilab_td_thesis/BCI.sqsh
/scratch/antwerpen/grp/ap_invilab_td_thesis/MIST_ER_neutral.sqsh
/scratch/antwerpen/grp/ap_invilab_td_thesis/MIST_HER2_neutral.sqsh
/scratch/antwerpen/grp/ap_invilab_td_thesis/MIST_Ki67_neutral.sqsh
/scratch/antwerpen/grp/ap_invilab_td_thesis/MIST_PR_neutral.sqsh
```

**Runtime symlinks:**

KAIR's `plain` dataset loader expects `train_HE/`, `train_IHC/` etc. Job scripts create symlinks at runtime:

```bash
mkdir -p /tmp/bci
ln -s /data/train/HE  /tmp/bci/train_HE
ln -s /data/train/IHC /tmp/bci/train_IHC
ln -s /data/val/HE    /tmp/bci/val_HE
ln -s /data/val/IHC   /tmp/bci/val_IHC
```

The training configs then point to `/tmp/bci/train_HE` etc.

---

## Training

### How Training Works

Unlike NAFNet and Uformer, KAIR/SwinIR training fits within a **single 23-hour SLURM job** — 100k iterations at ~0.79s/iter ≈ ~22h.

The inner container script (`train_kair_HE2IHC.sh` at repo root) sets PYTHONPATH and calls `main_train_psnr.py` with the appropriate JSON config.

### Job Scripts

```
hpc/
├── train_kair_BCI.sh                ← BCI training (ampere_gpu)
├── train_kair_HE2IHC_MIST_ER.sh
├── train_kair_HE2IHC_MIST_HER2.sh
├── train_kair_HE2IHC_MIST_Ki67.sh
├── train_kair_HE2IHC_MIST_PR.sh
├── run_benchmark_BCI_kair.sh        ← BCI inference
├── run_benchmark_MIST_kair.sh       ← MIST inference
└── eval_kair_BCI_benchmark.sh       ← BCI evaluation
```

### Training Configs

| Config | Dataset | Iterations |
|--------|---------|------------|
| `options/swinir/train_swinir_HE2IHC_HPC_512.json` | BCI | 100k |
| `options/swinir/train_swinir_HE2IHC_MIST_ER_HPC.json` | MIST ER | 100k |
| `options/swinir/train_swinir_HE2IHC_MIST_HER2_HPC.json` | MIST HER2 | 100k |
| `options/swinir/train_swinir_HE2IHC_MIST_Ki67_HPC.json` | MIST Ki67 | 100k |
| `options/swinir/train_swinir_HE2IHC_MIST_PR_HPC.json` | MIST PR | 100k |

### Submitting Training

**BCI:**
```bash
sbatch $VSC_DATA/projects/jobs/train_kair_BCI.sh
```

**MIST (all 4 biomarkers):**
```bash
for marker in ER HER2 Ki67 PR; do
    sbatch $VSC_DATA/projects/jobs/train_kair_HE2IHC_MIST_${marker}.sh
done
```

### Output Structure

```
$VSC_DATA/projects/outputs/kair_BCI_vaughan/
├── swinir_HE2IHC/
│   └── models/
│       ├── 15000_G.pth / 15000_E.pth / 15000_optimizerG.pth
│       ├── 30000_G.pth ...
│       ├── ...
│       └── 90000_G.pth     ← used for inference
├── gpu_usage.csv
└── train_log.txt

$VSC_DATA/projects/outputs/kair_MIST_ER_vaughan/
└── swinir_HE2IHC_MIST_ER/
    └── models/
        └── 90000_G.pth     ← used for inference
```

### Monitoring

```bash
# Check running jobs
squeue -u vsc21216 --format="%.18i %.35j %.8T %.10M %R"

# Watch training progress
tail -f $VSC_DATA/projects/logs/kair_BCI_vau_<JOBID>.out

# Check quota
myquota
```

---

## Inference

Benchmark inference uses the unified `benchmark_inference.py` script:

```bash
sbatch $VSC_DATA/projects/jobs/run_benchmark_BCI_kair.sh
```

Results are saved to:
```
/scratch/antwerpen/grp/ap_invilab_td_thesis/benchmark_inference/kair_BCI/
├── comparison/      ← side-by-side PNGs (HE | predicted | GT)
├── predicted/       ← predicted IHC only
├── metrics.csv      ← per-image PSNR and SSIM
└── summary.txt      ← average PSNR and SSIM
```

---

## Evaluation

Evaluation uses the shared `evaluate.py` script from the InViLab benchmark repository, run inside the `evaluate_nvidia.sif` container on the `broadwell` (CPU) partition of Leibniz.

**Metrics computed:** PSNR, SSIM, MS-SSIM, LPIPS (AlexNet + VGG), MAE, FID

Results are appended to:
```
/scratch/antwerpen/grp/ap_invilab_td_thesis/benchmark_results.csv
```

---

## Results

### BCI Dataset

| Model | PSNR ↑ | SSIM ↑ | MS-SSIM ↑ | LPIPS-Alex ↓ | LPIPS-VGG ↓ | MAE ↓ | FID ↓ |
|-------|--------|--------|-----------|--------------|-------------|-------|-------|
| KAIR/SwinIR (128px, 100k iters) | **22.55 dB** | **0.6621** | 0.5554 | 0.6611 | 0.6116 | **0.0689** | **196.94** |

### MIST Dataset

| Model | Marker | PSNR ↑ | SSIM ↑ | LPIPS-Alex ↓ | FID ↓ |
|-------|--------|--------|--------|--------------|-------|
| KAIR | ER | — | — | — | — |
| KAIR | HER2 | — | — | — | — |
| KAIR | Ki67 | — | — | — | — |
| KAIR | PR | — | — | — | — |

*MIST inference in progress. Results will be updated after evaluation completes.*

---

## Modifications

### `main_train_psnr.py`

Commented out intermediate image saving during validation to reduce I/O overhead on HPC:

```python
# FROM
util.imsave(E_img, save_img_path)
# TO
# util.imsave(E_img, save_img_path)
```

### `utils/utils_image.py`

Minor utility modifications to support the virtual staining pipeline.

---

## Notes

- **Single-job training** — KAIR training fits within one 23-hour job. No chaining needed.
- **Checkpoint naming** — KAIR saves `{iter}_G.pth` (model), `{iter}_E.pth` (EMA), and `{iter}_optimizerG.pth` at each `checkpoint_save` interval. Use `90000_G.pth` for inference.
- **`H_size` / `img_size` tuning** — set to 128 for benchmark runs. This reduced iteration time from ~90s to ~0.79s compared to larger patch sizes, making 100k iters feasible in one job.
- **Always use neutral squashfs** (`BCI.sqsh`, `MIST_*_neutral.sqsh`). Old format files have been deleted.
- **KAIR vs SwinIR repo** — always use KAIR for training. The standalone SwinIR repo has no training pipeline.