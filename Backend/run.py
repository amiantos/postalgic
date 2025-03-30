from source.main.app import flask_app
from dotenv import load_dotenv

if __name__ == "__main__":
    load_dotenv(dotenv_path="./.env")
    flask_app.run()