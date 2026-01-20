#!/bin/bash
# WebShop Server Startup Script
# Usage: source start_server.sh [--port PORT] [--host HOST]
#
# Run this on worker machines after bootstrap.sh has been run on master.
# No internet connection required.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== WebShop Server ==="

# ============================================================
# Parse arguments
# ============================================================
PORT=3000
HOST="0.0.0.0"
LOG_ENABLED="--log"
ATTRS_ENABLED="--attrs"

while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --no-log)
            LOG_ENABLED=""
            shift
            ;;
        --no-attrs)
            ATTRS_ENABLED=""
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: source start_server.sh [--port PORT] [--host HOST] [--no-log] [--no-attrs]"
            return 1 2>/dev/null || exit 1
            ;;
    esac
done

# ============================================================
# Check prerequisites
# ============================================================
if [ ! -d ".venv" ]; then
    echo "ERROR: .venv not found. Please run bootstrap.sh on master first."
    return 1 2>/dev/null || exit 1
fi

if [ ! -f "data/items_human_ins.json" ]; then
    echo "ERROR: Data files not found. Please run bootstrap.sh on master first."
    return 1 2>/dev/null || exit 1
fi

if [ ! -d "search_engine/indexes" ]; then
    echo "ERROR: Search index not found. Please run bootstrap.sh on master first."
    return 1 2>/dev/null || exit 1
fi

# ============================================================
# Activate virtual environment
# ============================================================
export UV_PYTHON_INSTALL_DIR="$SCRIPT_DIR/.uv/python"
source .venv/bin/activate

echo "Server will run on: http://$HOST:$PORT"

# ============================================================
# Start Flask server
# ============================================================
export FLASK_ENV=development
export WEBSHOP_HOST="$HOST"
export WEBSHOP_PORT="$PORT"

echo ""
echo "Starting WebShop server..."
echo "Server will preload 1.18M products before accepting requests."
echo "This may take a few minutes on first run."
echo ""
echo "Test URLs (after preload completes):"
echo "  http://localhost:$PORT/fixed_0  - Task 0"
echo "  http://localhost:$PORT/fixed_1  - Task 1"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python -m web_agent_site.app $LOG_ENABLED $ATTRS_ENABLED
