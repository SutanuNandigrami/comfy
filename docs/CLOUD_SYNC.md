# Cloud Sync Setup (Optional)

The `deploy_vastai.sh` script supports syncing your workspace from Google Drive instead of cloning from GitHub.

## How to Enable Cloud Sync

1. **Set environment variables** before running `deploy_vastai.sh`:
   ```bash
   export VAST_CONNECTION_ID="your_connection_id"
   export VAST_INSTANCE_ID="your_instance_id"
   ```

2. **Or add to your `.env` file**:
   ```bash
   VAST_CONNECTION_ID=your_connection_id
   VAST_INSTANCE_ID=your_instance_id
   ```

3. **Setup Vast.AI Cloud Storage**:
   - Follow the Vast.AI documentation to set up Google Drive sync
   - Get your connection ID from the Vast.AI portal

## Default Behavior

If cloud sync variables are **not** set:
- ✅ Script will clone repository from GitHub (default)
- ✅ Fresh, clean deployment every time
- ✅ No additional setup required

## When to Use Cloud Sync

Use cloud sync if you want to:
- Persist custom nodes or models between instances  
- Sync workspace across multiple deployments
- Avoid re-downloading large files

## Not Using Cloud Sync

If you're not using cloud sync (most users):
- Nothing to do! Script works out of the box
- GitHub clone is the default and recommended method
- Ensures you always get the latest code
