"""Make the cat artwork's white background transparent.

The source PNGs are opaque with a near-white backdrop, which renders as a visible
square against the cream cards. Flood-filling from the BORDER (rather than
keying out white globally) is what preserves the cats' own white fur — a tuxedo's
chest is pure white too, but it is not connected to the frame edge.

Idempotent: already-transparent files are skipped. Originals live in the Napcat
git repo if this ever needs redoing.

Usage: python3 tools/cutout_cats.py [--check]
"""
import sys
from collections import deque
from pathlib import Path
from PIL import Image

CATS = Path(__file__).resolve().parent.parent / "assets" / "cats"
TOLERANCE = 28          # per-channel distance from the sampled corner colour
MIN_BG_FRACTION = 0.05  # sanity floor: a real cutout removes at least this much
MAX_BG_FRACTION = 0.85  # sanity ceiling: more than this means we ate the cat


def cutout(path: Path) -> tuple[bool, str]:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()

    if min(px[x, y][3] for x in range(0, w, 8) for y in range(0, h, 8)) == 0:
        return False, "already transparent"

    seed = px[0, 0][:3]

    def is_bg(p):
        return all(abs(p[i] - seed[i]) <= TOLERANCE for i in range(3))

    # BFS inward from every border pixel. Only background reachable from the
    # frame edge is removed.
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(px[x, y]) and not seen[y * w + x]:
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(px[x, y]) and not seen[y * w + x]:
                seen[y * w + x] = 1
                q.append((x, y))

    removed = 0
    while q:
        x, y = q.popleft()
        px[x, y] = (255, 255, 255, 0)
        removed += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and is_bg(px[nx, ny]):
                seen[ny * w + nx] = 1
                q.append((nx, ny))

    frac = removed / (w * h)
    if not (MIN_BG_FRACTION <= frac <= MAX_BG_FRACTION):
        return False, f"REFUSED, would remove {frac:.0%} (outside sane bounds)"

    im.save(path)
    return True, f"removed {frac:.0%}"


def main() -> int:
    check_only = "--check" in sys.argv
    files = sorted(CATS.glob("*.png"))
    if not files:
        print("no cat assets found", file=sys.stderr)
        return 1
    failures = 0
    for f in files:
        if check_only:
            has_alpha = Image.open(f).convert("RGBA").getchannel("A").getextrema()[0] == 0
            print(f"{f.name:24} {'transparent' if has_alpha else 'OPAQUE'}")
            failures += 0 if has_alpha else 1
        else:
            ok, msg = cutout(f)
            print(f"{f.name:24} {msg}")
            failures += 0 if ok or msg == "already transparent" else 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
