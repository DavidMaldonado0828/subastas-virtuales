from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.main import add_cors_middleware


def test_cors_allows_frontend_origin_methods_and_headers_without_credentials():
    app = FastAPI()
    add_cors_middleware(app, "http://localhost:4200")
    app.get("/resource")(lambda: {"ok": True})

    with TestClient(app) as client:
        response = client.options(
            "/resource",
            headers={
                "Origin": "http://localhost:4200",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "authorization,content-type",
            },
        )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:4200"
    assert "access-control-allow-credentials" not in response.headers
    allowed_methods = set(response.headers["access-control-allow-methods"].split(", "))
    assert allowed_methods == {"GET", "POST", "PATCH", "DELETE", "OPTIONS"}
    assert "authorization" in response.headers["access-control-allow-headers"].lower()
    assert "content-type" in response.headers["access-control-allow-headers"].lower()


def test_cors_rejects_origin_outside_environment_allowlist():
    app = FastAPI()
    add_cors_middleware(app, "http://localhost:4200")

    with TestClient(app) as client:
        response = client.options(
            "/resource",
            headers={"Origin": "http://evil.example", "Access-Control-Request-Method": "GET"},
        )

    assert response.status_code == 400
