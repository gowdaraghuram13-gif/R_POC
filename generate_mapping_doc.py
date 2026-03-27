"""
Generate a mapping document (Excel) for a SQL Server stored procedure
by calling the Tachyon LLM API.

Usage:
    1. Create a .env file with Tachyon credentials (see .env.example)
    2. python generate_mapping_doc.py <sql_file> [--prompt <prompt_file>] [--output <output_file>]

Requirements:
    pip install requests openpyxl python-dotenv
"""

import argparse
import json
import os
import sys

import requests
import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter


DEFAULT_PROMPT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "prompt_template.txt")
DEFAULT_OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs")
DEFAULT_TACHYON_URL = "https://tachyon-studio.institute.net/playground_document_llm"

HEADER_FONT = Font(name="Calibri", size=12, bold=True, color="FFFFFF")
HEADER_FILL = PatternFill(start_color="2F5496", end_color="2F5496", fill_type="solid")
LABEL_FONT = Font(name="Calibri", size=11, bold=True)
LABEL_FILL = PatternFill(start_color="D6E4F0", end_color="D6E4F0", fill_type="solid")
NORMAL_FONT = Font(name="Calibri", size=11)
TRANSFORM_FILL = PatternFill(start_color="FCE4D6", end_color="FCE4D6", fill_type="solid")
THIN_BORDER = Border(
    left=Side(style="thin"),
    right=Side(style="thin"),
    top=Side(style="thin"),
    bottom=Side(style="thin"),
)
WRAP_ALIGN = Alignment(wrap_text=True, vertical="top")
CENTER_ALIGN = Alignment(horizontal="center", vertical="center", wrap_text=True)


def style_header_row(ws, row, max_col):
    for col in range(1, max_col + 1):
        cell = ws.cell(row=row, column=col)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = CENTER_ALIGN
        cell.border = THIN_BORDER


def style_data_rows(ws, start_row, end_row, max_col):
    for r in range(start_row, end_row + 1):
        for c in range(1, max_col + 1):
            cell = ws.cell(row=r, column=c)
            cell.font = NORMAL_FONT
            cell.border = THIN_BORDER
            cell.alignment = WRAP_ALIGN


def auto_width(ws, max_col, min_width=12, max_width=50):
    for col in range(1, max_col + 1):
        max_len = min_width
        for row in ws.iter_rows(min_col=col, max_col=col, values_only=False):
            for cell in row:
                if cell.value:
                    max_len = max(max_len, min(len(str(cell.value)), max_width))
        ws.column_dimensions[get_column_letter(col)].width = max_len + 2


def _get_row_value(row_data, header):
    if not isinstance(row_data, dict):
        return None
    if header in row_data:
        return row_data[header]
    snake = (
        header.lower()
        .replace(" ", "_")
        .replace("/", "_")
        .replace("(", "")
        .replace(")", "")
        .replace(".", "")
    )
    if snake in row_data:
        return row_data[snake]
    lower = header.lower()
    for key in row_data:
        if key.lower() == lower:
            return row_data[key]
        if key.lower().replace(" ", "_") == snake:
            return row_data[key]
    for key in row_data:
        key_lower = key.lower().replace("_", " ")
        if key_lower in lower or lower in key_lower:
            return row_data[key]
    return None


def write_table_sheet(ws, headers, rows, highlight_col=None, highlight_value=None):
    num_cols = len(headers)
    for c, h in enumerate(headers, 1):
        ws.cell(row=1, column=c, value=h)
    style_header_row(ws, 1, num_cols)
    for r_idx, row_data in enumerate(rows, 2):
        for c_idx, header in enumerate(headers, 1):
            value = _get_row_value(row_data, header)
            ws.cell(row=r_idx, column=c_idx, value=str(value) if value is not None else "")
        if highlight_col and highlight_value:
            val = _get_row_value(row_data, highlight_col)
            if val and str(val).lower() == str(highlight_value).lower():
                for c in range(1, num_cols + 1):
                    ws.cell(row=r_idx, column=c).fill = TRANSFORM_FILL
    end_row = len(rows) + 1
    style_data_rows(ws, 2, end_row, num_cols)
    auto_width(ws, num_cols)


def read_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()


def call_tachyon(prompt, sql_content):
    """Call the Tachyon LLM API and return parsed JSON response."""
    session = os.environ.get("TACHYON_SESSION")
    user_id = os.environ.get("TACHYON_USER_ID")
    preset_id = os.environ.get("TACHYON_PRESET_ID")
    llm_url = os.environ.get("TACHYON_LLM_URL", DEFAULT_TACHYON_URL)

    if not session:
        print("ERROR: TACHYON_SESSION is not set in .env file.")
        sys.exit(1)
    if not user_id:
        print("ERROR: TACHYON_USER_ID is not set in .env file.")
        sys.exit(1)
    if not preset_id:
        print("ERROR: TACHYON_PRESET_ID is not set in .env file.")
        sys.exit(1)

    full_prompt = prompt.replace("{sql_content}", sql_content)
    system_message = "You are a data engineering expert. You respond only with valid JSON."

    print(f"Calling Tachyon LLM API: {llm_url}")
    print(f"Prompt length: {len(full_prompt)} characters")

    payload = {
        "user_id": user_id,
        "preset_id": preset_id,
        "prompt": full_prompt,
        "system_message": system_message,
    }

    cookies = {"higgs_session": session}
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    resp = requests.post(llm_url, json=payload, cookies=cookies, headers=headers, timeout=120)
    resp.raise_for_status()

    resp_data = resp.json()

    # Try to extract the LLM text from common response shapes
    raw_response = None
    if isinstance(resp_data, str):
        raw_response = resp_data
    elif isinstance(resp_data, dict):
        # Try common keys where the LLM text might be
        for key in ["response", "result", "text", "content", "output", "answer", "message", "data"]:
            if key in resp_data:
                val = resp_data[key]
                if isinstance(val, str):
                    raw_response = val
                    break
                elif isinstance(val, dict):
                    # The value itself might be the JSON we need
                    raw_response = json.dumps(val)
                    break
        if raw_response is None:
            # Maybe the entire response IS the mapping data
            raw_response = json.dumps(resp_data)

    print(f"Response received: {len(raw_response)} characters")

    try:
        data = json.loads(raw_response)
    except json.JSONDecodeError as e:
        print(f"ERROR: Failed to parse JSON response from LLM: {e}")
        print("Raw response (first 500 chars):")
        print(raw_response[:500])
        raise ValueError(f"Failed to parse JSON from Tachyon LLM response: {e}")
    return data


def build_excel(data, output_path):
    wb = openpyxl.Workbook()

    # TAB 1: Header
    ws_header = wb.active
    ws_header.title = "Header"
    header_info = data.get("header", {})
    header_fields = [
        ("Document Title", "document_title"),
        ("Project Name", "project_name"),
        ("Module", "module"),
        ("Stored Procedure", "stored_procedure"),
        ("Source System", "source_system"),
        ("Target System", "target_system"),
        ("Source Table", "source_table"),
        ("Target Table", "target_table"),
        ("Load Strategy", "load_strategy"),
        ("Author", "author"),
        ("Created Date", "created_date"),
        ("Version", "version"),
        ("Status", "status"),
        ("Description", "description"),
        ("Dependencies", "dependencies"),
        ("Execution Frequency", "execution_frequency"),
        ("Estimated Row Volume", "estimated_row_volume"),
        ("Error Handling", "error_handling"),
    ]
    ws_header.column_dimensions["A"].width = 25
    ws_header.column_dimensions["B"].width = 80
    for i, (label, key) in enumerate(header_fields, start=1):
        cell_a = ws_header.cell(row=i, column=1, value=label)
        cell_a.font = LABEL_FONT
        cell_a.fill = LABEL_FILL
        cell_a.border = THIN_BORDER
        cell_a.alignment = WRAP_ALIGN
        value = header_info.get(key, "")
        cell_b = ws_header.cell(row=i, column=2, value=str(value))
        cell_b.font = NORMAL_FONT
        cell_b.border = THIN_BORDER
        cell_b.alignment = WRAP_ALIGN

    # TAB 2: Data Set
    ws_ds = wb.create_sheet("Data Set")
    write_table_sheet(ws_ds,
        ["Data Set Name", "Database", "Schema", "Table/View", "Type", "Row Count (Est.)", "Description"],
        data.get("data_sets", []))

    # TAB 3: Source Data
    ws_src = wb.create_sheet("Source Data")
    write_table_sheet(ws_src,
        ["#", "Column Name", "Data Type", "Nullable", "Primary Key", "Description", "Sample Value"],
        data.get("source_data", []))

    # TAB 4: Target Data
    ws_tgt = wb.create_sheet("Target Data")
    write_table_sheet(ws_tgt,
        ["#", "Column Name", "Data Type", "Nullable", "Primary Key", "Unique", "Default", "Column Type", "Description", "Sample Value"],
        data.get("target_data", []),
        highlight_col="Column Type", highlight_value="Transformed")

    # TAB 5: Data Dictionary
    ws_dict = wb.create_sheet("Data Dictionary")
    write_table_sheet(ws_dict,
        ["#", "Column Name", "Business Name", "Data Type", "Length/Precision", "Nullable", "Domain / Valid Values", "Business Definition", "Source System", "Notes"],
        data.get("data_dictionary", []))

    # TAB 6: Mapping
    ws_map = wb.create_sheet("Mapping")
    write_table_sheet(ws_map,
        ["#", "Source Column", "Source Data Type", "Target Column", "Target Data Type", "Mapping Type", "Mapping Rule / Logic", "Join Key", "NULL Handling", "Notes"],
        data.get("mapping", []),
        highlight_col="Mapping Type", highlight_value="Transformation")

    # TAB 7: Health Checks
    ws_hc = wb.create_sheet("Health Checks")
    write_table_sheet(ws_hc,
        ["#", "Check Category", "Check Name", "Check Description", "SQL Query / Validation", "Expected Result", "Severity", "Frequency"],
        data.get("health_checks", []))

    # TAB 8: Transformation
    ws_tf = wb.create_sheet("Transformation")
    write_table_sheet(ws_tf,
        ["#", "Transformation Name", "Target Column", "Source Column(s)", "Transformation Type", "Business Rule", "SQL Logic", "NULL Handling", "Edge Cases", "Example Input", "Example Output"],
        data.get("transformations", []))

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    wb.save(output_path)
    print(f"Mapping document saved to: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate an ETL mapping document (Excel) from a SQL stored procedure using Tachyon LLM.",
    )
    parser.add_argument("sql_file", help="Path to the SQL stored procedure file to analyze.")
    parser.add_argument("--prompt", default=DEFAULT_PROMPT_FILE, help="Path to the prompt template file.")
    parser.add_argument("--output", default=None, help="Output Excel file path.")
    args = parser.parse_args()

    if not os.path.isfile(args.sql_file):
        print(f"ERROR: SQL file not found: {args.sql_file}")
        sys.exit(1)
    if not os.path.isfile(args.prompt):
        print(f"ERROR: Prompt template file not found: {args.prompt}")
        sys.exit(1)

    if args.output:
        output_path = args.output
    else:
        sql_basename = os.path.splitext(os.path.basename(args.sql_file))[0]
        output_path = os.path.join(DEFAULT_OUTPUT_DIR, f"MappingDocument_{sql_basename}.xlsx")

    print(f"Reading SQL file: {args.sql_file}")
    sql_content = read_file(args.sql_file)
    print(f"Reading prompt template: {args.prompt}")
    prompt_template = read_file(args.prompt)

    llm_response = call_tachyon(prompt_template, sql_content)

    json_output_path = output_path.replace(".xlsx", "_llm_response.json")
    with open(json_output_path, "w", encoding="utf-8") as f:
        json.dump(llm_response, f, indent=2, ensure_ascii=False)
    print(f"LLM JSON response saved to: {json_output_path}")

    build_excel(llm_response, output_path)
    print("Done!")


if __name__ == "__main__":
    main()
