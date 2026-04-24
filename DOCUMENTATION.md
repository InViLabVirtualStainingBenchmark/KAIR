                                                                                                                                                                                                                                                                                                                                                       
# SWINIR: Denoising, Image-to-Image, Super-Resolution & Automation Pipeline
 
**Hybrid Technical + Researcher-Friendly Documentation** 
**Author:** Aisosa and Lesley
**GPU:** RTX 4080 (16GB) 
**OS:** Ubuntu 22.04 
**Environment:** `vs_ua` (Conda)
 
---
 
## 1. Hardware & Environment
 
### Hardware
- Ubuntu 22.04
- NVIDIA RTX 4080 (16GB VRAM)
- Python 3.9
- Conda environment: `vs_ua`
### Repository Structure
 
```
~/virtual_stain/
   data/
   repos/
       KAIR/
       SwinIR/
       Uformer/
       Restormer/
   scripts/
   outputs/
   run_all_night.sh
```
 
### Why We Use KAIR Instead of the SwinIR Repo
 
**KAIR = the official training framework for SwinIR.** 
The standalone SwinIR repo only supports inference, not training.
 
✔ **KAIR contains:**
- `main_train_psnr.py` → the ONLY correct SwinIR training script
- `options/swinir/*.json` → training configs
- Dataset loaders for `dncnn`, `sr`, `plain`, etc.
- Model definitions for SwinIR
✔ **The SwinIR repo contains:**
- Pretrained models
- Inference scripts
- No training pipeline
> ➡**All SwinIR training MUST be done inside KAIR.**
 
---
 
## 2. Dataset Structure (BCI)
 
```
/home/virtual_stain/data/BCI/
   HE/
       train/
       test/
   IHC/
       train/
       test/
```
 
### Paired or Unpaired?
 
✔ **BCI is a paired dataset.** 
Every HE image has a matching IHC image with the same filename.
 
This is required for:
- HE-denoiser
- IHC-denoiser
- SR ×4
- Uformer HE→IHC
- Image-to-Image SwinIR (HE2IHC)
---
 
## 3. SwinIR Tasks Implemented
 
### 1. Denoising (HE & IHC)
- Removes noise, keeps structure
- Paired dataset
- Uses `dataset_type: dncnn`
### 2. Image-to-Image (HE → IHC)
- The HE2IHC model
- Uses SwinIR as a paired translator
- Uses `dataset_type: plain`
- Requires `dataroot_L` (input) and `dataroot_H` (target)
### 3. Super-Resolution ×4 (HE)
- Upscales HE images by 4×
- Sharpens nuclei, improves Uformer virtual staining
- Uses `dataset_type: sr`
- Uses `"upscale": 4`
---
 
## 4. What SR ×4 Means
 
**SR ×4 = Super-Resolution by a factor of 4.**
 
| Input | Output |
|-------|--------|
| 256×256 | 1024×1024 |
 
✔ More detail 
✔ Sharper nuclei 
✔ Better IHC translation 
✔ Heavier compute — but the RTX 4080 handles it easily
 
---
 
## 5. Exact Dataset Directories Used in JSONs
 
### HE Denoiser
```
/home/virtual_stain/data/BCI/HE/train
/home/virtual_stain/data/BCI/HE/test
```
 
### IHC Denoiser
```
/home/virtual_stain/data/BCI/IHC/train
/home/virtual_stain/data/BCI/IHC/test
```
 
### HE2IHC (Image-to-Image)
```
dataroot_L = HE/train
dataroot_H = IHC/train
```
 
### SR ×4
```
dataroot_H = HE/train
```
 
---
 
## 6. JSON Configurations
 
### 6.1 `train_swinir_HE_denoise.json`
 
**Purpose:** Denoise HE images (paired, dncnn loader) 
**Why we created it:** To clean HE before SR and Uformer. 
**Location:**
```
~/virtual_stain/repos/KAIR/options/swinir/train_swinir_HE_denoise.json
```
 
**Key edits made:**
- Set dataset paths to BCI HE
- Set `train_iter = 58440` (15 epochs)
- Set `checkpoint_save = 3896`
- Set `dataset_type = dncnn`
---
 
### 6.2 `train_swinir_IHC_denoise.json`
 
**Purpose:** Denoise IHC images (paired, dncnn loader) 
**Why we created it:** To clean IHC for evaluation and visualization. 
**Location:**
```
~/virtual_stain/repos/KAIR/options/swinir/train_swinir_IHC_denoise.json
```
 
**Key edits:**
- Changed dataset paths to BCI IHC
- Same training schedule as HE
---
 
### 6.3 `train_swinir_HE2IHC.json`
 
**Purpose:** Image-to-Image translation (HE → IHC) 
**Why we created it:** To test SwinIR as a paired translator. 
**Location:**
```
~/virtual_stain/repos/KAIR/options/swinir/train_swinir_HE2IHC.json
```
 
**Key edits:**
- Set `dataset_type = plain`
- Set `dataroot_L = HE/train`
- Set `dataroot_H = IHC/train`
- Set `upscale = 1`
---
 
### 6.4 `train_swinir_SR_x4.json`
 
**Purpose:** Super-Resolution ×4 on HE images 
**Why we created it:** To improve Uformer virtual staining quality. 
**Location:**
```
~/virtual_stain/repos/KAIR/options/swinir/train_swinir_SR_x4.json
```
 
**Key edits:**
- Set `"upscale": 4`
- Set `"dataset_type": "sr"`
- Set `"dataroot_H": HE/train`
- Set `"train_iter": 58440`
---
 
## 7. Training Commands (Exact)
 
All training is run from:
```bash
cd ~/virtual_stain/repos/KAIR
```
 
### HE Denoiser
```bash
python main_train_psnr.py --opt options/swinir/train_swinir_HE_denoise.json
```
 
### IHC Denoiser
```bash
python main_train_psnr.py --opt options/swinir/train_swinir_IHC_denoise.json
```
 
### HE2IHC
```bash
python main_train_psnr.py --opt options/swinir/train_swinir_HE2IHC.json
```
 
### SR ×4
```bash
python main_train_psnr.py --opt options/swinir/train_swinir_SR_x4.json
```
 
---
 
## 8. Overnight Automation Script
 
The loop trains:
1. IHC-denoiser
2. HE-denoiser
3. SR ×4
4. Repeat forever
**Script location:**
```
~/virtual_stain/run_all_night.sh
```
 
**Run:**
```bash
chmod +x run_all_night.sh
./run_all_night.sh
```

---
 
## 9. Viewer Scripts
 
### HE vs Denoised
```
view_he_denoised.py
```
Output folder: `comparison_he_denoised_labeled/`
 
### HE | Prediction | IHC
```
compare_he_ihc.py
```
Output folder: `comparison_results/`
 
---
 
## 10. How to Switch Tasks
 
In KAIR, the task is controlled by `dataset_type`, `netG` settings, and the task name.
 
| Task | `dataset_type` | Example JSON |
|------|---------------|--------------|
| Denoise | `dncnn` | `train_swinir_HE_denoise.json` |
| Deblur | `plain` | `train_swinir_car_jpeg.json` |
| SR ×4 | `sr` | `train_swinir_SR_x4.json` |
| Image-to-Image | `plain` | `train_swinir_HE2IHC.json` |
 
To switch tasks, only change:
- `dataset_type`
- `dataroot` paths
- `upscale` (if SR)
Everything else stays the same.
 
---
 
## 11. Full Pipeline Summary
 
```
┌──────────────┐
│   Raw HE      │
└──────┬───────┘
      │
      ▼
┌──────────────────┐
│ HE Denoiser       │
└──────┬───────────┘
      │
      ▼
┌──────────────────┐
│ SR ×4 (HE)        │
└──────┬───────────┘
      │
      ▼
┌──────────────────┐
│ Uformer HE→IHC    │
└──────┬───────────┘
      │
      ▼
┌──────────────────┐
│ Final IHC Output  │
└───────────────────┘
```
 
---
 
## 12. Final Check
 
This documentation includes:
 
- ✔ Denoising
- ✔ Image-to-Image
- ✔ SR ×4
- ✔ Paired/unpaired explanation
- ✔ Why KAIR is required
- ✔ Exact dataset directories
- ✔ What each JSON is for
- ✔ What was edited and why
- ✔ How to switch tasks
- ✔ Viewer scripts
- ✔ Automation script
- ✔ Actual folder structure

