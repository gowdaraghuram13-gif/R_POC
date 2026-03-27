"""
Flask web application for generating ETL mapping documents.
Upload a SQL stored procedure file and get an Excel mapping document back.

Usage:
    export OPENAI_API_KEY="sk-..."
    python app.py

Then open http://localhost:5000 in your browser.
"""

import io
import json
import os
import tempfile
import uuid

from flask import Flask, render_template, request, send_file, jsonify

from generate_mapping_doc import call_openai, build_excel, read_file, DEFAULT_PROMPT_FILE

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16 MB max upload


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/generate", methods=["POST"])
def generate():
    # Check API key
    api_key = request.form.get("api_key", "").strip()
    if api_key:
        os.environ["OPENAI_API_KEY"] = api_key
    elif not os.environ.get("OPENAI_API_KEY"):
        return jsonify({"error": "OpenAI API key is required. Either provide it in the form or set the OPENAI_API_KEY environment variable."}), 400

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
        # Call OpenAI
        llm_response = call_openai(prompt_template, sql_content)

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
    print("Starting Mapping Document Generator on http://localhost:5000")
    print("Make sure OPENAI_API_KEY is set or provide it in the web form.")
    app.run(host="0.0.0.0", port=5000, debug=True)
