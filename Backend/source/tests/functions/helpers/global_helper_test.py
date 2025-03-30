from source.main.helpers import super_complex_function
import unittest


class TestAuthRoutes(unittest.TestCase):
    def test_super_complex_function(self):
        self.assertEqual(super_complex_function("World !"), "Hello World !")


if __name__ == '__main__':
    unittest.main()
