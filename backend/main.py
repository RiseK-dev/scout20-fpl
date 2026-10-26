from typing import Optional
from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fpl_service import get_fpl_best_buys, get_fpl_jokers, fetch_fpl_raw_data

app = FastAPI(
    title="FPL Best Buys API",
    description="Backend API calculating top Fantasy Premier League transfer recommendations based on form, fixtures, value, and expected stats.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": "FPL Best Buys Backend",
        "docs_url": "/docs"
    }


@app.get("/api/best-buys")
async def api_best_buys(
    position: Optional[str] = Query(None, description="Position filter: GKP, DEF, MID, FWD, or ALL"),
    max_price: Optional[float] = Query(None, description="Maximum price filter in millions (e.g. 8.5)"),
    limit: int = Query(20, ge=1, le=100, description="Number of player recommendations to return (default 20)"),
    next_gameweeks: int = Query(3, ge=1, le=8, description="Number of upcoming gameweeks to analyze for fixtures"),
    sort_by: str = Query("expected_points", description="Sort by: 'expected_points' or 'best_buy_score'")
):
    try:
        data = await get_fpl_best_buys(
            position_filter=position,
            max_price=max_price,
            limit=limit,
            next_gameweeks=next_gameweeks,
            sort_by=sort_by
        )
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch or process FPL data: {str(e)}")


@app.get("/api/jokers")
async def api_jokers(
    max_price: float = Query(6.5, ge=4.0, le=10.0, description="Max price for joker player"),
    max_ownership: float = Query(20.0, ge=1.0, le=50.0, description="Max ownership in %"),
    limit: int = Query(1, ge=1, le=20, description="Number of jokers to return"),
    next_gameweeks: int = Query(3, ge=1, le=8, description="Number of upcoming gameweeks")
):
    try:
        data = await get_fpl_jokers(
            max_price=max_price,
            max_ownership=max_ownership,
            limit=limit,
            next_gameweeks=next_gameweeks
        )
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Kunne ikke beregne jokere: {str(e)}")


@app.get("/api/overview")
async def api_overview():
    try:
        raw_data = await fetch_fpl_raw_data()
        bootstrap = raw_data["bootstrap"]
        events = bootstrap.get("events", [])

        current_gw = next((e for e in events if e.get("is_next") or e.get("is_current")), None)

        return {
            "current_gameweek": current_gw.get("id") if current_gw else 1,
            "gameweek_name": current_gw.get("name") if current_gw else "GW1",
            "deadline_time": current_gw.get("deadline_time") if current_gw else None,
            "total_fpl_players": len(bootstrap.get("elements", [])),
            "teams_count": len(bootstrap.get("teams", [])),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch overview: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
