# CivitAI API Usage in Notebook

## Quick Example

```python
# Import the CivitAI API utility
from civitai_api import CivitAIAPI

# Initialize with your token (loaded from environment)
import os
api = CivitAIAPI(api_token=os.getenv('CIVITAI_API_TOKEN'))

# Search for top SDXL LoRAs
top_loras = api.get_top_loras(base_model="SDXL 1.0", limit=5)
for lora in top_loras:
    print(f"{lora['name']} - Downloads: {lora['stats']['downloadCount']}")

# Get specific model info
model = api.get_model(126343)  # Touch of Realism
print(f"Model: {model['name']}")
print(f"Download URL: {model['modelVersions'][0]['downloadUrl']}")
```

## In Jupyter Notebook

Add this cell after platform detection:

```python
# Set CivitAI API Token
import os
os.environ['CIVITAI_API_TOKEN'] = 'your_token_here'  # Replace with your token

# Or load from config if using .env
from config import CIVITAI_API_TOKEN
os.environ['CIVITAI_API_TOKEN'] = CIVITAI_API_TOKEN
```

Then use the API anywhere:

```python
from civitai_api import CivitAIAPI

api = CivitAIAPI()  # Automatically uses CIVITAI_API_TOKEN from environment

# Find NSFW models
nsfw_models = api.search_models(
    types=["LORA"],
    base_models=["SDXL 1.0"],
    sort="Most Downloaded",
    nsfw=True,
    limit=10
)

for model in nsfw_models['items']:
    print(f"{model['name']} - {model['stats']['downloadCount']} downloads")
```

## Environment Variable Locations

1. **Local Development**: Add to `.env` file
   ```bash
   CIVITAI_API_TOKEN=your_civitai_api_token_here
   ```

2. **Kaggle Notebook**: Set in a cell
   ```python
   import os
   os.environ['CIVITAI_API_TOKEN'] = 'your_civitai_api_token_here'
   ```

3. **Google Colab**: Add to secrets or set in cell
   ```python
   from google.colab import userdata
   os.environ['CIVITAI_API_TOKEN'] = userdata.get('CIVITAI_API_TOKEN')
   # Or directly:
   os.environ['CIVITAI_API_TOKEN'] = 'your_civitai_api_token_here'
   ```

## Your Token
```
your_civitai_api_token_here
```

Get more tokens or manage: https://civitai.com/user/account
