import json
import re
import os

log_file = "/home/dineth_thenuwara/.gemini/antigravity-ide/brain/b6a3b4d3-758f-474e-a1a8-1ad1a0eb2142/.system_generated/logs/transcript_full.jsonl"
app_tsx_path = "/home/dineth_thenuwara/gsmb-admin-dashboard_Temp/src/App.tsx"

lines = {}

def parse_content(content):
    for line in content.splitlines():
        parts = line.split(":", 1)
        if len(parts) == 2 and parts[0].strip().isdigit():
            num = int(parts[0].strip())
            val = parts[1]
            if val.startswith(" "):
                val = val[1:]
            lines[num] = val

# Read current App.tsx lines 1 to 1161 to preserve them exactly
with open(app_tsx_path, "r", encoding="utf-8") as f:
    current_lines = f.read().splitlines()

# We only fill in the rest of the lines from the log
with open(log_file, "r", encoding="utf-8") as f:
    for line in f:
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
            content = obj.get("content", "")
            if not content:
                continue
            if "File Path:" in content and "App.tsx" in content:
                parse_content(content)
        except Exception as e:
            pass

# Merge the current lines 1 to 1161
for idx, line_val in enumerate(current_lines[:1161]):
    lines[idx + 1] = line_val

# Apply the 5 className syntax error fixes
fixes = [1194, 1673, 1715, 1724, 1736]
for line_num in fixes:
    if line_num in lines:
        lines[line_num] = lines[line_num].replace("${theme} === 'light'", "theme === 'light'")

# Let's write the reconstructed lines back to App.tsx
max_line = max(lines.keys())
print(f"Max line found: {max_line}")

output_lines = []
for i in range(1, max_line + 1):
    output_lines.append(lines.get(i, ""))

# Write output to App.tsx
with open(app_tsx_path, "w", encoding="utf-8") as f:
    f.write("\n".join(output_lines) + "\n")

print("Successfully restored App.tsx!")
