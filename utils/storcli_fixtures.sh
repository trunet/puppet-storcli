#!/bin/bash
# Fixture Data Collection Script for puppet-storcli
# This script automates the collection of JSON fixture data from MegaRAID controllers

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}ERROR: This script must be run as root${NC}"
   echo "Usage: sudo $0 [storcli_binary] [controller_model]"
   exit 1
fi

# Default values
STORCLI_BIN=${1:-storcli64}
CONTROLLER_MODEL=${2}

# Function to find storcli binary
find_storcli() {
    local bins=("storcli64" "storcli" "perccli64" "perccli" \
                "/opt/MegaRAID/storcli/storcli64" \
                "/opt/MegaRAID/storcli/storcli" \
                "/opt/MegaRAID/perccli/perccli64" \
                "/opt/MegaRAID/perccli/perccli")

    for bin in "${bins[@]}"; do
        if command -v "$bin" &> /dev/null; then
            echo "$bin"
            return 0
        fi
    done
    return 1
}

# If no binary specified, try to find one
if [ -z "$1" ]; then
    echo -e "${YELLOW}No storcli binary specified, attempting to auto-detect...${NC}"
    STORCLI_BIN=$(find_storcli)
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Could not find storcli or perccli binary${NC}"
        echo "Please specify the binary path as the first argument"
        exit 1
    fi
    echo -e "${GREEN}Found: $STORCLI_BIN${NC}"
fi

# Verify binary exists and is executable
if ! command -v "$STORCLI_BIN" &> /dev/null; then
    echo -e "${RED}ERROR: Binary '$STORCLI_BIN' not found or not executable${NC}"
    exit 1
fi

# Auto-detect controller model if not specified
if [ -z "$CONTROLLER_MODEL" ]; then
    echo -e "${YELLOW}No controller model specified, attempting to auto-detect...${NC}"

    # Try to extract product name from controller info
    CONTROLLER_MODEL=$($STORCLI_BIN /call show J nolog 2>/dev/null | grep -i "Product Name" | head -1 | sed 's/.*"Product Name" : "\(.*\)".*/\1/')
fi

FIXTURE_DIR="spec/fixtures/$CONTROLLER_MODEL"

echo ""
echo "========================================"
echo "Collecting Fixtures"
echo "========================================"
echo "Binary:     $STORCLI_BIN"
echo "Model:      $CONTROLLER_MODEL"
echo "Output dir: $FIXTURE_DIR"
echo "========================================"
echo ""

# Create fixture directory
mkdir -p "$FIXTURE_DIR"

# Function to run command and save output
run_and_save() {
    local cmd="$1"
    local output_file="$2"
    local description="$3"

    echo -n "Collecting $description... "

    if eval "$cmd" > "$output_file" 2>/dev/null; then
        # Verify it's valid JSON
        if python3 -m json.tool "$output_file" > /dev/null 2>&1; then
            echo -e "${GREEN}OK${NC}"
            return 0
        else
            echo -e "${YELLOW}WARNING: Invalid JSON${NC}"
            return 1
        fi
    else
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
}

# Collect main controller info
run_and_save \
    "$STORCLI_BIN /call show J nolog" \
    "$FIXTURE_DIR/storcli_call_show.json" \
    "main controller info"

# Collect patrol read info
run_and_save \
    "$STORCLI_BIN /call show patrolread J nolog" \
    "$FIXTURE_DIR/storcli_call_show_patrolread.json" \
    "patrol read info"

# Collect consistency check info
run_and_save \
    "$STORCLI_BIN /call show cc J nolog" \
    "$FIXTURE_DIR/storcli_call_show_cc.json" \
    "consistency check info"

# Detect controllers and virtual disks
echo ""
echo "Detecting controllers and virtual disks..."

# Parse the main show output to find controllers and VDs
if [ -f "$FIXTURE_DIR/storcli_call_show.json" ]; then
    # Extract controller IDs and their VDs
    # This is a simplified approach - in real use, you might want to use jq

    # Try to detect number of controllers
    CONTROLLER_COUNT=$($STORCLI_BIN /call show J nolog 2>/dev/null | grep -c '"Controller" :' || echo "0")

    if [ "$CONTROLLER_COUNT" -gt 0 ]; then
        echo "Found $CONTROLLER_COUNT controller(s)"

        # For each controller, try to detect VDs
        for ((c=0; c<CONTROLLER_COUNT; c++)); do
            echo ""
            echo "Checking controller $c for virtual disks..."

            # Get VD list for this controller
            VD_LIST=$($STORCLI_BIN /c$c show J nolog 2>/dev/null | grep "DG/VD" | grep -oP '"\d+/\d+"' | grep -oP '\d+/\K\d+' | sort -u || echo "")

            if [ -n "$VD_LIST" ]; then
                for vd in $VD_LIST; do
                    run_and_save \
                        "$STORCLI_BIN /c$c/v$vd show all J nolog" \
                        "$FIXTURE_DIR/storcli_call_show_vdisk${vd}.json" \
                        "VD $vd on controller $c"
                done
            else
                echo "  No virtual disks found on controller $c"
            fi
        done
    fi
fi

echo ""
echo "========================================"
echo "Collection Complete!"
echo "========================================"
echo ""
echo "Files created in: $FIXTURE_DIR"
echo ""
ls -lh "$FIXTURE_DIR"
echo ""
echo "Next steps:"
echo "1. Review the collected files"
echo "2. Validate JSON: for f in $FIXTURE_DIR/*.json; do python3 -m json.tool \$f > /dev/null && echo \"\$f OK\"; done"
echo "3. Add test cases to spec/unit/facter/megaraid_spec.rb"
echo "4. Run tests: bundle exec rake spec"
echo ""
