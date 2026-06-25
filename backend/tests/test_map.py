def test_base_map_and_manual_route(client, auth_headers):
    base_response = client.get("/api/map/base")
    assert base_response.status_code == 200
    assert len(base_response.json()["nodes"]) >= 4
    assert len(base_response.json()["edges"]) >= 4

    create_route = client.post(
        "/api/map/manual-routes",
        headers=auth_headers,
        json={
            "name": "Manual Campus Loop",
            "points": [
                {"lat": 18.8059, "lng": 98.9523},
                {"lat": 18.8088, "lng": 98.9595},
                {"lat": 18.8018, "lng": 98.9630},
            ],
        },
    )
    assert create_route.status_code == 201
    route_id = create_route.json()["id"]
    assert create_route.json()["distance_km"] > 0

    delete_response = client.delete(
        f"/api/map/manual-routes/{route_id}",
        headers=auth_headers,
    )
    assert delete_response.status_code == 204

    list_response = client.get("/api/map/manual-routes", headers=auth_headers)
    assert list_response.status_code == 200
    assert all(item["id"] != route_id for item in list_response.json())

    marker_response = client.post(
        "/api/map/markers",
        headers=auth_headers,
        json={
            "marker_type": "construction",
            "severity": 3,
            "lat": 18.804,
            "lng": 98.955,
            "note": "Construction near crossing",
        },
    )
    assert marker_response.status_code == 201
    marker_id = marker_response.json()["id"]

    validate_response = client.post(
        f"/api/map/markers/{marker_id}/validate",
        headers=auth_headers,
        json={"confirmed": True},
    )
    assert validate_response.status_code == 200
    assert validate_response.json()["confirm_count"] >= 1
