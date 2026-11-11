"""icovr_shader_arrays.py SHADER_DIR: rewrites the ICO port's HLSL texture accesses into the ICO_VR macros
(common.hlsli): Texture2D<T> -> ICO_T2D(T); the uv of Sample/SampleLevel/SampleGrad/Gather* -> ICO_UV(uv);
Load(int3(c, lv)) -> Load(ICO_LD(c, lv)), Load(int3(x, y, lv)) -> Load(ICO_LDXY(x, y, lv)),
Load(p) of an int3 variable -> Load(ICO_LD3(p)); GetDimensions(w, h) -> ICO_DIMS(t, w, h) and
GetDimensions(lv, w, h, n) -> ICO_DIMS_LV(t, lv, w, h, n).  Texture2DMS loads (two bare arguments) and the
three-argument (multisampled) GetDimensions are left alone.  Idempotent: already-wrapped calls are skipped."""
import os, re, sys

SAMPLE = ("Sample", "SampleLevel", "SampleGrad", "SampleBias", "GatherRed", "GatherGreen", "GatherBlue",
          "GatherAlpha", "Gather")


def split_args(s):
    """top-level comma split of s (no outer parens)"""
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


def close_paren(s, i):
    """index of the paren closing s[i] == '('"""
    depth = 0
    for j in range(i, len(s)):
        if s[j] == "(":
            depth += 1
        elif s[j] == ")":
            depth -= 1
            if depth == 0:
                return j
    raise ValueError("unbalanced")


def convert(text):
    text = re.sub(r"\bTexture2D<(\w+)>", r"ICO_T2D(\1)", text)
    out, i = "", 0
    pat = re.compile(r"(\b[\w\.\]\)]+|\))\.(" + "|".join(SAMPLE) + r"|Load|GetDimensions)\(")
    while True:
        m = pat.search(text, i)
        if not m:
            out += text[i:]
            break
        obj, meth = m.group(1), m.group(2)
        start = m.end() - 1
        end = close_paren(text, start)
        args = split_args(text[start + 1:end])
        new = None
        if meth in SAMPLE and len(args) >= 2 and "ICO_UV" not in args[1]:
            args[1] = " ICO_UV(" + args[1].strip() + ")"
            new = ",".join(args)
        elif meth == "Load" and len(args) == 1 and "ICO_" not in args[0]:
            a = args[0].strip()
            mm = re.fullmatch(r"int3\((.*)\)", a, re.S)
            if mm:
                inner = split_args(mm.group(1))
                if len(inner) == 2:
                    new = "ICO_LD(" + ",".join(inner) + ")"
                elif len(inner) == 3:
                    new = "ICO_LDXY(" + ",".join(inner) + ")"
            elif re.fullmatch(r"\w+", a):
                new = "ICO_LD3(" + a + ")"
        elif meth == "GetDimensions" and "ICO_" not in obj:
            if len(args) == 2:
                out += text[i:m.start()] + "ICO_DIMS(" + obj + ", " + args[0].strip() + ", " + args[1].strip() + ")"
                i = end + 1
                continue
            if len(args) == 4:
                out += text[i:m.start()] + "ICO_DIMS_LV(" + obj + ", " + ", ".join(a.strip() for a in args) + ")"
                i = end + 1
                continue
        if new is None:
            out += text[i:end + 1]
        else:
            out += text[i:start + 1] + new + ")"
        i = end + 1
    return out


def main():
    d = sys.argv[1]
    for name in sorted(os.listdir(d)):
        if not name.endswith((".hlsl", ".hlsli")) or name == "reg.hlsli":
            continue
        p = os.path.join(d, name)
        with open(p, encoding="utf-8", newline="") as f:
            src = f.read()
        dst = convert(src)
        if dst != src:
            with open(p, "w", encoding="utf-8", newline="") as f:
                f.write(dst)
            print("converted", name)


if __name__ == "__main__":
    main()
