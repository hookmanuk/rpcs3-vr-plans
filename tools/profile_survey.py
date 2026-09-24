#!/usr/bin/env python3
"""
First-pass VR profile survey of a one-frame RSX Stereo Inspector capture.

Answers the questions a new profile needs, from a flat (2D) capture:
  - render passes and which targets have the output aspect (camera views)
  - candidate camera blocks, in both matrix layouts, ranked by coverage
  - per-program coverage by the chosen blocks, and the programs on
    output-aspect targets that no block covers (head-locked in VR)
  - the camera position slot (a constant equal to the matrix's eye point)
  - the HUD / screen-space block (orthographic pixel matrix)

Usage:
    profile_survey.py <capture.jsonl> [--blocks 26,39] [--layout rows|columns]

Without --blocks/--layout, the best-covering layout and blocks are chosen.
Needs numpy. See plans/5-vr-profile-playbook.md.
"""

import argparse
import collections
import json

import numpy as np


def load(path):
    header, shaders, draws = None, {}, []
    for line in open(path, encoding="utf-8"):
        r = json.loads(line)
        if r["type"] == "header":
            header = r
        elif r["type"] == "shader":
            shaders[r["vp_storage_hash"]] = r
        elif r["type"] == "draw":
            draws.append(r)
    return header, shaders, draws


def consts(d):
    return {c["c"]: np.array(c["f"], dtype=np.float64) for c in d["constants"]}


def block(c, base, layout):
    """The block as DP4 rows (clip[i] = row_i . (v,1)), or None.
    columns: slot i is row i; z may be absent (z = w, a far-plane sky).
    rows: slot k is row k of M in clip = v * M, i.e. the transpose."""
    if layout == "columns":
        if not all(base + k in c for k in (0, 1, 3)):
            return None, False
        z_missing = base + 2 not in c
        z = c[base + 3] if z_missing else c[base + 2]
        return np.array([c[base], c[base + 1], z, c[base + 3]]), z_missing
    if not all(base + k in c for k in range(4)):
        return None, False
    return np.array([c[base + k] for k in range(4)]).T, False


def is_perspective(m):
    return not np.allclose(m[3], [0, 0, 0, 1], atol=1e-6)


def rigidity(m):
    x, y, w = m[0, :3], m[1, :3], m[3, :3]
    nx, ny, nw = np.linalg.norm(x), np.linalg.norm(y), np.linalg.norm(w)
    if min(nx, ny, nw) < 1e-8:
        return 9.0
    return max(abs(x @ y) / (nx * ny), abs(x @ w) / (nx * nw), abs(y @ w) / (ny * nw))


def eye_point(m):
    try:
        return np.linalg.solve(m[[0, 1, 3], :3], -m[[0, 1, 3], 3])
    except np.linalg.LinAlgError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("capture")
    ap.add_argument("--blocks", help="comma-separated camera block bases, in priority order")
    ap.add_argument("--layout", choices=["rows", "columns"])
    ap.add_argument("--rigid", type=float, default=0.1, help="rigidity tolerance (require_rigid_camera)")
    args = ap.parse_args()

    header, shaders, draws = load(args.capture)
    av = header["avconf"]
    out_w, out_h = av["eye_width"], av["eye_height"]
    out_aspect = out_w / out_h
    print(f"{header['title_id']} {header.get('app_version', '')}: {len(draws)} draws, output {out_w}x{out_h}")

    def output_aspect(d):
        w, h = d["rt"]["width"], d["rt"]["height"]
        return h and abs((w / h) / out_aspect - 1) <= 0.02

    # 1. Passes
    print("\n== Render passes (consecutive draws on one target set)")
    runs = []
    for d in draws:
        rt = d["rt"]
        color = rt["color_addresses"][0] if any(rt["color_write_enabled"]) else None
        key = (rt["width"], rt["height"], color, rt["zeta_address"])
        if runs and runs[-1][0] == key:
            runs[-1][2] = d["draw"]
            runs[-1][3] += 1
        else:
            runs.append([key, d["draw"], d["draw"], 1])
    for (w, h, color, z), a, b, n in runs:
        tag = "  <- output aspect" if h and abs((w / h) / out_aspect - 1) <= 0.02 else ""
        print(f"  draws {a:5}-{b:5} n={n:4}  {w}x{h} color={hex(color) if color else '-'} z={hex(z) if z else '-'}{tag}")

    view_draws = [d for d in draws if output_aspect(d)]

    # 2. Candidate camera blocks (perspective + rigid on output-aspect targets)
    print("\n== Candidate camera blocks on output-aspect targets (perspective and rigid)")
    # Programs with indexed constants upload the whole bank, so every slot looks
    # "read" there; they are covered by whatever the other programs establish.
    cand = collections.Counter()
    for d in view_draws:
        if shaders.get(d["vp_storage_hash"], {}).get("has_indexed_constants"):
            continue
        c = consts(d)
        for layout in ("rows", "columns"):
            for base in sorted(c):
                m, _ = block(c, base, layout)
                if m is not None and is_perspective(m) and rigidity(m) <= args.rigid:
                    cand[(layout, base)] += 1
    for (layout, base), n in cand.most_common(12):
        print(f"  {layout:8} c[{base}]  {n} draws")
    if not cand:
        print("  none - the camera may be split across programs differently; inspect by hand")
        return

    layout = args.layout or cand.most_common(1)[0][0][0]
    if args.blocks:
        blocks = [int(b) for b in args.blocks.split(",")]
    else:
        blocks = [b for (lay, b), n in cand.most_common() if lay == layout and n >= 2][:4]
    print(f"\n  using layout={layout} blocks={blocks}")

    # 3. Coverage per program
    print("\n== Programs on output-aspect targets")
    progs = collections.OrderedDict()
    eye_points, projections = [], []
    for d in view_draws:
        c = consts(d)
        chosen = None
        for base in blocks:
            m, z_missing = block(c, base, layout)
            if m is not None and is_perspective(m) and rigidity(m) <= args.rigid:
                chosen = (base, m, z_missing)
                break
        key = (d["vp_storage_hash"][:8], chosen[0] if chosen else None)
        p = progs.setdefault(key, {"draws": [], "verts": 0, "z_missing": False, "reads": sorted(c)[:14],
                                   "fp": d.get("fp_session_id"), "vp": d.get("vp_session_id")})
        p["draws"].append(d["draw"])
        p["verts"] += d["vertex_draw_count"]
        if chosen:
            base, m, z_missing = chosen
            p["z_missing"] |= z_missing
            nw = np.linalg.norm(m[3, :3])
            projections.append((round(np.linalg.norm(m[0, :3]) / nw, 3), round(np.linalg.norm(m[1, :3]) / nw, 3)))
            e = eye_point(m)  # object space; equals world space where no object matrix is folded in
            if e is not None:
                eye_points.append((d["draw"], e, c))
    covered = [(k, p) for k, p in progs.items() if k[1] is not None]
    uncovered = [(k, p) for k, p in progs.items() if k[1] is None]
    for (vp, base), p in covered:
        note = "  (no z slot: z = w)" if p["z_missing"] else ""
        print(f"  covered   {vp} c[{base}]  draws={len(p['draws'])} first={p['draws'][0]} verts={p['verts']}{note}")
    print("  -- not covered (drawn with the game's own camera in VR: head-locked unless screen space) --")
    for (vp, _), p in uncovered:
        print(f"  UNCOVERED {vp} vp#{p['vp']} fp#{p['fp']} draws={len(p['draws'])} first={p['draws'][0]} "
              f"verts={p['verts']} reads={p['reads']}")
    print("\n  projection (A=|x|/|w|, B=|y|/|w|):", collections.Counter(projections).most_common(4))

    # 4. Camera position slot: a w=1 constant equal to the eye point
    print("\n== Camera position slot (constant equal to the solved eye point)")
    hits = collections.Counter()
    for _, e, c in eye_points:
        for slot, v in c.items():
            if abs(v[3] - 1) < 1e-4 and np.linalg.norm(v[:3] - e) < 0.05 * max(1.0, np.linalg.norm(e)):
                hits[slot] += 1
    for slot, n in hits.most_common(4):
        print(f"  c[{slot}]  matches on {n} draws")
    if not hits:
        print("  none found (the game may not upload one; camera_position.slot is optional)")

    # 5. Screen-space block: orthographic, pixel-scaled, on output-aspect targets
    print("\n== Orthographic blocks on output-aspect targets (HUD candidates)")
    ortho = collections.Counter()
    for d in view_draws:
        c = consts(d)
        for base in sorted(c):
            m, z_missing = block(c, base, layout)
            if m is None or z_missing or is_perspective(m):
                continue
            sx, sy = abs(m[0, 0]), abs(m[1, 1])
            if 0 < sx < 0.01 and 0 < sy < 0.01:  # clip units per pixel: HUD in pixel coordinates
                ortho[base] += 1
    for base, n in ortho.most_common(3):
        print(f"  c[{base}]  {n} draws")


if __name__ == "__main__":
    main()
