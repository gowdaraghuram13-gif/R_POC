"""
Flask web application for generating ETL mapping documents.
Upload a SQL stored procedure file and get an Excel mapping document back.

Usage:
    1. Create a .env file with Tachyon credentials (see .env.example)
    2. python app.py
    3. Open http://localhost:5000 in your browser.
"""

import json
import os
import tempfile

from dotenv import load_dotenv
from flask import Flask, render_template, request, send_file, jsonify

from generate_mapping_doc import call_tachyon, build_excel, read_file, DEFAULT_PROMPT_FILE

# Load .env file from the project root
load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16 MB max upload


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/generate", methods=["POST"])
def generate():
    # Check Tachyon credentials (loaded from .env file)
    missing = []
    if not os.environ.get("TACHYON_SESSION"):
        missing.append("TACHYON_SESSION")
    if not os.environ.get("TACHYON_USER_ID"):
        missing.append("TACHYON_USER_ID")
    if not os.environ.get("TACHYON_PRESET_ID"):
        missing.append("TACHYON_PRESET_ID")
    if missing:
        return jsonify({"error": f"Tachyon credentials not configured. Missing: {', '.join(missing)}. Please add them to your .env file and restart the server."}), 400

    # Check file upload
    if "sql_file" not in request.files:
        return jsonify({"error": "No SQL file uploaded."}), 400

    sql_file = request.files["sql_file"]
    if sql_file.filename == "":
        return jsonify({"error": "No file selected."}), 400

    if not sql_file.filename.lower().endswith(".sql"):
        return jsonify({"error": "Please upload a .sql file."}), 400

    # Read SQL content
    sql_content = sql_file.read().decode("utf-8")

    # Read prompt template
    prompt_path = request.form.get("prompt_path", "").strip()
    if not prompt_path:
        prompt_path = DEFAULT_PROMPT_FILE

    if not os.path.isfile(prompt_path):
        return jsonify({"error": f"Prompt template not found: {prompt_path}"}), 400

    prompt_template = read_file(prompt_path)

    try:
        # Call Tachyon LLM
        llm_response = call_tachyon(prompt_template, sql_content)

        # Build Excel in a temp file
        proc_name = os.path.splitext(sql_file.filename)[0]
        output_filename = f"MappingDocument_{proc_name}.xlsx"

        with tempfile.NamedTemporaryFile(suffix=".xlsx", delete=False) as tmp:
            tmp_path = tmp.name

        build_excel(llm_response, tmp_path)

        # Also save JSON response
        json_path = tmp_path.replace(".xlsx", "_llm_response.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(llm_response, f, indent=2, ensure_ascii=False)

        return send_file(
            tmp_path,
            as_attachment=True,
            download_name=output_filename,
            mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    required = ["TACHYON_SESSION", "TACHYON_USER_ID", "TACHYON_PRESET_ID"]
    missing = [k for k in required if not os.environ.get(k)]
    if missing:
        print(f"WARNING: Missing Tachyon credentials: {', '.join(missing)}")
        print("Create a .env file with the required values (see .env.example).")
    else:
        print("Tachyon credentials loaded successfully.")
    print("Starting Mapping Document Generator on http://localhost:5000")
    app.run(host="0.0.0.0", port=5000, debug=True)
