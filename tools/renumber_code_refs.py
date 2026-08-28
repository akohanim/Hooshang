"""Apply the same Level_6..Level_25 rotation (see renumber_levels_v2.py) to
literal identifier tokens in .gd source, restricted to a fixed file list.

Word-boundary regex means Level_1_Office / Level_2_ServerRooms (unrelated
legacy scenes) never match, since \\d+ stops at the first underscore and \\b
then fails between two word characters.

Run once. Do NOT rerun over files already hand-edited elsewhere -- that would
rotate an already-correct Level_14 into Level_15 a second time.
"""
import re

MAPPING = {"25": "6"}
for n in range(6, 25):
    MAPPING[str(n)] = str(n + 1)

PATTERN = re.compile(r"Level_(\d+)\b")

FILES = [
    "tests/music_test.gd",
    "tests/escape_test.gd",
    "tests/room_shot.gd",
    "tests/save_test.gd",
    "tests/route_order_test.gd",
    "tests/chase_route_test.gd",
    "tests/backtrack_test.gd",
    "tests/chase_entry_test.gd",
    "tests/chase_test.gd",
    "tests/intro_test.gd",
    "tests/world_bounds_test.gd",
]


def sub(m: re.Match) -> str:
    old = m.group(1)
    new = MAPPING.get(old)
    return f"Level_{new}" if new else m.group(0)


def main() -> None:
    for path in FILES:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
        new_text, count = PATTERN.subn(sub, text)
        if count:
            with open(path, "w", encoding="utf-8") as f:
                f.write(new_text)
        print(f"{path}: {count} replacement(s)")


if __name__ == "__main__":
    main()
