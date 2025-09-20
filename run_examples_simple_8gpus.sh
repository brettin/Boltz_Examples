#!/bin/bash

# Simple Multi-GPU Boltz-2 Examples Runner for 8 V100s
# Runs each original example script on a dedicated GPU

set -e

echo "=== Running Boltz-2 Examples on 8 GPUs ==="
echo "Each example will run on a dedicated V100 GPU"
echo ""

# Create timestamped output directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_BASE="./results_8gpu_${TIMESTAMP}"
mkdir -p "$OUTPUT_BASE"

# Run each example on a specific GPU
echo "Starting jobs in parallel..."

# GPU 0: Simple protein prediction
CUDA_VISIBLE_DEVICES=0 boltz predict test_simple.yaml --use_msa_server --out_dir "$OUTPUT_BASE/gpu0_simple" > "$OUTPUT_BASE/gpu0.log" 2>&1 &
PID0=$!

# GPU 1: Protein-ligand affinity
CUDA_VISIBLE_DEVICES=1 boltz predict protein_ligand_affinity.yaml --use_msa_server --out_dir "$OUTPUT_BASE/gpu1_affinity" > "$OUTPUT_BASE/gpu1.log" 2>&1 &
PID1=$!

# GPU 2: Pocket constrained
CUDA_VISIBLE_DEVICES=2 boltz predict pocket_constrained.yml --use_msa_server --out_dir "$OUTPUT_BASE/gpu2_pocket" > "$OUTPUT_BASE/gpu2.log" 2>&1 &
PID2=$!

# GPU 3: High quality (AlphaFold3 settings)
CUDA_VISIBLE_DEVICES=3 boltz predict protein_ligand_affinity.yaml --use_msa_server --recycling_steps 10 --diffusion_samples 25 --out_dir "$OUTPUT_BASE/gpu3_hq" > "$OUTPUT_BASE/gpu3.log" 2>&1 &
PID3=$!

# GPU 4-7: Additional runs with variations for thorough testing
CUDA_VISIBLE_DEVICES=4 boltz predict test_simple.yaml --use_msa_server --diffusion_samples 5 --out_dir "$OUTPUT_BASE/gpu4_simple_multi" > "$OUTPUT_BASE/gpu4.log" 2>&1 &
PID4=$!

CUDA_VISIBLE_DEVICES=5 boltz predict protein_ligand_affinity.yaml --use_msa_server --diffusion_samples 10 --out_dir "$OUTPUT_BASE/gpu5_affinity_multi" > "$OUTPUT_BASE/gpu5.log" 2>&1 &
PID5=$!

CUDA_VISIBLE_DEVICES=6 boltz predict pocket_constrained.yml --use_msa_server --recycling_steps 5 --out_dir "$OUTPUT_BASE/gpu6_pocket_extra" > "$OUTPUT_BASE/gpu6.log" 2>&1 &
PID6=$!

CUDA_VISIBLE_DEVICES=7 boltz predict protein_ligand_affinity.yaml --use_msa_server --recycling_steps 8 --diffusion_samples 15 --out_dir "$OUTPUT_BASE/gpu7_comprehensive" > "$OUTPUT_BASE/gpu7.log" 2>&1 &
PID7=$!

echo "All 8 jobs started on separate GPUs"
echo "Output directory: $OUTPUT_BASE"
echo ""

# Wait for all jobs to complete
echo "Waiting for jobs to complete..."
wait $PID0 && echo "✅ GPU 0 (simple): Complete" || echo "❌ GPU 0 (simple): Failed"
wait $PID1 && echo "✅ GPU 1 (affinity): Complete" || echo "❌ GPU 1 (affinity): Failed"
wait $PID2 && echo "✅ GPU 2 (pocket): Complete" || echo "❌ GPU 2 (pocket): Failed"
wait $PID3 && echo "✅ GPU 3 (high-quality): Complete" || echo "❌ GPU 3 (high-quality): Failed"
wait $PID4 && echo "✅ GPU 4 (simple-multi): Complete" || echo "❌ GPU 4 (simple-multi): Failed"
wait $PID5 && echo "✅ GPU 5 (affinity-multi): Complete" || echo "❌ GPU 5 (affinity-multi): Failed"
wait $PID6 && echo "✅ GPU 6 (pocket-extra): Complete" || echo "❌ GPU 6 (pocket-extra): Failed"
wait $PID7 && echo "✅ GPU 7 (comprehensive): Complete" || echo "❌ GPU 7 (comprehensive): Failed"

echo ""
echo "=== All jobs completed! ==="
echo "Results in: $OUTPUT_BASE"
echo ""
echo "To view results:"
echo "  ls $OUTPUT_BASE/gpu*/predictions/"
echo "  cat $OUTPUT_BASE/gpu*.log"
