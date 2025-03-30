
import unittest
from dotenv import load_dotenv
from source.main.config import create_app

class TestAuthRoutes(unittest.TestCase):
    def setUp(self) -> None:
        load_dotenv()
        self.client = create_app().test_client()

    def test_auth_global_endpoint(self):
        try:
            auth_endpoint_request = self.client.get('/api/auth/')
            self.assertDictEqual(auth_endpoint_request.json, {
                "message": "Welcome to your awesome auth endpoint", "success": True})
        except ValueError:
            raise SystemExit(ValueError)




if __name__ == '__main__':
    unittest.main()
