import time
from typing import Dict, List, Optional, Any
import httpx

FPL_BOOTSTRAP_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"
FPL_FIXTURES_URL = "https://fantasy.premierleague.com/api/fixtures/"

# In-memory cache med 10-minutters TTL
_cache: Dict[str, Any] = {}
_cache_time: float = 0
CACHE_TTL = 600  # 10 minutter


async def fetch_fpl_raw_data() -> Dict[str, Any]:
    global _cache, _cache_time
    now = time.time()

    if _cache and (now - _cache_time < CACHE_TTL):
        return _cache

    async with httpx.AsyncClient(timeout=15.0) as client:
        bootstrap_res = await client.get(FPL_BOOTSTRAP_URL)
        bootstrap_res.raise_for_status()
        bootstrap_data = bootstrap_res.json()

        fixtures_res = await client.get(FPL_FIXTURES_URL)
        fixtures_res.raise_for_status()
        fixtures_data = fixtures_res.json()

    _cache = {
        "bootstrap": bootstrap_data,
        "fixtures": fixtures_data,
    }
    _cache_time = now
    return _cache


def get_position_name(element_type: int, element_types: List[Dict[str, Any]]) -> str:
    for et in element_types:
        if et["id"] == element_type:
            return et["singular_name_short"]  # e.g., GKP, DEF, MID, FWD
    return "UNKNOWN"


def get_team_map(teams_data: List[Dict[str, Any]]) -> Dict[int, Dict[str, Any]]:
    return {team["id"]: team for team in teams_data}


def is_player_injured_or_unavailable(player: Dict[str, Any]) -> bool:
    status = str(player.get("status") or "").lower()
    chance = player.get("chance_of_playing_next_round")
    news = str(player.get("news") or "").lower()

    if status in ['i', 's', 'u', 'n']:
        return True

    if chance is not None and chance == 0:
        return True

    if chance is not None and chance <= 25:
        return True

    if chance is not None and chance < 50:
        if any(kw in news for kw in ['injured', 'suspended', 'out for', 'knee', 'acl', 'hamstring']):
            return True

    return False


def calculate_form_multiplier(form: float, ppg: float) -> tuple[float, str]:
    if form >= 7.0:
        form_multiplier = 1.35
        form_desc = f"Brennhet form ({form} i snitt)"
    elif form >= 5.0:
        form_multiplier = 1.20
        form_desc = f"I kjempeform ({form} i snitt)"
    elif form >= 3.5:
        form_multiplier = 1.08
        form_desc = f"God form ({form} i snitt)"
    elif form >= 2.0:
        form_multiplier = 0.95
        form_desc = f"Middels form ({form} i snitt)"
    else:
        form_multiplier = 0.80
        form_desc = f"Svak form ({form} i snitt)"

    if form > (ppg + 2.0) and form >= 5.0:
        form_multiplier += 0.08
        form_desc += " 🔥 Hot Streak!"

    return round(form_multiplier, 2), form_desc


def calculate_set_piece_multiplier(player: Dict[str, Any]) -> tuple[float, List[str]]:
    pen_order = player.get("penalties_order")
    fk_order = player.get("direct_freekicks_order")
    corner_order = player.get("corners_and_indirect_freekicks_order")

    multiplier = 1.0
    roles = []

    if pen_order == 1:
        multiplier += 0.18
        roles.append("🎯 1st choice penalty taker")
    elif pen_order == 2:
        multiplier += 0.05
        roles.append("2nd choice penalties")

    if fk_order == 1:
        multiplier += 0.10
        roles.append("📐 Direct free-kick taker")

    if corner_order == 1:
        multiplier += 0.08
        roles.append("⛳ Corner taker")

    return round(multiplier, 2), roles


def calculate_match_odds(
    team_info: Dict[str, Any],
    opp_info: Dict[str, Any],
    is_home: bool,
    position: str
) -> tuple[float, float, str]:
    if is_home:
        team_str = team_info.get("strength_overall_home", 1100)
        team_att = team_info.get("strength_attack_home", 1100)
        team_def = team_info.get("strength_defence_home", 1100)
        opp_str = opp_info.get("strength_overall_away", 1100)
        opp_att = opp_info.get("strength_attack_away", 1100)
        opp_def = opp_info.get("strength_defence_away", 1100)
    else:
        team_str = team_info.get("strength_overall_away", 1050)
        team_att = team_info.get("strength_attack_away", 1050)
        team_def = team_info.get("strength_defence_away", 1050)
        opp_str = opp_info.get("strength_overall_home", 1150)
        opp_att = opp_info.get("strength_attack_home", 1150)
        opp_def = opp_info.get("strength_defence_home", 1150)

    diff = team_str - opp_str
    win_prob = 1.0 / (1.0 + (10.0 ** (-diff / 400.0)))
    win_prob = min(max(win_prob, 0.15), 0.85)

    match_odds = round(1.0 / win_prob, 2)
    odds_multiplier = 0.65 + (win_prob * 0.80)

    odd_info_text = f"Lav vinnerodds ({match_odds} / {int(win_prob*100)}% seierssjanse)"

    if position in ['GKP', 'DEF']:
        def_diff = team_def - opp_att
        cs_prob = 1.0 / (1.0 + (10.0 ** (-def_diff / 350.0)))
        cs_prob = min(max(cs_prob, 0.10), 0.65)
        cs_odds = round(1.0 / cs_prob, 2)

        odds_multiplier *= (0.85 + (cs_prob * 0.50))
        odd_info_text = f"Lav hold-nullen odds ({cs_odds} / {int(cs_prob*100)}% clean sheet sjanse)"

    return round(odds_multiplier, 2), match_odds, odd_info_text


def get_upcoming_fixtures_for_team(
    team_id: int,
    current_gw: int,
    fixtures_data: List[Dict[str, Any]],
    team_map: Dict[int, Dict[str, Any]],
    next_n: int = 5
) -> List[Dict[str, Any]]:
    upcoming = []
    for f in fixtures_data:
        if f.get("event") is not None and f["event"] >= current_gw and not f.get("finished", False):
            if f["team_h"] == team_id:
                opp_id = f["team_a"]
                fdr = f.get("team_h_difficulty", 3)
                is_home = True
            elif f["team_a"] == team_id:
                opp_id = f["team_h"]
                fdr = f.get("team_a_difficulty", 3)
                is_home = False
            else:
                continue

            opp_name = team_map.get(opp_id, {}).get("short_name", "OPP")
            upcoming.append({
                "event": f["event"],
                "opponent": opp_name,
                "opp_id": opp_id,
                "is_home": is_home,
                "fdr": fdr,
            })

            if len(upcoming) == next_n:
                break

    return upcoming


def calculate_next_round_expected_points(
    player: Dict[str, Any],
    upcoming_fixtures: List[Dict[str, Any]],
    team_map: Dict[int, Dict[str, Any]],
    position: str,
    is_most_transferred_in: bool = False
) -> tuple[float, str, List[str], bool]:
    """
    Calculates expected points in NEXT ROUND based on:
    1. Number of matches the team has in that round (Double Gameweek DGW = 2+ matches!)
    2. Player's ep_next and form
    3. Set pieces / Penalties
    4. Match odds for each match in the round
    5. Chance of playing
    """
    ep_next = float(player.get("ep_next") or 0.0)
    form = float(player.get("form") or 0.0)
    ppg = float(player.get("points_per_game") or 0.0)
    chance = player.get("chance_of_playing_next_round")

    if chance is not None and chance == 0:
        return 0.0, "Injured / Not available next round", [], False

    chance_multiplier = (chance / 100.0) if chance is not None else 1.0

    form_multiplier, form_desc = calculate_form_multiplier(form, ppg)
    set_piece_multiplier, set_piece_roles = calculate_set_piece_multiplier(player)
    transfer_boost = 1.10 if is_most_transferred_in else 1.0

    base_single_match_xp = ep_next if ep_next > 0 else (ppg * 0.8)

    if not upcoming_fixtures:
        return 0.0, "No fixtures scheduled in next round", set_piece_roles, False

    next_event = upcoming_fixtures[0]["event"]
    next_round_matches = [fx for fx in upcoming_fixtures if fx["event"] == next_event]

    is_double_gameweek = len(next_round_matches) >= 2
    total_xp_for_round = 0.0
    match_descriptions = []

    for fx in next_round_matches:
        opp_id = fx.get("opp_id")
        is_home = fx.get("is_home", True)
        opp_name = fx.get("opponent", "OPP")
        match_label = f"{opp_name} ({'H' if is_home else 'B'})"

        team_info = team_map.get(player["team"], {})
        opp_info = team_map.get(opp_id, {})

        odds_multiplier, _, _ = calculate_match_odds(
            team_info, opp_info, is_home, position
        )

        single_fx_xp = base_single_match_xp * form_multiplier * set_piece_multiplier * odds_multiplier * transfer_boost * chance_multiplier
        total_xp_for_round += single_fx_xp
        match_descriptions.append(match_label)

    final_next_round_xp = round(total_xp_for_round, 1)

    reasons = []
    if is_double_gameweek:
        reasons.append(f"⚡ DOUBLE GAMEWEEK (DGW)! 2 matches in GW{next_event}: {' + '.join(match_descriptions)}")
    if is_most_transferred_in:
        reasons.append("🔥 Most Transferred In in FPL this round! (+10% boost)")
    if set_piece_roles:
        reasons.append(" • ".join(set_piece_roles))
    if form >= 5.0:
        reasons.append(form_desc)

    if not reasons:
        reasons.append(f"Fixture in GW{next_event}: {' + '.join(match_descriptions)}")

    why_buy = " • ".join(reasons)

    return final_next_round_xp, why_buy, set_piece_roles, is_double_gameweek


async def get_fpl_best_buys(
    position_filter: Optional[str] = None,
    max_price: Optional[float] = None,
    limit: int = 20,
    next_gameweeks: int = 3,
    sort_by: str = "expected_points"
) -> Dict[str, Any]:
    raw_data = await fetch_fpl_raw_data()
    bootstrap = raw_data["bootstrap"]
    fixtures = raw_data["fixtures"]

    elements = bootstrap["elements"]
    teams = bootstrap["teams"]
    element_types = bootstrap["element_types"]
    events = bootstrap["events"]

    current_gw = 1
    current_gw_name = "Gameweek 1"
    for ev in events:
        if ev.get("is_next") or ev.get("is_current"):
            current_gw = ev["id"]
            current_gw_name = ev["name"]
            break

    most_transferred_in_player = max(elements, key=lambda p: p.get("transfers_in_event", 0)) if elements else None
    most_transferred_in_id = most_transferred_in_player["id"] if most_transferred_in_player else -1

    team_map = get_team_map(teams)
    processed_players = []

    for player in elements:
        if is_player_injured_or_unavailable(player):
            continue

        minutes = player.get("minutes", 0)
        if minutes < 90 and float(player.get("form", 0) or 0) < 1.0:
            continue

        pos_name = get_position_name(player["element_type"], element_types)

        if position_filter and position_filter.upper() != "ALL":
            if pos_name.upper() != position_filter.upper():
                continue

        price = float(player["now_cost"]) / 10.0

        if max_price is not None and price > max_price:
            continue

        team_info = team_map.get(player["team"], {})
        team_short = team_info.get("short_name", "UNK")
        team_name = team_info.get("name", "Unknown")

        upcoming_fx = get_upcoming_fixtures_for_team(
            player["team"], current_gw, fixtures, team_map, next_n=next_gameweeks
        )

        is_most_in = (player["id"] == most_transferred_in_id)

        next_round_xp, why_buy, set_piece_roles, is_dgw = calculate_next_round_expected_points(
            player, upcoming_fx, team_map, pos_name, is_most_transferred_in=is_most_in
        )

        processed_players.append({
            "id": player["id"],
            "web_name": player["web_name"],
            "first_name": player["first_name"],
            "second_name": player["second_name"],
            "position": pos_name,
            "team_short": team_short,
            "team_name": team_name,
            "price": price,
            "total_points": player["total_points"],
            "form": float(player.get("form") or 0.0),
            "points_per_game": float(player.get("points_per_game") or 0.0),
            "selected_by_percent": float(player.get("selected_by_percent") or 0.0),
            "transfers_in_event": player.get("transfers_in_event", 0),
            "is_most_transferred_in": is_most_in,
            "is_double_gameweek": is_dgw,
            "expected_points_next": float(player.get("ep_next") or 0.0),
            "projected_expected_points": next_round_xp,
            "is_penalty_taker": player.get("penalties_order") == 1,
            "is_freekick_taker": player.get("direct_freekicks_order") == 1,
            "is_corner_taker": player.get("corners_and_indirect_freekicks_order") == 1,
            "set_piece_roles": set_piece_roles,
            "chance_of_playing": player.get("chance_of_playing_next_round"),
            "news": player.get("news", ""),
            "best_buy_score": next_round_xp,
            "why_buy": why_buy,
            "upcoming_fixtures": upcoming_fx,
            "photo_url": f"https://resources.premierleague.com/premierleague/photos/players/110x140/p{player['code']}.png"
        })

    processed_players.sort(key=lambda p: (p["projected_expected_points"], p["form"], p["expected_points_next"]), reverse=True)

    return {
        "current_gameweek": current_gw,
        "gameweek_name": current_gw_name,
        "total_players_analyzed": len(processed_players),
        "most_transferred_in_player": most_transferred_in_player["web_name"] if most_transferred_in_player else None,
        "sort_by": sort_by,
        "results": processed_players[:limit]
    }


async def get_fpl_jokers(
    max_price: float = 6.5,
    max_ownership: float = 20.0,
    limit: int = 1,
    next_gameweeks: int = 3
) -> Dict[str, Any]:
    raw_data = await fetch_fpl_raw_data()
    bootstrap = raw_data["bootstrap"]
    fixtures = raw_data["fixtures"]

    elements = bootstrap["elements"]
    teams = bootstrap["teams"]
    element_types = bootstrap["element_types"]
    events = bootstrap["events"]

    current_gw = 1
    current_gw_name = "Gameweek 1"
    for ev in events:
        if ev.get("is_next") or ev.get("is_current"):
            current_gw = ev["id"]
            current_gw_name = ev["name"]
            break

    most_transferred_in_player = max(elements, key=lambda p: p.get("transfers_in_event", 0)) if elements else None
    most_transferred_in_id = most_transferred_in_player["id"] if most_transferred_in_player else -1

    team_map = get_team_map(teams)
    jokers = []

    for player in elements:
        if is_player_injured_or_unavailable(player):
            continue

        price = float(player["now_cost"]) / 10.0
        selected_pct = float(player.get("selected_by_percent") or 0.0)

        if price > max_price or selected_pct > max_ownership:
            continue

        form = float(player.get("form") or 0.0)
        ep_next = float(player.get("ep_next") or 0.0)

        minutes = player.get("minutes", 0)
        if minutes < 90 and form < 0.5 and ep_next < 1.0:
            continue

        pos_name = get_position_name(player["element_type"], element_types)
        team_info = team_map.get(player["team"], {})
        team_short = team_info.get("short_name", "UNK")
        team_name = team_info.get("name", "Unknown")

        upcoming_fx = get_upcoming_fixtures_for_team(
            player["team"], current_gw, fixtures, team_map, next_n=next_gameweeks
        )

        is_most_in = (player["id"] == most_transferred_in_id)

        next_round_xp, _, set_piece_roles, is_dgw = calculate_next_round_expected_points(
            player, upcoming_fx, team_map, pos_name, is_most_transferred_in=is_most_in
        )

        if next_round_xp <= 0:
            continue

        xp_per_million = round(next_round_xp / price, 2)

        joker_reason = (
            f"🃏 Joker Find: {next_round_xp} projected pts for only £{price:.1f}m "
            f"({xp_per_million} pts/£m) • Low ownership ({selected_pct:.1f}%)"
        )
        if is_dgw:
            joker_reason += " • ⚡ DOUBLE GAMEWEEK!"
        elif is_most_in:
            joker_reason += " • 🔥 Most Transferred In in FPL!"
        elif set_piece_roles:
            joker_reason += f" • {set_piece_roles[0]}"

        jokers.append({
            "id": player["id"],
            "web_name": player["web_name"],
            "first_name": player["first_name"],
            "second_name": player["second_name"],
            "position": pos_name,
            "team_short": team_short,
            "team_name": team_name,
            "price": price,
            "total_points": player["total_points"],
            "form": form,
            "points_per_game": float(player.get("points_per_game") or 0.0),
            "selected_by_percent": selected_pct,
            "transfers_in_event": player.get("transfers_in_event", 0),
            "is_most_transferred_in": is_most_in,
            "is_double_gameweek": is_dgw,
            "expected_points_next": ep_next,
            "projected_expected_points": next_round_xp,
            "is_penalty_taker": player.get("penalties_order") == 1,
            "is_freekick_taker": player.get("direct_freekicks_order") == 1,
            "is_corner_taker": player.get("corners_and_indirect_freekicks_order") == 1,
            "set_piece_roles": set_piece_roles,
            "xp_per_million": xp_per_million,
            "chance_of_playing": player.get("chance_of_playing_next_round"),
            "news": player.get("news", ""),
            "best_buy_score": next_round_xp,
            "why_buy": joker_reason,
            "upcoming_fixtures": upcoming_fx,
            "photo_url": f"https://resources.premierleague.com/premierleague/photos/players/110x140/p{player['code']}.png"
        })

    jokers.sort(key=lambda j: (j["xp_per_million"], j["projected_expected_points"]), reverse=True)

    return {
        "current_gameweek": current_gw,
        "gameweek_name": current_gw_name,
        "total_jokers_found": len(jokers),
        "results": jokers[:limit]
    }
