--- 
# KAIR/SwinIR: BCI Virtual Staining
Local setup and initial training for H&E → IHC translation · BCI & MIST Datasets · Thomas's PC

> **Note:** This documents the local development setup used on Thomas's PC before HPC training.
> For HPC training, inference, and evaluation on the CalcUA cluster, see [HPC-INSTRUCTION.md](HPC-INSTRUCTION.md).
> See the [official KAIR repository](https://github.com/cszn/KAIR) for the original codebase.

---

## 1. Project Goal

This adapts SwinIR (Swin Transformer for Image Restoration) via the KAIR training framework to perform **virtual histological staining**:

- **Input:** H&E stained histology tiles
- **Output:** IHC stained equivalents

Trained and evaluated on the **BCI** and **MIST** datasets as part of the InViLab Virtual Staining Benchmark.

> **Why KAIR instead of the SwinIR repo?** The standalone SwinIR repository only supports inference with pretrained models. KAIR is the official training framework for SwinIR — it contains `main_train_psnr.py`, all training configs, and dataset loaders. All SwinIR training must be done inside KAIR.

---

## 2. Environment Setup

A unified conda environment is used across all models in the benchmark:

```bash
conda activate vs_ua
```

| Component | Version |
|-----------|---------|
| Python | 3.9 |
| PyTorch | 2.1.2+cu121 |
| GPU | NVIDIA RTX 4080 (16GB VRAM) |
| OS | Ubuntu 22.04 |

---

## 3. Tasks Implemented

Three SwinIR tasks were explored during local development:

### Task 1 — Image-to-Image Translation (HE2IHC) ← Benchmark Task
The primary benchmark task. SwinIR is used as a paired H&E → IHC translator.

- `dataset_type: plain`
- `dataroot_L`: H&E input
- `dataroot_H`: IHC target
- `upscale: 1` (same resolution in/out)
- Config: `options/swinir/train_swinir_HE2IHC.json`

### Task 2 — HE Denoising (Exploration)
Explored as a preprocessing step before virtual staining.

- `dataset_type: dncnn`
- Config: `options/swinir/train_swinir_HE_denoise.json`

### Task 3 — IHC Denoising (Exploration)
Explored for cleaning IHC images for evaluation and visualization.

- `dataset_type: dncnn`
- Config: `options/swinir/train_swinir_IHC_denoise.json`

> Tasks 2 and 3 were early explorations and are not part of the final benchmark. Only the HE2IHC task was trained at full scale on HPC.

---

## 4. Dataset Preparation

BCI is a **paired** dataset — every H&E image has a matching IHC image with the same filename.

```
data/BCI/
├── HE/
│   ├── train/      ← H&E input (dataroot_L)
│   └── test/
└── IHC/
    ├── train/      ← IHC ground truth (dataroot_H)
    └── test/
```

```
data/MIST/
├── HER2/
│   ├── trainA/     ← H&E input
│   ├── trainB/     ← IHC ground truth
│   ├── valA/
│   └── valB/
├── ER/    (same structure)
├── Ki67/  (same structure)
└── PR/    (same structure)
```

> For HPC training, datasets are stored as SquashFS images with a neutral `HE/` / `IHC/` structure. See [HPC-INSTRUCTION.md](HPC-INSTRUCTION.md).

---

## 5. Configuration Files

Local configs live in `options/swinir/` without the `_HPC` suffix. HPC configs have `_HPC` in the name.

| Config | Task | Use |
|--------|------|-----|
| `train_swinir_HE2IHC.json` | H&E → IHC translation | Local smoke test |
| `train_swinir_HE_denoise.json` | HE denoising | Local exploration |
| `train_swinir_IHC_denoise.json` | IHC denoising | Local exploration |
| `train_swinir_HE2IHC_HPC_512.json` | H&E → IHC translation | HPC BCI benchmark |
| `train_swinir_HE2IHC_MIST_*_HPC.json` | H&E → IHC (MIST) | HPC MIST benchmark |

### Key architecture parameters (HE2IHC benchmark config)

| Parameter | Value |
|-----------|-------|
| `H_size` / `img_size` | 128 |
| `embed_dim` | 128 |
| `upscale` | 1 |
| `task` | `swinir_HE2IHC` |
| `dataset_type` | `plain` |

---

## 6. Training

```bash
conda activate vs_ua
cd ~/virtual_stain/repos/KAIR

# HE2IHC (benchmark task)
python main_train_psnr.py --opt options/swinir/train_swinir_HE2IHC.json

# HE denoising (exploration)
python main_train_psnr.py --opt options/swinir/train_swinir_HE_denoise.json

# IHC denoising (exploration)
python main_train_psnr.py --opt options/swinir/train_swinir_IHC_denoise.json
```

Full benchmark training (100k iterations) runs on HPC — see [HPC-INSTRUCTION.md](HPC-INSTRUCTION.md).

---

## 7. Modifications

### `main_train_psnr.py`

Commented out intermediate image saving during validation to reduce I/O overhead:

```python
# FROM
util.imsave(E_img, save_img_path)
# TO
# util.imsave(E_img, save_img_path)
```

### `utils/utils_image.py`

Minor utility modifications to support the virtual staining pipeline.

---

## 8. Results

### Smoke Test (Local)

Results from early local runs using the pretrained SwinIR model as baseline and initial fine-tuning experiments. Full benchmark results from HPC training are in [HPC-INSTRUCTION.md](HPC-INSTRUCTION.md).

---

## 9. Notes

- **Always use KAIR for training** — the standalone SwinIR repo has no training pipeline.
- **Task is controlled by `dataset_type`** in the JSON config — switching between denoising (`dncnn`), image-to-image (`plain`), and super-resolution (`sr`) only requires changing the config.
- The `H_size` / `img_size` parameter was tuned to 128 for HPC training — lower values significantly reduce iteration time without major quality loss at this scale.