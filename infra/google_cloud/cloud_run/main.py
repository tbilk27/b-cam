"""
b-cam Cloud Run Service (100% Free Tier - 2M Requests/Month)
Processamento Multimodal com Gemini e Notificações Push com Deeplink.
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import os

app = FastAPI(title="b-cam Surveillance AI Gateway")

class BoundingBox(BaseModel):
    label: str
    confidence: float
    left: float
    top: float
    width: float
    height: float

class EventRequest(BaseModel):
    cameraId: str
    cameraName: str
    minConfidence: float = 0.25
    imageBase64: Optional[str] = None
    customPrompt: Optional[str] = None

@app.get("/health")
def health():
    return {"status": "online", "service": "b-cam-ai-gateway", "tier": "100% Free"}

@app.post("/api/events/analyze")
def analyze_event(req: EventRequest):
    # Simulação ou integração com Gemini
    simulated_confidence = 0.94
    if simulated_confidence < req.minConfidence:
        return {
            "status": "discarded",
            "reason": f"Confiança ({simulated_confidence}) abaixo do limiar ({req.minConfidence})"
        }
    
    event_id = f"evt-{req.cameraId}-run"
    deep_link = f"bcam://event/{event_id}"
    
    return {
        "status": "created",
        "eventId": event_id,
        "deepLink": deep_link,
        "confidence": simulated_confidence,
        "boundingBoxes": [
            {
                "label": "Pessoa",
                "confidence": 0.94,
                "left": 0.42,
                "top: 0.28,
                "width": 0.20,
                "height": 0.54
            }
        ]
    }
