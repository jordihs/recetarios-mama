import io

from PIL import Image


def _png_bytes(color: str = "red", size: tuple[int, int] = (8, 6)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, format="PNG")
    return buf.getvalue()


def test_upload_and_fetch_image(client):
    data = _png_bytes()
    response = client.post("/images", files={"file": ("photo.png", data, "image/png")})
    assert response.status_code == 200
    body = response.json()
    assert body["ext"] == "png"
    assert body["width"] == 8 and body["height"] == 6
    assert len(body["hash"]) == 64

    fetched = client.get(f"/images/{body['hash']}")
    assert fetched.status_code == 200
    assert fetched.headers["content-type"] == "image/png"
    assert fetched.content == data


def test_upload_dedupes_by_content(client):
    data = _png_bytes("blue")
    first = client.post("/images", files={"file": ("a.png", data, "image/png")}).json()
    second = client.post("/images", files={"file": ("b.png", data, "image/png")}).json()
    assert first["hash"] == second["hash"]


def test_upload_rejects_non_image(client):
    response = client.post("/images", files={"file": ("nota.txt", b"hello", "text/plain")})
    assert response.status_code == 400
    body = response.json()
    assert body["error"]["code"] == "invalid_image_data"
    assert body["error"]["message"]  # Spanish message present


def test_missing_image_404(client):
    response = client.get("/images/" + "0" * 64)
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "image_not_found"


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
