def test_start_and_finish_run(client, auth_headers):
    start_response = client.post(
        "/api/runs/start",
        headers=auth_headers,
        json={"notes": "Easy evening run"},
    )
    assert start_response.status_code == 201
    run_id = start_response.json()["id"]
    assert start_response.json()["status"] == "active"
    assert start_response.json()["started_at"] is not None

    get_response = client.get(f"/api/runs/{run_id}", headers=auth_headers)
    assert get_response.status_code == 200
    assert get_response.json()["id"] == run_id

    finish_response = client.post(
        f"/api/runs/{run_id}/finish",
        headers=auth_headers,
        json={"distance_km": 5.25, "duration_seconds": 1800},
    )
    assert finish_response.status_code == 200
    assert finish_response.json()["status"] == "finished"
    assert finish_response.json()["finished_at"] is not None

    finish_again = client.post(
        f"/api/runs/{run_id}/finish",
        headers=auth_headers,
        json={"distance_km": 5.25, "duration_seconds": 1800},
    )
    assert finish_again.status_code == 400

    list_response = client.get("/api/runs", headers=auth_headers)
    assert list_response.status_code == 200
    assert len(list_response.json()) == 1


def test_run_points_are_saved_and_used_for_finish_stats(client, auth_headers):
    start_response = client.post(
        "/api/runs/start",
        headers=auth_headers,
        json={"notes": "GPS run"},
    )
    assert start_response.status_code == 201
    run_id = start_response.json()["id"]

    points_response = client.post(
        f"/api/runs/{run_id}/points",
        headers=auth_headers,
        json=[
            {
                "lat": 18.8059,
                "lng": 98.9523,
                "accuracy_m": 8,
                "recorded_at": "2026-06-15T10:00:00Z",
            },
            {
                "lat": 18.8069,
                "lng": 98.9533,
                "accuracy_m": 8,
                "recorded_at": "2026-06-15T10:01:00Z",
            },
        ],
    )
    assert points_response.status_code == 201
    assert len(points_response.json()) == 2

    finish_response = client.post(
        f"/api/runs/{run_id}/finish",
        headers=auth_headers,
        json={},
    )
    assert finish_response.status_code == 200
    assert finish_response.json()["status"] == "finished"
    assert finish_response.json()["distance_km"] > 0
    assert finish_response.json()["duration_seconds"] == 60
