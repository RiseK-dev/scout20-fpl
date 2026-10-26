# FPL Best Buys - Python Backend

FastAPI backend that fetches real-time Fantasy Premier League data and evaluates top transfer recommendations using an algorithm based on form, fixture difficulty (FDR), expected points, and price value.

## Quick Start

1. Install requirements:
   ```bash
   pip install -r requirements.txt
   ```

2. Run the FastAPI development server:
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

3. Open interactive API Documentation:
   - Web browser: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

## API Endpoints

- `GET /` - Health check & server status
- `GET /api/overview` - Current Gameweek & deadline info
- `GET /api/best-buys?position=MID&max_price=9.0&limit=20` - Recommended player picks
