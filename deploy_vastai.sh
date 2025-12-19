#!/bin/bash
# Vast.AI CLI Deployment Script for ComfyUI
# One-command deployment with Google Drive sync
# Based on official Vast.AI API documentation: https://docs.vast.ai

set -e

echo "🔍 Searching for available RTX 3090 instances..."

# Search filters matching user's GUI criteria
# IMPORTANT: Filters include bandwidth costs, not just GPU specs
OFFERS=$(vastai search offers \
  "num_gpus=1 gpu_name=RTX_3090 \
   reliability >= 0.955 \
   cpu_cores_effective >= 7.89 \
   cpu_ram >= 30.5 \
   inet_down >= 724 \
   inet_up >= 652 \
   inet_down_cost <= 0.13 \
   inet_up_cost <= 0.13" \
  --order "dph_total+" \
  --limit 20 \
  --raw)

# Parse JSON response (requires jq)
if ! command -v jq &> /dev/null; then
  echo "❌ Error: 'jq' is required but not installed."
  echo "Install from: https://jqlang.github.io/jq/download/"
  exit 1
fi

# Check if we got any results
OFFER_COUNT=$(echo "$OFFERS" | jq -r 'length')
if [ "$OFFER_COUNT" -eq 0 ]; then
  echo "❌ No suitable offers found!"
  echo "Try different search criteria or check manually at https://console.vast.ai/"
  exit 1
fi

echo "📊 Found $OFFER_COUNT matching offers, calculating total costs..."

# Calculate total cost for each offer (GPU + 200GB disk + bandwidth estimate)
DISK_GB=200
BANDWIDTH_GB_ESTIMATE=50  # Estimate ~50GB download for ComfyUI setup
BEST_TOTAL=999999
BEST_OFFER_ID=""
BEST_OFFER_INDEX=-1

for i in $(seq 0 $((OFFER_COUNT - 1))); do
  OFFER_ID=$(echo "$OFFERS" | jq -r ".[$i].id")
  GPU_COST=$(echo "$OFFERS" | jq -r ".[$i].dph_total")
  STORAGE_COST=$(echo "$OFFERS" | jq -r ".[$i].storage_cost")
  INET_DOWN_COST=$(echo "$OFFERS" | jq -r ".[$i].inet_down_cost")
  INET_UP_COST=$(echo "$OFFERS" | jq -r ".[$i].inet_up_cost")
  
  # Calculate disk cost per hour: (storage_cost * disk_GB) / 730
  DISK_HOURLY=$(awk "BEGIN {printf \"%.6f\", ($STORAGE_COST * $DISK_GB) / 730}")
  
  # Calculate bandwidth cost estimate (one-time, but amortize over expected runtime)
  # Assume 24hr runtime, so bandwidth_cost_per_gb * GB / 24
  BANDWIDTH_HOURLY=$(awk "BEGIN {printf \"%.6f\", ($INET_DOWN_COST * $BANDWIDTH_GB_ESTIMATE) / 24}")
  
  # Total cost = GPU + Disk + Bandwidth
  TOTAL_COST=$(awk "BEGIN {printf \"%.6f\", $GPU_COST + $DISK_HOURLY + $BANDWIDTH_HOURLY}")
  
  echo "  Offer $((i+1)): GPU \$$GPU_COST + Disk \$$DISK_HOURLY + BW \$$BANDWIDTH_HOURLY = \$$TOTAL_COST/hr"
  
  # Compare using awk (works in Git Bash)
  IS_BETTER=$(awk "BEGIN {print ($TOTAL_COST < $BEST_TOTAL) ? 1 : 0}")
  if [ "$IS_BETTER" = "1" ]; then
    BEST_TOTAL=$TOTAL_COST
    BEST_OFFER_ID=$OFFER_ID
    BEST_OFFER_INDEX=$i
  fi
done

if [ -z "$BEST_OFFER_ID" ] || [ "$BEST_OFFER_ID" = "null" ]; then
  echo "❌ Could not calculate costs!"
  exit 1
fi

echo ""
echo "✅ Selected offer with LOWEST TOTAL COST:"

# Extract details of best offer
OFFER_ID=$BEST_OFFER_ID
OFFER_GPU_PRICE=$(echo "$OFFERS" | jq -r ".[$BEST_OFFER_INDEX].dph_total")
OFFER_STORAGE_COST=$(echo "$OFFERS" | jq -r ".[$BEST_OFFER_INDEX].storage_cost")
OFFER_INET_DOWN_COST=$(echo "$OFFERS" | jq -r ".[$BEST_OFFER_INDEX].inet_down_cost")
OFFER_INET_UP_COST=$(echo "$OFFERS" | jq -r ".[$BEST_OFFER_INDEX].inet_up_cost")
OFFER_LOCATION=$(echo "$OFFERS" | jq -r ".[$BEST_OFFER_INDEX].geolocation")

# Calculate final costs
DISK_MONTHLY_COST=$(awk "BEGIN {printf \"%.4f\", $OFFER_STORAGE_COST * $DISK_GB}")
DISK_HOURLY_COST=$(awk "BEGIN {printf \"%.6f\", $DISK_MONTHLY_COST / 730}")
BANDWIDTH_EST=$(awk "BEGIN {printf \"%.6f\", ($OFFER_INET_DOWN_COST * $BANDWIDTH_GB_ESTIMATE) / 24}")
TOTAL_HOURLY=$BEST_TOTAL

echo "✅ Found offer:"
echo "  ID: $OFFER_ID"
echo "  Location: $OFFER_LOCATION"
echo ""
echo "💰 Pricing Breakdown:"
echo "  GPU Cost:       \$$(printf "%.4f" $OFFER_GPU_PRICE)/hr"
echo "  Disk (${DISK_GB}GB): \$$(printf "%.4f" $DISK_HOURLY_COST)/hr (\$${OFFER_STORAGE_COST}/GB/month)"
echo "  Download:       \$${OFFER_INET_DOWN_COST}/GB"
echo "  Upload:         \$${OFFER_INET_UP_COST}/GB"
echo "  BW Est (~${BANDWIDTH_GB_ESTIMATE}GB): \$$(printf "%.4f" $BANDWIDTH_EST)/hr"
echo "  ────────────────────────"
echo "  TOTAL:          \$$(printf "%.4f" $TOTAL_HOURLY)/hr"
echo ""

# Check for running instances and stop them to avoid double billing
# API docs: vastai show instances --raw
echo "🔍 Checking for running instances..."
RUNNING_INSTANCES=$(vastai show instances --raw 2>/dev/null | jq -r '.[] | select(.actual_status == "running") | .id' || echo "")

if [ -n "$RUNNING_INSTANCES" ]; then
  echo "⚠️  Found running instances:"
  vastai show instances
  echo ""
  read -p "Stop all running instances before deploying new one? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    for instance_id in $RUNNING_INSTANCES; do
      echo "🛑 Stopping instance $instance_id..."
      # API docs: vastai destroy instance <id>
      vastai destroy instance "$instance_id"
    done
    echo "✅ All instances stopped"
    sleep 2
  else
    echo "⚠️  Continuing with existing instances running (you'll be billed for both!)"
  fi
fi

echo ""
read -p "Deploy new instance? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled"
  exit 1
fi

echo "📦 Creating instance..."

# On-start script (executed after instance creation)
# API docs: --onstart-cmd 'script_contents'
ONSTART_SCRIPT=$(cat <<'EOF'
#!/bin/bash
set -e

# Python fix for vastai/pytorch images
if ! command -v python >/dev/null 2>&1; then
  if command -v python3 >/dev/null 2>&1; then
    sudo ln -sf "$(command -v python3)" /usr/bin/python || true
  fi
fi

# Workspace setup
mkdir -p /workspace
cd /workspace

# Google Drive sync (download from cloud to instance)
CONNECTION_ID="${VAST_CONNECTION_ID:-}"
INSTANCE_ID="${VAST_INSTANCE_ID:-}"

if [ -n "$CONNECTION_ID" ] && [ -n "$INSTANCE_ID" ]; then
  echo "[SYNC] Downloading workspace from Google Drive..."
  python3 vast.py cloud copy \
    --src "/workspace/" \
    --dst "/workspace/" \
    --instance "$INSTANCE_ID" \
    --connection "$CONNECTION_ID" \
    --transfer "Cloud To Instance" \
    || echo "[WARN] Cloud sync failed (continuing anyway)"
  
  # Remove old comfy directory (will clone fresh from GitHub)
  if [ -d "/workspace/comfy" ]; then
    echo "[SYNC] Removing old comfy directory..."
    rm -rf /workspace/comfy
  fi
fi

# Clone/update repository
if [ ! -d "comfy" ]; then
  echo "[REPO] Cloning comfy repository..."
  git clone https://github.com/SutanuNandigrami/comfy.git
else
  echo "[REPO] Updating comfy repository..."
  cd comfy && git pull && cd ..
fi

cd comfy

# Install ComfyUI + Models
echo "[INSTALL] Running ComfyUI installer..."
bash install_comfyui_auto.sh \
  --hf-token="${HF_TOKEN}" \
  --civitai-token="${CIVITAI_TOKEN}"

# Fix paths: ComfyUI runs from /workspace/ComfyUI but models are in /workspace/comfy
echo "[FIX] Linking models to ComfyUI directory..."
ln -sfn /workspace/comfy/models /workspace/ComfyUI/models
ln -sfn /workspace/comfy/custom_nodes /workspace/ComfyUI/custom_nodes

# Copy workflows to ComfyUI user directory
echo "[FIX] Copying workflows..."
mkdir -p /workspace/ComfyUI/user/default/workflows/
cp -f /workspace/comfy/workflows/*.json /workspace/ComfyUI/user/default/workflows/ 2>/dev/null || true

# Create extra_model_paths.yaml as backup
cat > /workspace/ComfyUI/extra_model_paths.yaml << 'EOFPATHS'
comfy:
    base_path: /workspace/comfy/
    checkpoints: models/checkpoints/
    clip: models/clip/
    clip_vision: models/clip_vision/
    controlnet: models/controlnet/
    loras: models/loras/
    upscale_models: models/upscale_models/
    vae: models/vae/
EOFPATHS

# Launch ComfyUI with ngrok tunnel
echo "[LAUNCH] Starting ComfyUI with tunnel..."
cd /workspace/comfy
export NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN}"

# Run in background but show output in console via tee
echo "[INFO] Launching ComfyUI - tunnel URL will appear below..."
python launch_with_tunnel.py 2>&1 | tee /workspace/comfy_tunnel.log &

# Give it time to start and print ngrok URL
sleep 15

echo ""
echo "✅ Setup complete!"
echo "📂 Full log: /workspace/comfy_tunnel.log"
echo "🌐 Ngrok URL should be displayed above"
nvidia-smi || true
EOF
)

# Create instance using official API syntax
# API docs: vastai create instance ID --image IMAGE --disk SIZE --ssh --direct --env 'OPTIONS' --onstart-cmd 'SCRIPT'
echo "🚀 Creating instance $OFFER_ID..."

# === SECURITY: Load tokens from environment or .env file ===
echo "🔐 Loading API tokens..."

# Try to load from .env file if it exists
ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
  echo "✅ Loaded tokens from .env file"
else
  echo "⚠️  No .env file found, using environment variables"
fi

# Validate required tokens
MISSING_TOKENS=()
[ -z "$HF_TOKEN" ] && MISSING_TOKENS+=("HF_TOKEN")
[ -z "$CIVITAI_TOKEN" ] && MISSING_TOKENS+=("CIVITAI_TOKEN")
[ -z "$NGROK_AUTHTOKEN" ] && MISSING_TOKENS+=("NGROK_AUTHTOKEN")

if [ ${#MISSING_TOKENS[@]} -gt 0 ]; then
  echo "❌ Missing required tokens: ${MISSING_TOKENS[*]}"
  echo ""
  echo "Please set them in .env file or export as environment variables:"
  echo "  export HF_TOKEN=your_huggingface_token"
  echo "  export CIVITAI_TOKEN=your_civitai_token"
  echo "  export NGROK_AUTHTOKEN=your_ngrok_token"
  exit 1
fi

vastai create instance "$OFFER_ID" \
  --image "vastai/pytorch:cuda-12.4.1-auto" \
  --disk 200 \
  --ssh \
  --direct \
  --env "-p 8188:8188 -p 4040:4040 -p 8888:8888 -p 1111:1111 \
-e HF_TOKEN=$HF_TOKEN \
-e CIVITAI_TOKEN=$CIVITAI_TOKEN \
-e NGROK_AUTHTOKEN=$NGROK_AUTHTOKEN \
-e CUDA_VISIBLE_DEVICES=0 \
-e VAST_CONNECTION_ID=34520 \
-e PORTAL_CONFIG='localhost:1111:11111:/:Instance Portal|localhost:8080:18080:/:Jupyter|localhost:8080:8080:/terminals/1:Jupyter Terminal|localhost:8188:8188:/:ComfyUI|localhost:8384:18384:/:Syncthing|localhost:6006:16006:/:Tensorboard'" \
  --onstart-cmd "$ONSTART_SCRIPT"

echo ""
echo "======================================"
echo "✅ Instance deployed successfully!"
echo "======================================"
echo ""
echo "📊 Check status:"
echo "  vastai show instances"
echo ""
echo "🔐 SSH into instance:"
echo "  vastai ssh <INSTANCE_ID>"
echo ""
echo "📝 View logs:"
echo "  vastai ssh <INSTANCE_ID> 'tail -f /workspace/comfy_tunnel.log'"
echo ""
echo "🌐 Get ngrok URL:"
echo "  vastai ssh <INSTANCE_ID> 'grep -o \"https://.*\\.ngrok-free\\.app\" /workspace/comfy_tunnel.log | tail -1'"
echo ""
