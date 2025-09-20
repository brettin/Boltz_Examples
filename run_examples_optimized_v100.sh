#!/bin/bash

# Optimized Multi-GPU Boltz-2 Runner for 8x V100 (32GB each)
# Takes advantage of large memory capacity for enhanced predictions

set -e

echo "=== Optimized Boltz-2 Examples for 8x V100 (32GB) ==="
echo "Using memory-intensive settings optimized for V100 capabilities"
echo ""

# Create timestamped output directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_BASE="./v100_optimized_${TIMESTAMP}"
mkdir -p "$OUTPUT_BASE"

# V100-optimized settings
# With 32GB per GPU, we can use aggressive settings for maximum quality

echo "Starting optimized jobs on 8 V100s..."

# GPU 0: Simple protein with enhanced sampling
CUDA_VISIBLE_DEVICES=0 boltz predict test_simple.yaml \
    --use_msa_server \
    --diffusion_samples 20 \
    --recycling_steps 8 \
    --use_potentials \
    --out_dir "$OUTPUT_BASE/gpu0_simple_enhanced" \
    > "$OUTPUT_BASE/gpu0_enhanced.log" 2>&1 &
PID0=$!

# GPU 1: Standard affinity prediction with high quality
CUDA_VISIBLE_DEVICES=1 boltz predict protein_ligand_affinity.yaml \
    --use_msa_server \
    --diffusion_samples 30 \
    --recycling_steps 12 \
    --use_potentials \
    --step_scale 1.2 \
    --out_dir "$OUTPUT_BASE/gpu1_affinity_hq" \
    > "$OUTPUT_BASE/gpu1_hq.log" 2>&1 &
PID1=$!

# GPU 2: Pocket constrained with maximum sampling
CUDA_VISIBLE_DEVICES=2 boltz predict pocket_constrained.yml \
    --use_msa_server \
    --diffusion_samples 25 \
    --recycling_steps 10 \
    --use_potentials \
    --step_scale 1.3 \
    --out_dir "$OUTPUT_BASE/gpu2_pocket_max" \
    > "$OUTPUT_BASE/gpu2_max.log" 2>&1 &
PID2=$!

# GPU 3: Ultra high quality (AlphaFold3+ settings)
CUDA_VISIBLE_DEVICES=3 boltz predict protein_ligand_affinity.yaml \
    --use_msa_server \
    --recycling_steps 15 \
    --diffusion_samples 40 \
    --use_potentials \
    --step_scale 1.1 \
    --out_dir "$OUTPUT_BASE/gpu3_ultra_hq" \
    > "$OUTPUT_BASE/gpu3_ultra.log" 2>&1 &
PID3=$!

# GPU 4: Temperature sampling exploration
CUDA_VISIBLE_DEVICES=4 boltz predict test_simple.yaml \
    --use_msa_server \
    --diffusion_samples 35 \
    --recycling_steps 10 \
    --step_scale 1.8 \
    --use_potentials \
    --out_dir "$OUTPUT_BASE/gpu4_temp_explore" \
    > "$OUTPUT_BASE/gpu4_temp.log" 2>&1 &
PID4=$!

# GPU 5: Affinity with conservative sampling
CUDA_VISIBLE_DEVICES=5 boltz predict protein_ligand_affinity.yaml \
    --use_msa_server \
    --diffusion_samples 50 \
    --recycling_steps 8 \
    --step_scale 0.8 \
    --use_potentials \
    --out_dir "$OUTPUT_BASE/gpu5_conservative" \
    > "$OUTPUT_BASE/gpu5_conservative.log" 2>&1 &
PID5=$!

# GPU 6: Pocket with extensive recycling
CUDA_VISIBLE_DEVICES=6 boltz predict pocket_constrained.yml \
    --use_msa_server \
    --recycling_steps 20 \
    --diffusion_samples 30 \
    --use_potentials \
    --out_dir "$OUTPUT_BASE/gpu6_extensive" \
    > "$OUTPUT_BASE/gpu6_extensive.log" 2>&1 &
PID6=$!

# GPU 7: Maximum everything (stress test)
CUDA_VISIBLE_DEVICES=7 boltz predict protein_ligand_affinity.yaml \
    --use_msa_server \
    --recycling_steps 25 \
    --diffusion_samples 60 \
    --use_potentials \
    --step_scale 1.5 \
    --out_dir "$OUTPUT_BASE/gpu7_maximum" \
    > "$OUTPUT_BASE/gpu7_max.log" 2>&1 &
PID7=$!

echo "All 8 optimized jobs started"
echo "Using aggressive settings to leverage 32GB V100 memory"
echo "Output directory: $OUTPUT_BASE"
echo ""

# Monitor memory usage
echo "Monitoring GPU memory usage..."
nvidia-smi dmon -s m -c 3 > "$OUTPUT_BASE/memory_monitor.log" &
MONITOR_PID=$!

# Function to check job status
check_job() {
    local pid=$1
    local gpu=$2
    local name=$3
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "🔄 GPU $gpu ($name): Running"
        return 0
    else
        wait "$pid"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "✅ GPU $gpu ($name): Complete"
        else
            echo "❌ GPU $gpu ($name): Failed (exit code: $exit_code)"
        fi
        return $exit_code
    fi
}

# Monitor progress every 2 minutes
while true; do
    running=0
    echo ""
    echo "=== Status Check $(date) ==="
    
    check_job $PID0 0 "simple_enhanced" && running=$((running + 1))
    check_job $PID1 1 "affinity_hq" && running=$((running + 1))
    check_job $PID2 2 "pocket_max" && running=$((running + 1))
    check_job $PID3 3 "ultra_hq" && running=$((running + 1))
    check_job $PID4 4 "temp_explore" && running=$((running + 1))
    check_job $PID5 5 "conservative" && running=$((running + 1))
    check_job $PID6 6 "extensive" && running=$((running + 1))
    check_job $PID7 7 "maximum" && running=$((running + 1))
    
    if [ $running -eq 0 ]; then
        break
    fi
    
    echo ""
    echo "💾 Current GPU Memory Usage:"
    nvidia-smi --query-gpu=index,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits | \
        awk -F, '{printf "  GPU %s: %sMB/%sMB (%.1f%%) - Util: %s%%\n", $1, $3, $4, ($3/$4)*100, $5}'
    
    sleep 120  # Check every 2 minutes
done

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true

echo ""
echo "🎉 === ALL OPTIMIZED JOBS COMPLETED! ==="
echo ""

# Final results summary
echo "=== Final Results Summary ==="
echo "Output directory: $OUTPUT_BASE"
echo ""

for i in {0..7}; do
    gpu_dir="$OUTPUT_BASE/gpu${i}_*/predictions"
    log_file="$OUTPUT_BASE/gpu${i}_*.log"
    
    if ls $gpu_dir 2>/dev/null | grep -q .; then
        structure_count=$(ls $gpu_dir/*.{cif,pdb} 2>/dev/null | wc -l)
        echo "✅ GPU $i: $structure_count structures generated"
    else
        echo "❌ GPU $i: No structures found - check log files"
    fi
done

echo ""
echo "📊 === Performance Statistics ==="
echo "Total runtime: $(date) (started at $TIMESTAMP)"
echo "Memory monitoring log: $OUTPUT_BASE/memory_monitor.log"
echo ""
echo "📁 To explore results:"
echo "  ls -la $OUTPUT_BASE/gpu*/predictions/"
echo "  grep -i 'confidence\|affinity' $OUTPUT_BASE/gpu*.log"
echo ""
echo "🔍 To analyze structures:"
echo "  find $OUTPUT_BASE -name '*.cif' -exec ls -lh {} \;"
