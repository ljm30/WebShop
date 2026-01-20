#!/bin/bash
# WebShop Server Startup Script
# Usage: source start_server.sh [--port PORT] [--bg]
#
# Run this on worker machines after bootstrap.sh has been run on master.
# No internet connection required.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== WebShop Server ==="

# ============================================================
# Use Java 11 from NAS (required for pyserini)
# ============================================================
JAVA11_PATH="$(dirname "$SCRIPT_DIR")/java11"
if [ -d "$JAVA11_PATH" ]; then
    export JAVA_HOME="$JAVA11_PATH"
    export PATH="$JAVA_HOME/bin:$PATH"
fi

# Disable vector module that requires Java 16+
export JDK_JAVA_OPTIONS=""
export _JAVA_OPTIONS=""
export JAVA_TOOL_OPTIONS=""

# ============================================================
# Parse arguments
# ============================================================
PORT=3000
HOST="0.0.0.0"
LOG_ENABLED="--log"
ATTRS_ENABLED="--attrs"
RUN_IN_BG=false

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
        --bg)
            RUN_IN_BG=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: source start_server.sh [--port PORT] [--host HOST] [--bg] [--no-log] [--no-attrs]"
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

LOG_FILE="$SCRIPT_DIR/webshop_server.log"

if [ "$RUN_IN_BG" = true ]; then
    echo "Starting in background mode..."
    echo "Log file: $LOG_FILE"
    echo "To stop: kill \$(cat $SCRIPT_DIR/webshop.pid)"
    echo ""
    nohup python -m web_agent_site.app $LOG_ENABLED $ATTRS_ENABLED > "$LOG_FILE" 2>&1 &
    echo $! > "$SCRIPT_DIR/webshop.pid"
    echo "Server started with PID: $(cat $SCRIPT_DIR/webshop.pid)"
    echo "Waiting for server to be ready..."

    # Wait for server to start (check if port is listening)
    for i in {1..120}; do
        if curl -s "http://localhost:$PORT" > /dev/null 2>&1; then
            echo "Server is ready!"
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""
else
    echo "Press Ctrl+C to stop the server"
    echo ""
    python -m web_agent_site.app $LOG_ENABLED $ATTRS_ENABLED
fi
