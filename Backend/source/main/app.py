from flask import Flask
from source.main.config import create_app

flask_app = create_app()


@flask_app.route("/")
def home_route():
    return "Hello World !"
