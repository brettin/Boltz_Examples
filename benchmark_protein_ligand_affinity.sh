#!/bin/bash

# Protein-Ligand Affinity Benchmark Script
# ========================================
# This script benchmarks Boltz-2 protein-ligand affinity predictions across multiple GPUs
# using identical input sequences to measure performance consistency and timing.
#
# Features:
# - Runs same prediction task on each available GPU
# - Measures execution time per GPU
# - Monitors GPU memory usage during execution
# - Compares prediction consistency across GPUs
# - Generates performance summary report
#
# Usage: ./benchmark_protein_ligand_affinity.sh [gpu_list]
# Examples: 
#   ./benchmark_protein_ligand_affinity.sh "0,1,2,3"    # Use GPUs 0,1,2,3
#   ./benchmark_protein_ligand_affinity.sh "1,3,5,7"    # Use GPUs 1,3,5,7
#   ./benchmark_protein_ligand_affinity.sh              # Default: use GPUs 0-7

set -e

# Configuration
# Default to GPUs 0-7 if not specified
GPU_LIST=${1:-"0,1,2,3,4,5,6,7"}
NUM_GPUS=$(echo "$GPU_LIST" | tr ',' '\n' | wc -l)  # Count number of GPUs specified
INPUT_CONFIG="protein_ligand_affinity.yaml"
BENCHMARK_NAME="protein_ligand_affinity"

# Create timestamped benchmark directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BENCHMARK_DIR="./benchmark_results_${BENCHMARK_NAME}_${TIMESTAMP}"
mkdir -p "$BENCHMARK_DIR"

echo "=== Boltz-2 Protein-Ligand Affinity Benchmark ==="
echo "Timestamp: $TIMESTAMP"
echo "Target: $INPUT_CONFIG"
echo "GPUs to test: $GPU_LIST ($NUM_GPUS total)"
echo "Results directory: $BENCHMARK_DIR"
echo ""

# Check GPU availability
AVAILABLE_GPUS=$(nvidia-smi -L | wc -l)
if [ "$AVAILABLE_GPUS" -lt "$NUM_GPUS" ]; then
    echo "️Warning: Only $AVAILABLE_GPUS GPUs available, but $NUM_GPUS requested"
    echo "Adjusting to use $AVAILABLE_GPUS GPUs"
    NUM_GPUS=$AVAILABLE_GPUS
fi

# Verify input file exists
if [ ! -f "$INPUT_CONFIG" ]; then
    echo "Error: Input file '$INPUT_CONFIG' not found"
    exit 1
fi

echo "Setup complete. Starting benchmark..."
echo ""

# Function to run benchmark on specific GPU
run_gpu_benchmark() {
    local gpu_id=$1
    local output_dir="$BENCHMARK_DIR/gpu${gpu_id}"
    local log_file="$BENCHMARK_DIR/gpu${gpu_id}_benchmark.log"
    local time_file="$BENCHMARK_DIR/gpu${gpu_id}_timing.txt"
    
    mkdir -p "$output_dir"
    
    echo "GPU $gpu_id: Starting benchmark..."
    
    # Record start time
    local start_time=$(date +%s.%N)
    echo "Start time: $(date)" > "$time_file"
    
    # Run prediction with timing
    CUDA_VISIBLE_DEVICES=$gpu_id time -p boltz predict "$INPUT_CONFIG" \
        --use_msa_server \
        --out_dir "$output_dir" \
        > "$log_file" 2>&1
    
    local exit_code=$?
    
    # Record end time
    local end_time=$(date +%s.%N)
    echo "End time: $(date)" >> "$time_file"
    
    # Calculate duration
    local duration=$(echo "$end_time - $start_time" | bc -l)
    echo "Duration (seconds): $duration" >> "$time_file"
    
    if [ $exit_code -eq 0 ]; then
        echo "GPU $gpu_id: Completed successfully (${duration}s)"
    else
        echo "GPU $gpu_id: Failed with exit code $exit_code"
    fi
    
    return $exit_code
}

# Start GPU memory monitoring in background
echo "Starting GPU memory monitoring..."
nvidia-smi dmon -s m -f "$BENCHMARK_DIR/gpu_memory_monitor.csv" &
MONITOR_PID=$!

# Start all GPU benchmarks in parallel
echo "Starting parallel benchmarks on $NUM_GPUS GPUs..."
pids=()
start_times=()

# Convert GPU_LIST to array
IFS=',' read -ra GPU_ARRAY <<< "$GPU_LIST"

for i in "${!GPU_ARRAY[@]}"; do
    gpu=${GPU_ARRAY[$i]}
    run_gpu_benchmark $gpu &
    pids[$i]=$!
    start_times[$i]=$(date +%s.%N)
done

echo ""
echo "All benchmarks started. Monitoring progress..."
echo ""

# Monitor progress
while true; do
    running=0
    completed=0
    
    for i in "${!GPU_ARRAY[@]}"; do
        if kill -0 "${pids[$i]}" 2>/dev/null; then
            running=$((running + 1))
        else
            completed=$((completed + 1))
        fi
    done
    
    if [ $running -eq 0 ]; then
        break
    fi
    
    echo "$(date '+%H:%M:%S'): Running: $running, Completed: $completed"
    
    # Show current GPU profile (only for user-specified GPUs)
    echo "Current GPU Profile:"
    if nvidia-smi --query-gpu=index,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits 2>/dev/null > /tmp/gpu_status_all.csv; then
        # Only show stats for the GPUs in our user-specified list
        for monitor_gpu in "${GPU_ARRAY[@]}"; do
            # Find the line for this specific GPU
            if gpu_line=$(grep "^${monitor_gpu}," /tmp/gpu_status_all.csv); then
                # Parse the line for this GPU
                IFS=',' read -r gpu_index mem_used mem_total util_gpu <<< "$gpu_line"
                # Remove any whitespace
                gpu_index=$(echo "$gpu_index" | tr -d ' ')
                mem_used=$(echo "$mem_used" | tr -d ' ')
                mem_total=$(echo "$mem_total" | tr -d ' ')
                util_gpu=$(echo "$util_gpu" | tr -d ' ')
                perc_mem=$(echo "scale=4; ($mem_used / $mem_total) * 100" | bc -l)
                
                echo "  GPU $gpu_index: ${mem_used}MB/${mem_total}MB - GPU Util: ${util_gpu}% - Memory Util: ${perc_mem}%"
            else
                echo "  GPU $monitor_gpu: Unable to read status"
            fi
        done
        # rm -f /tmp/gpu_status_all.csv
    else
        echo "  Unable to query GPU memory status"
    fi
    echo ""
    
    sleep 60  # Check every minute
done

# Stop memory monitoring
kill $MONITOR_PID 2>/dev/null || true

echo ""
echo "🎉 === ALL BENCHMARKS COMPLETED! ==="
echo ""

# Collect results and generate summary
echo "📊 === BENCHMARK RESULTS SUMMARY ==="
echo "Benchmark: $BENCHMARK_NAME"
echo "Input: $INPUT_CONFIG"
echo "Timestamp: $TIMESTAMP"
echo "GPUs tested: $NUM_GPUS"
echo ""

# Results table header
printf "%-6s %-10s %-15s %-15s %-20s\n" "GPU" "Status" "Time (s)" "Structures" "Affinity Score"
printf "%-6s %-10s %-15s %-15s %-20s\n" "---" "------" "--------" "----------" "-------------"

total_time=0
successful_runs=0
failed_runs=0

for i in "${!GPU_ARRAY[@]}"; do
    gpu=${GPU_ARRAY[$i]}
    # Clean the gpu variable to ensure no contamination
    gpu=$(echo "$gpu" | tr -d ' \t\n\r')
    gpu_dir="$BENCHMARK_DIR/gpu${gpu}"
    time_file="$BENCHMARK_DIR/gpu${gpu}_timing.txt"
    log_file="$BENCHMARK_DIR/gpu${gpu}_benchmark.log"
    
    # Wait for process and get exit code
    wait "${pids[$i]}"
    exit_code=$?
    
    if [ $exit_code -eq 0 ] && [ -f "$time_file" ]; then
        # Extract timing
        duration=$(grep "Duration" "$time_file" | cut -d: -f2 | tr -d ' ')
        total_time=$(echo "$total_time + $duration" | bc -l)
        
        # Count structures
        structure_count=$(find "$gpu_dir" -name "*.cif" -o -name "*.pdb" 2>/dev/null | wc -l)
        
        # Extract affinity score if available
        affinity_score="N/A"
        if [ -f "$log_file" ]; then
            affinity_score=$(grep -i "affinity\|binding" "$log_file" | head -1 | cut -c1-15 || echo "N/A")
        fi
        
        # Debug: show what's actually in the gpu variable
        echo "DEBUG: gpu='$gpu', exit_code='$exit_code'" >&2
        printf "%-6s %-10s %-15.2f %-15s %-20s\n" "$gpu" "SUCCESS" "$duration" "$structure_count" "$affinity_score"
        successful_runs=$((successful_runs + 1))
    else
        # Debug: show what's actually in the gpu variable
        echo "DEBUG: gpu='$gpu', exit_code='$exit_code' (FAILED)" >&2
        printf "%-6s %-10s %-15s %-15s %-20s\n" "$gpu" "FAILED" "N/A" "0" "N/A"
        failed_runs=$((failed_runs + 1))
    fi
done

echo ""
echo "📈 === PERFORMANCE STATISTICS ==="
echo "Total successful runs: $successful_runs/$NUM_GPUS"
echo "Failed runs: $failed_runs"

if [ $successful_runs -gt 0 ]; then
    avg_time=$(echo "scale=4; $total_time / $successful_runs" | bc -l)
    echo "Average execution time: ${avg_time}s"
    echo "Total execution time: ${total_time}s"
    echo "Parallel efficiency: $(echo "scale=2; $avg_time * $NUM_GPUS / $total_time * 100" | bc -l)%"
fi

echo ""
echo "📁 === FILES AND LOGS ==="
echo "Results directory: $BENCHMARK_DIR"
echo "Individual logs: $BENCHMARK_DIR/gpu*_benchmark.log"
echo "Timing data: $BENCHMARK_DIR/gpu*/timing.txt"
echo "Memory monitoring: $BENCHMARK_DIR/gpu_memory_monitor.csv"
echo "Prediction outputs: $BENCHMARK_DIR/gpu*/predictions/"
echo ""

echo "🔍 === ANALYSIS COMMANDS ==="
echo "View all logs: tail -n 10 $BENCHMARK_DIR/gpu*_benchmark.log"
echo "Compare timings: grep Duration $BENCHMARK_DIR/gpu*/timing.txt"
echo "Check structures: find $BENCHMARK_DIR -name '*.cif' -exec ls -lh {} \;"
echo "Memory analysis: head -20 $BENCHMARK_DIR/gpu_memory_monitor.csv"

echo ""
echo "✨ Benchmark completed successfully!"
