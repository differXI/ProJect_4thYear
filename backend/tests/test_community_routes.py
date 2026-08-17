from app.models.manual_route import ManualRoute


def test_favorite_manual_route_toggle_and_list(client, auth_headers, db_session):
    create_response = client.post(
        "/api/map/manual-routes",
        headers=auth_headers,
        json={
            "name": "Favorite Loop",
            "points": [
                {"lat": 18.8059, "lng": 98.9523},
                {"lat": 18.8088, "lng": 98.9595},
            ],
        },
    )
    assert create_response.status_code == 201
    route_id = create_response.json()["id"]
    assert create_response.json()["is_favorited"] is False

    # favorite the route
    favorite_response = client.put(
        f"/api/map/manual-routes/{route_id}/favorite?favorite=true",
        headers=auth_headers,
    )
    assert favorite_response.status_code == 200
    assert favorite_response.json()["is_favorited"] is True

    # it should now show up in the favorites list
    list_response = client.get("/api/map/manual-routes/favorites", headers=auth_headers)
    assert list_response.status_code == 200
    favorites = list_response.json()
    assert len(favorites) == 1
    assert favorites[0]["id"] == route_id
    assert favorites[0]["is_favorited"] is True

    # favoriting again should not create a duplicate entry
    client.put(f"/api/map/manual-routes/{route_id}/favorite?favorite=true", headers=auth_headers)
    list_response_again = client.get("/api/map/manual-routes/favorites", headers=auth_headers)
    assert len(list_response_again.json()) == 1

    # unfavorite the route
    unfavorite_response = client.put(
        f"/api/map/manual-routes/{route_id}/favorite?favorite=false",
        headers=auth_headers,
    )
    assert unfavorite_response.status_code == 200
    assert unfavorite_response.json()["is_favorited"] is False

    empty_list_response = client.get("/api/map/manual-routes/favorites", headers=auth_headers)
    assert empty_list_response.json() == []


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
