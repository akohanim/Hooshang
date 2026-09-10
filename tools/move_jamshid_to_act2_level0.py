#!/usr/bin/env python3
"""Move the existing Jamshid instance into Act_2_Level_0 without reformatting LDtk."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[1] / "ldtk/hooshang_act2.ldtk"
raw = p.read_text()
doc = json.loads(raw)

def span(text, start):
    i = text.index("[", start); depth = 0; quote = False; esc = False
    while i < len(text):
        c = text[i]
        if quote:
            if esc: esc = False
            elif c == "\\": esc = True
            elif c == '"': quote = False
        elif c == '"': quote = True
        elif c in "[{": depth += 1
        elif c in "]}":
            depth -= 1
            if depth == 0: return i
        i += 1
    raise ValueError("unbalanced array")

levels = doc["levels"]
source_level = next(level for level in levels if level["identifier"] == "Act_2_Level_1")
target_level = next(level for level in levels if level["identifier"] == "Act_2_Level_0")
entity = next(e for layer in source_level["layerInstances"] for e in layer.get("entityInstances", []) if e["__identifier"] == "Jamshid")
if any(e["__identifier"] == "Jamshid" for layer in target_level["layerInstances"] for e in layer.get("entityInstances", [])):
    print("Jamshid already in Act_2_Level_0")
    raise SystemExit

def entity_array(level):
    marker = '"identifier": "' + level["identifier"] + '"'
    at = raw.index(marker)
    at = raw.index('"__identifier": "Entities"', at)
    at = raw.index('"entityInstances":', at)
    return raw.index("[", at), span(raw, at)

src_open, src_close = entity_array(source_level)
target_open, target_close = entity_array(target_level)
needle = raw.index('{', src_open)
end = span(raw, needle)
obj = raw[needle:end+1]
raw = raw[:needle] + raw[end+1:]
# Removing the source object shifts the target only if it appeared later.
if target_open > end:
    target_open -= (end + 1 - needle)
    target_close -= (end + 1 - needle)
insert = raw.rfind(']', target_open, target_close + 1)
prefix = raw[:insert].rstrip()
if prefix.endswith('['):
    raw = prefix + '\n\t\t\t\t\t\t' + obj + raw[insert:]
else:
    raw = prefix + ',\n\t\t\t\t\t\t' + obj + raw[insert:]
p.write_text(raw)
print("Moved Jamshid from Act_2_Level_1 to Act_2_Level_0")
