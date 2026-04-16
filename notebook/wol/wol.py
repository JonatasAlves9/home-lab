import os
from flask import Flask, jsonify
import subprocess

app = Flask(__name__)

DESKTOP_MAC = os.environ["DESKTOP_MAC"]
DESKTOP_IP = os.environ["DESKTOP_IP"]


@app.route("/wol/start")
def wol_start():
    subprocess.run(["wakeonlan", DESKTOP_MAC], check=True)
    return jsonify({"status": "sent"})


@app.route("/wol/status")
def wol_status():
    result = subprocess.run(
        ["ping", "-c", "1", "-W", "1", DESKTOP_IP],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return jsonify({"online": result.returncode == 0})


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
