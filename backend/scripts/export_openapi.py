"""Writes docs/openapi.json (import it into Postman/Insomnia, or generate a typed client)."""
import json
from pathlib import Path

from app.main import app

Path("docs").mkdir(exist_ok=True)
Path("docs/openapi.json").write_text(json.dumps(app.openapi(), indent=2))
print("docs/openapi.json written")
