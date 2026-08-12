from app.models.manual_route import ManualRoute


def test_shared_manual_routes_list_and_share(client, auth_headers, db_session):
    # create a route
    create_response = client.post(
        "/api/map/manual-routes",
        headers=auth_headers,
        json={
            "name": "Community Loop",
            "points": [
                {"lat": 18.8059, "lng": 98.9523},
                {"lat": 18.8088, "lng": 98.9595},
            ],
        },
    )
    assert create_response.status_code == 201
    route_id = create_response.json()["id"]
    assert create_response.json()["is_shared"] is False

    # share the route to community
    share_response = client.put(
        f"/api/map/manual-routes/{route_id}/share?share=true",
        headers=auth_headers,
    )
    assert share_response.status_code == 200
    assert share_response.json()["is_shared"] is True
    assert share_response.json()["creator_full_name"] == "Jane Runner"

    # list shared community routes
    list_response = client.get("/api/map/manual-routes/shared")
    assert list_response.status_code == 200
    results = list_response.json()
    assert any(item["id"] == route_id for item in results)

    # search by name
    search_response = client.get("/api/map/manual-routes/shared?q=community")
    assert search_response.status_code == 200
    assert any(item["id"] == route_id for item in search_response.json())

    # unshare the route
    unshare_response = client.put(
        f"/api/map/manual-routes/{route_id}/share?share=false",
        headers=auth_headers,
    )
    assert unshare_response.status_code == 200
    assert unshare_response.json()["is_shared"] is False

    list_after_response = client.get("/api/map/manual-routes/shared")
    assert list_after_response.status_code == 200
    assert all(item["id"] != route_id for item in list_after_response.json())
