#!/bin/bash

# Boltz-2 Environment Setup Script
# ================================
# This script configures the required environment for running Boltz-2 protein structure prediction.
# 
# Purpose:
#   - Sets up the conda environment with all required dependencies
#   - Ensures proper Python package isolation
#   - Configures PATH for conda/anaconda binaries
#
# Usage:
#   source env.sh
#   # OR
#   . env.sh
#
# Note: This script must be SOURCED (not executed) to modify the current shell environment
#
# Dependencies:
#   - Anaconda3 installed at /software/anaconda3/
#   - Conda environment 'boltz' with Boltz-2 dependencies installed
#
# After sourcing this script, you can run Boltz-2 commands like:
#   boltz predict <config.yaml>

# Add Anaconda/Conda binaries to PATH
export PATH=${PATH}:/software/anaconda3/condabin:/software/anaconda3/bin

# Activate the Boltz-2 conda environment
source /software/anaconda3/bin/activate /homes/brettin/.conda/envs/boltz

echo "✅ Boltz-2 environment activated successfully"
echo "🐍 Python: $(which python)"
echo "📦 Conda environment: $CONDA_DEFAULT_ENV"
echo "🔬 Ready to run Boltz-2 predictions!"

