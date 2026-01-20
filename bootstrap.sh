#!/bin/bash
# WebShop Bootstrap Script
# Usage: source bootstrap.sh
#
# Run this ONCE on a machine with internet access (master).
# After completion, use start_server.sh on worker machines.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== WebShop Bootstrap ==="
echo "This script downloads ~3GB of data and builds search indexes."
echo ""

# ============================================================
# Use Java 11 from NAS (required for pyserini)
# ============================================================
JAVA11_PATH="$(dirname "$SCRIPT_DIR")/java11"
if [ -d "$JAVA11_PATH" ]; then
    export JAVA_HOME="$JAVA11_PATH"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "Using Java 11 from: $JAVA_HOME"
    echo "Java version: $(java -version 2>&1 | head -1)"
else
    echo "WARNING: Java 11 not found at $JAVA11_PATH"
    echo "pyserini requires Java 11. Please install it first."
fi

# Disable vector module that requires Java 16+ (pyserini/pyjnius compatibility)
export JDK_JAVA_OPTIONS=""
export _JAVA_OPTIONS=""
export JAVA_TOOL_OPTIONS=""

# ============================================================
# Install Python to project directory (for offline workers)
# ============================================================
export UV_PYTHON_INSTALL_DIR="$SCRIPT_DIR/.uv/python"

# Ensure uv is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Install uv if not available
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "uv location: $(which uv)"
echo "uv version: $(uv --version)"

# Check if .venv exists and Python works
if [ -d ".venv" ] && [ -x ".venv/bin/python" ]; then
    if .venv/bin/python --version &> /dev/null; then
        echo "Found valid .venv, activating..."
        source .venv/bin/activate
    else
        echo "WARNING: .venv exists but Python is broken, recreating..."
        rm -rf .venv
    fi
fi

# Create venv if not exists
if [ ! -d ".venv" ]; then
    echo "Installing Python 3.10 to project directory..."
    echo "Install location: $UV_PYTHON_INSTALL_DIR"
    if ! uv python install 3.10; then
        echo "ERROR: Failed to install Python 3.10"
        return 1 2>/dev/null || exit 1
    fi

    echo "Creating virtual environment and syncing dependencies..."
    if ! uv sync --python 3.10; then
        echo "ERROR: Failed to sync dependencies"
        return 1 2>/dev/null || exit 1
    fi
fi

source .venv/bin/activate
echo "Python: $(python --version)"
echo "Location: $(which python)"

# ============================================================
# Download data files (full dataset: 1.18M products)
# ============================================================
echo ""
echo "=== Downloading Data Files (Full Dataset) ==="
mkdir -p data
cd data

echo "Downloading items_shuffle.json (~1.5GB)..."
if [ ! -f "items_shuffle.json" ]; then
    python -m gdown "https://drive.google.com/uc?id=1A2whVgOO0euk5O13n2iYDM0bQRkkRduB" -O items_shuffle.json
else
    echo "  items_shuffle.json already exists, skipping"
fi

echo "Downloading items_ins_v2.json (~500MB)..."
if [ ! -f "items_ins_v2.json" ]; then
    python -m gdown "https://drive.google.com/uc?id=1s2j6NgHljiZzQNL3veZaAiyW_qDEgBNi" -O items_ins_v2.json
else
    echo "  items_ins_v2.json already exists, skipping"
fi

echo "Downloading items_human_ins.json..."
if [ ! -f "items_human_ins.json" ]; then
    python -m gdown "https://drive.google.com/uc?id=14Kb5SPBk_jfdLZ_CDBNitW98QLDlKR5O" -O items_human_ins.json
else
    echo "  items_human_ins.json already exists, skipping"
fi

cd "$SCRIPT_DIR"

# ============================================================
# Download spaCy model (use uv since venv has no pip)
# ============================================================
echo ""
echo "=== Downloading spaCy Model ==="
if ! python -c "import spacy; spacy.load('en_core_web_lg')" 2>/dev/null; then
    uv pip install https://github.com/explosion/spacy-models/releases/download/en_core_web_lg-3.7.1/en_core_web_lg-3.7.1-py3-none-any.whl
else
    echo "  en_core_web_lg already installed, skipping"
fi

# ============================================================
# Build search engine index
# ============================================================
echo ""
echo "=== Building Search Engine Index ==="
cd search_engine

# Create resource directories
mkdir -p resources
mkdir -p indexes

# Convert product file format
echo "Converting product data to search engine format..."
python convert_product_file_format.py

# Build full index
echo "Building Lucene index for all products (this may take a while)..."
if [ ! -d "indexes/segments_1" ] && [ -z "$(ls -A indexes 2>/dev/null)" ]; then
    python -m pyserini.index.lucene \
        --collection JsonCollection \
        --input resources \
        --index indexes \
        --generator DefaultLuceneDocumentGenerator \
        --threads 8 \
        --storePositions --storeDocvectors --storeRaw
else
    echo "  indexes already built, skipping"
fi

cd "$SCRIPT_DIR"

# ============================================================
# Create log directory
# ============================================================
mkdir -p user_session_logs/mturk

echo ""
echo "=== Bootstrap Complete ==="
echo "Python: $(python --version)"
echo "Location: $(which python)"
echo ""
echo "To start the server on worker machines:"
echo "  cd $SCRIPT_DIR && source start_server.sh"
