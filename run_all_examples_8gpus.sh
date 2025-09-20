#!/bin/bash

# Multi-GPU Boltz-2 Examples Runner for 8 V100s (32GB each)
# This script runs each example on a dedicated GPU for maximum parallel efficiency

set -e  # Exit on any error

# Check if we have 8 GPUs available
GPU_COUNT=$(nvidia-smi -L | wc -l)
if [ "$GPU_COUNT" -lt 8 ]; then
    echo "Warning: Only $GPU_COUNT GPUs detected, but script expects 8"
    echo "Continuing with available GPUs..."
fi

# Create output directories with timestamps
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_OUTPUT_DIR="./multi_gpu_results_${TIMESTAMP}"
mkdir -p "$BASE_OUTPUT_DIR"

echo "=== Starting Multi-GPU Boltz-2 Examples ==="
echo "Timestamp: $TIMESTAMP"
echo "Output directory: $BASE_OUTPUT_DIR"
echo "Available GPUs: $GPU_COUNT"
echo "V100 Memory per GPU: 32GB"
echo ""

# Function to run command on specific GPU
run_on_gpu() {
    local gpu_id=$1
    local command=$2
    local output_dir=$3
    local log_file=$4
    
    echo "GPU $gpu_id: Starting - $command"
    CUDA_VISIBLE_DEVICES=$gpu_id $command --out_dir "$output_dir" > "$log_file" 2>&1 &
}

# Define examples with optimized settings for V100 32GB
declare -a EXAMPLES=(
    "0:boltz predict test_simple.yaml --use_msa_server:simple_protein:GPU0_simple.log"
    "1:boltz predict protein_ligand_affinity.yaml --use_msa_server:protein_ligand:GPU1_affinity.log"
    "2:boltz predict pocket_constrained.yml --use_msa_server:pocket_constrained:GPU2_pocket.log"
    "3:boltz predict protein_ligand_affinity.yaml --use_msa_server --recycling_steps 10 --diffusion_samples 25:high_quality_af3:GPU3_high_quality.log"
    "4:boltz predict test_simple.yaml --use_msa_server --diffusion_samples 10 --recycling_steps 5:simple_enhanced:GPU4_enhanced.log"
    "5:boltz predict protein_ligand_affinity.yaml --use_msa_server --diffusion_samples 15 --step_scale 1.8:affinity_enhanced:GPU5_affinity_enhanced.log"
    "6:boltz predict pocket_constrained.yml --use_msa_server --diffusion_samples 20 --use_potentials:pocket_enhanced:GPU6_pocket_enhanced.log"
    "7:boltz predict protein_ligand_affinity.yaml --use_msa_server --recycling_steps 15 --diffusion_samples 30 --use_potentials:ultra_high_quality:GPU7_ultra.log"
)

# Start all jobs in parallel
pids=()
for example in "${EXAMPLES[@]}"; do
    IFS=':' read -r gpu_id command output_name log_file <<< "$example"
    
    output_dir="$BASE_OUTPUT_DIR/$output_name"
    mkdir -p "$output_dir"
    log_path="$BASE_OUTPUT_DIR/$log_file"
    
    run_on_gpu "$gpu_id" "$command" "$output_dir" "$log_path"
    pids+=($!)
done

echo ""
echo "=== All jobs started in parallel ==="
echo "Monitoring progress..."
echo ""

# Monitor progress
while true; do
    running=0
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            running=$((running + 1))
        fi
    done
    
    if [ $running -eq 0 ]; then
        break
    fi
    
    echo "$(date): $running jobs still running..."
    sleep 30
done

echo ""
echo "=== All jobs completed! ==="
echo ""

# Check results and generate summary
echo "=== Results Summary ==="
for example in "${EXAMPLES[@]}"; do
    IFS=':' read -r gpu_id command output_name log_file <<< "$example"
    
    output_dir="$BASE_OUTPUT_DIR/$output_name"
    log_path="$BASE_OUTPUT_DIR/$log_file"
    
    if [ -f "$log_path" ]; then
        # Check if job completed successfully
        if grep -q "error\|Error\|ERROR\|failed\|Failed\|FAILED" "$log_path"; then
            echo "❌ GPU $gpu_id ($output_name): FAILED - check $log_file"
        elif [ -d "$output_dir/predictions" ] && [ "$(ls -A $output_dir/predictions)" ]; then
            echo "✅ GPU $gpu_id ($output_name): SUCCESS - outputs in $output_name/"
        else
            echo "⚠️  GPU $gpu_id ($output_name): UNCERTAIN - check $log_file"
        fi
    else
        echo "❌ GPU $gpu_id ($output_name): NO LOG FOUND"
    fi
done

echo ""
echo "=== GPU Memory Usage Summary ==="
nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits | \
    awk -F, '{printf "GPU %s: %sMB/%sMB used (%.1f%%), Util: %s%%\n", $1, $3, $4, ($3/$4)*100, $5}'

echo ""
echo "=== Timing Summary ==="
echo "Start time: $TIMESTAMP"
echo "End time: $(date +%Y%m%d_%H%M%S)"

echo ""
echo "All results saved in: $BASE_OUTPUT_DIR"
echo "Individual logs: $BASE_OUTPUT_DIR/GPU*.log"
echo ""
echo "To analyze results:"
echo "  ls -la $BASE_OUTPUT_DIR/*/predictions/"
echo "  tail -n 20 $BASE_OUTPUT_DIR/GPU*.log"

# Optional: Create a quick structure analysis
echo ""
echo "=== Quick Structure Count ==="
find "$BASE_OUTPUT_DIR" -name "*.cif" -o -name "*.pdb" | wc -l | xargs echo "Total structure files generated:"
