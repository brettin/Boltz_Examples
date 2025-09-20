# Boltz Examples

This repository contains practical examples and use cases for **Boltz-2**, a groundbreaking biomolecular foundation model that predicts protein structures and binding affinities. Boltz-2 goes beyond AlphaFold3 by jointly modeling complex structures and binding affinities, making accurate in silico screening practical for early-stage drug discovery.

## 🚀 Quick Start

### Installation

1. Create a conda environment:
```bash
conda create -n boltz python=3.11 -y
conda activate boltz
```

2. Install Boltz with CUDA support:
```bash
pip install "boltz[cuda]" -U
```

For CPU-only installation:
```bash
pip install boltz -U
```

### Basic Usage

```bash
boltz predict input.yaml --use_msa_server
```

## 📁 Examples

### 1. Simple Protein Structure Prediction
- **File**: `test_simple.yaml`
- **Command**: `bash test_simple.sh`
- **Description**: Predicts the structure of a single protein chain

### 2. Protein-Ligand Complex with Affinity Prediction
- **File**: `protein_ligand_affinity.yaml`
- **Command**: `bash protein_ligand_affinity.sh`
- **Description**: Predicts both structure and binding affinity for a protein-ligand complex

### 3. Pocket-Constrained Prediction
- **File**: `pocket_constrained.yml`
- **Command**: `bash pocket_constrained.sh`
- **Description**: Predicts ligand binding with specific pocket constraints

### 4. High-Quality Prediction (AlphaFold3 Parameters)
- **Command**: `bash high_quality_prediction_alphafold3.sh`
- **Description**: Uses AlphaFold3-level parameters for maximum accuracy

## 🧬 Input Formats

Boltz uses YAML format for input specification:

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: QLEDSEVEAVAKGLEEMYANGVTEDNFKNYVKNNFAQQEISSVEEELNVNISDSCVANKIKDEFFAMISISAIVKAAQKKAWKELAVTVLRFAKANGLKTNAIIVAGQLALWAVQCG
  - ligand:
      id: B
      smiles: 'N[C@@H](Cc1ccc(O)cc1)C(=O)O'
properties:
  - affinity:
      binder: B
```

### Supported Molecule Types
- **Proteins**: Amino acid sequences
- **DNA/RNA**: Nucleotide sequences  
- **Ligands**: SMILES strings or CCD codes
- **Modified residues**: Custom modifications
- **Cyclic peptides**: Supported

## 📊 Understanding Output

### Structure Files
- `*.cif` or `*.pdb`: Predicted structures ordered by confidence
- Multiple samples if `--diffusion_samples > 1`

### Confidence Metrics
- **`confidence_score`**: Overall confidence (0-1, higher is better)
- **`ptm`**: Predicted TM score for the complex
- **`plddt`**: Per-residue confidence scores
- **`iptm`**: Interface TM score for multi-chain complexes

### Affinity Predictions
- **`affinity_pred_value`**: Binding affinity as log10(IC50) in μM
  - Lower values = stronger binding
  - Example: -3 = very strong, 0 = moderate, 2 = weak
- **`affinity_probability_binary`**: Probability (0-1) that ligand is a binder
  - Use for hit discovery and binder vs. decoy detection

## ⚙️ Command Options

### Essential Flags
- `--use_msa_server`: Auto-generate MSA using mmseqs2 server
- `--use_potentials`: Apply inference-time potentials for better physical quality
- `--override`: Override existing predictions

### Performance Tuning
- `--recycling_steps 10`: More recycling for higher quality (default: 3)
- `--diffusion_samples 25`: More samples for better results (default: 1)
- `--step_scale 1.5`: Temperature control for diversity (1-2 range)
- `--devices 2`: Use multiple GPUs

### Output Control
- `--output_format mmcif`: Output format (mmcif or pdb)
- `--write_full_pae`: Save full PAE matrix
- `--out_dir ./results`: Specify output directory

## 🔧 Advanced Features

### Constraints
- **Pocket constraints**: Define binding sites
- **Contact constraints**: Specify residue interactions
- **Covalent bonds**: Define chemical bonds

### Templates
- Use structural templates to guide predictions
- Support for both CIF and PDB template files

### MSA Options
- Auto-generation via mmseqs2 server
- Custom MSA support
- Single-sequence mode available

## 📚 Resources

- **Official Repository**: [https://github.com/jwohlwend/boltz](https://github.com/jwohlwend/boltz)
- **Boltz-1 Paper**: [https://doi.org/10.1101/2024.11.19.624167](https://doi.org/10.1101/2024.11.19.624167)
- **Boltz-2 Paper**: [https://doi.org/10.1101/2025.06.14.659707](https://doi.org/10.1101/2025.06.14.659707)
- **Slack Community**: [https://boltz.bio/join-slack](https://boltz.bio/join-slack)

## 🐛 Troubleshooting

### Common Issues
1. **Old NVIDIA GPUs**: Use `--no_kernels` flag if you get cuequivariance errors
2. **MSA Server Issues**: Check authentication with environment variables or API keys
3. **Memory Issues**: Reduce `--diffusion_samples` or use CPU with `--accelerator cpu`
4. **Large Complexes**: May require significant GPU memory

### Getting Help
- Join the [Boltz Slack community](https://boltz.bio/join-slack)
- Check the [GitHub repository](https://github.com/jwohlwend/boltz) for issues
- Review the detailed prediction documentation

## 📄 License

Boltz is released under the MIT License and can be freely used for both academic and commercial purposes.

## 🙏 Citation

If you use Boltz in your research, please cite:

```bibtex
@article{passaro2025boltz2,
  author = {Passaro, Saro and Corso, Gabriele and Wohlwend, Jeremy and Reveiz, Mateo and Thaler, Stephan and Somnath, Vignesh Ram and Getz, Noah and Portnoi, Tally and Roy, Julien and Stark, Hannes and Kwabi-Addo, David and Beaini, Dominique and Jaakkola, Tommi and Barzilay, Regina},
  title = {Boltz-2: Towards Accurate and Efficient Binding Affinity Prediction},
  year = {2025},
  doi = {10.1101/2025.06.14.659707},
  journal = {bioRxiv}
}

@article{wohlwend2024boltz1,
  author = {Wohlwend, Jeremy and Corso, Gabriele and Passaro, Saro and Getz, Noah and Reveiz, Mateo and Leidal, Ken and Swiderski, Wojtek and Atkinson, Liam and Portnoi, Tally and Chinn, Itamar and Silterra, Jacob and Jaakkola, Tommi and Barzilay, Regina},
  title = {Boltz-1: Democratizing Biomolecular Interaction Modeling},
  year = {2024},
  doi = {10.1101/2024.11.19.624167},
  journal = {bioRxiv}
}
```
