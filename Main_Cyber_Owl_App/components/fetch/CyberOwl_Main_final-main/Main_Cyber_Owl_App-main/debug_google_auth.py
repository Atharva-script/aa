import traceback
from api_server_updated import app

client = app.test_client()
try:
    response = client.post('/api/google-auth', json={
        "email": "test_agent@example.com",
        "google_id": "agent_123",
        "name": "Agent Test",
        "photo_url": "http://example.com/photo.jpg",
        "secret_code": "1234",
        "is_register": True
    })
    print("STATUS:", response.status_code)
    print("DATA:", response.data.decode())
except Exception as e:
    traceback.print_exc()
