#!/usr/bin/env python3
"""
CivitAI API Utility
Provides functions to interact with CivitAI API for model discovery and download URL extraction.
"""
import requests
from typing import Dict, List, Optional
import os

class CivitAIAPI:
    """Wrapper for CivitAI REST API v1"""
    
    BASE_URL = "https://civitai.com/api/v1"
    
    def __init__(self, api_token: Optional[str] = None):
        """
        Initialize CivitAI API client
        
        Args:
            api_token: Optional CivitAI API token for authenticated requests
        """
        self.api_token = api_token or os.getenv("CIVITAI_API_TOKEN")
        self.headers = {"Content-Type": "application/json"}
       
        if self.api_token:
            self.headers["Authorization"] = f"Bearer {self.api_token}"
    
    def get_model(self, model_id: int) -> Dict:
        """
        Get model details by ID
        
        Args:
            model_id: CivitAI model ID
            
        Returns:
            Model data including all versions and download URLs
        """
        url = f"{self.BASE_URL}/models/{model_id}"
        response = requests.get(url, headers=self.headers)
        response.raise_for_status()
        return response.json()
    
    def search_models(self, 
                     query: Optional[str] = None,
                     types: Optional[List[str]] = None,
                     sort: str = "Highest Rated",
                     limit: int = 20,
                     base_models: Optional[List[str]] = None) -> Dict:
        """
        Search for models
        
        Args:
            query: Search query string
            types: Model types (e.g., ["LORA", "Checkpoint"])
            sort: Sort order ("Highest Rated", "Most Downloaded", "Newest")
            limit: Number of results (max 100)
            base_models: Filter by base models (e.g., ["SDXL 1.0"])
            
        Returns:
            Search results with models list
        """
        url = f"{self.BASE_URL}/models"
        params = {"limit": limit, "sort": sort}
        
        if query:
            params["query"] = query
        if types:
            params["types"] = types
        if base_models:
            params["baseModels"] = base_models
            
        response = requests.get(url, headers=self.headers, params=params)
        response.raise_for_status()
        return response.json()
    
    def get_model_version(self, version_id: int) -> Dict:
        """
        Get specific model version details
        
        Args:
            version_id: Model version ID
            
        Returns:
            Version data including download URL
        """
        url = f"{self.BASE_URL}/model-versions/{version_id}"
        response = requests.get(url, headers=self.headers)
        response.raise_for_status()
        return response.json()
    
    def get_download_url(self, model_id: int, version_index: int = 0) -> str:
        """
        Get download URL for a model version
        
        Args:
            model_id: CivitAI model ID
            version_index: Index of version in model versions list (0 = latest)
            
        Returns:
            Download URL string
        """
        model_data = self.get_model(model_id)
        if "modelVersions" not in model_data or not model_data["modelVersions"]:
            raise ValueError(f"No versions found for model {model_id}")
            
        version = model_data["modelVersions"][version_index]
        return version.get("downloadUrl", "")
    
    def get_top_loras(self, base_model: str = "SDXL 1.0", limit: int = 10) -> List[Dict]:
        """
        Get top-rated LoRAs for a specific base model
        
        Args:
            base_model: Base model name (e.g., "SDXL 1.0", "SD 1.5")
            limit: Number of results
            
        Returns:
            List of LoRA models sorted by highest rating
        """
        result = self.search_models(
            types=["LORA"],
            base_models=[base_model],
            sort="Highest Rated",
            limit=limit
        )
        return result.get("items", [])


# Convenience functions
def get_civitai_download_url(model_id: int, api_token: Optional[str] = None) -> str:
    """Quick function to get download URL for a model"""
    api = CivitAIAPI(api_token)
    return api.get_download_url(model_id)


if __name__ == "__main__":
    # Example usage
    import sys
    
    if len(sys.argv) > 1:
        model_id = int(sys.argv[1])
        api = CivitAIAPI()
        
        print(f"Fetching model {model_id}...")
        try:
            model = api.get_model(model_id)
            print(f"\nModel: {model['name']}")
            print(f"Type: {model['type']}")
            print(f"\nVersions:")
            for idx, version in enumerate(model.get('modelVersions', [])):
                print(f"  [{idx}] {version['name']} - {version.get('downloadUrl', 'No URL')}")
        except Exception as e:
            print(f"Error: {e}")
    else:
        print("Usage: python civitai_api.py <model_id>")
        print("Example: python civitai_api.py 126343")
