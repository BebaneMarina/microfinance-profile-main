# run.py - Script de démarrage
import uvicorn
import os
from app.main import app

if __name__ == "__main__":
    # Configuration pour le développement
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8000)),
        reload=True,
        log_level="info"
    )