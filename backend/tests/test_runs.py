def test_start_and_finish_run(client, auth_headers):
    start_response = client.post(
        "/api/runs/start",
        headers=auth_headers,
        json={"notes": "Easy evening run"},
    )
    assert start_response.status_code == 201
    run_id = start_response.json()["id"]
    assert start_response.json()["status"] == "active"

    finish_response = client.post(
        f"/api/runs/{run_id}/finish",
        headers=auth_headers,
        json={"distance_km": 5.25, "duration_seconds": 1800, "step_count": 5400},
    )
    assert finish_response.status_code == 200
    body = finish_response.json()
    assert body["status"] == "finished"
    assert body["ai_insight"]
    assert body["ai_reasoning"]
    assert body["ai_recommendations"]
    assert body["avg_pace_min_per_km"] > 0

    list_response = client.get("/api/runs", headers=auth_headers)
    assert list_response.status_code == 200
    assert len(list_response.json()) == 1
