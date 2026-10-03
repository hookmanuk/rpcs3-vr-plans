#!/usr/bin/env python3
"""Checks that two versions of RPCS3 GLSL snippets preprocess to the same shader text.

Used for 10-multiview-merge-audit.md: moving the fork's _VR_MULTIVIEW macros from #if/#elif around
upstream's lines to #undef/#define overrides after them must not change any shader. Each snippet is
taken from its R"( ... )" literal (both versions concatenated in the order given, as GLSLCommon.cpp
emits them), every combination of the defines below is preprocessed with the C preprocessor (cpp -P),
and every macro defined in either version is expanded with placeholder arguments. Function and other
code lines are compared as a sorted multiset (an override block may sit elsewhere in the file).

usage: glsl_equiv.py [-C rpcs3-checkout] OLD_REF NEW_REF snippet.glsl...   (NEW_REF may be WORKTREE)
example: tools/merge/glsl_equiv.py -C ../rpcs3 multiview HEAD \\
  rpcs3/Emu/RSX/Program/GLSLSnippets/RSXProg/RSXFragmentTextureOps.glsl \\
  rpcs3/Emu/RSX/Program/GLSLSnippets/RSXProg/RSXFragmentTextureDepthConversion.glsl
"""
import itertools
import os
import re
import subprocess
import sys

DEFINES = ['_VR_MULTIVIEW', '_ENABLE_TEX1D', '_ENABLE_TEX2D', '_ENABLE_TEX3D', '_ENABLE_SHADOW', '_EMULATED_TEXSHADOW',
           '_ENABLE_SHADOWPROJ', '_ENABLE_FORMAT_CONVERSION', '_ENABLE_TEXTURE_ALPHA_KILL', '_VR_REPROJECT']


def snippet(ref, path):
    if ref == 'WORKTREE':
        text = open(path, encoding='utf-8').read()
    else:
        text = subprocess.run(['git', 'show', f'{ref}:{path}'], capture_output=True, check=True).stdout.decode('utf-8')
    text = text.replace('\r\n', '\n')
    return text[text.index('R"(') + 3:text.rstrip().rfind(')"')]


def main():
    args = sys.argv[1:]
    if args[:1] == ['-C']:
        os.chdir(args[1])
        args = args[2:]
    old_ref, new_ref, paths = args[0], args[1], args[2:]
    sources = [''.join(snippet(ref, p) + '\n' for p in paths) for ref in (old_ref, new_ref)]
    names = sorted(set(re.findall(r'#\s*define\s+(\w+)', sources[0] + sources[1])))
    uses = []
    for name in names:
        m = re.search(r'#\s*define\s+' + name + r'\(([^)]*)\)', sources[0] + sources[1])
        call = f"{name}({', '.join(f'A{i}' for i in range(len(m.group(1).split(','))))})" if m else name
        uses.append(f'USE_{name}: {call}')
    mismatches = 0
    for combo in itertools.product([False, True], repeat=len(DEFINES)):
        defs = ''.join(f'#define {d}\n' for d, on in zip(DEFINES, combo) if on)
        results = []
        for src in sources:
            r = subprocess.run(['cpp', '-P', '-x', 'c', '-'], input=(defs + src + '\n' + '\n'.join(uses) + '\n').encode(),
                               capture_output=True, check=True)
            lines = [l.strip() for l in r.stdout.decode().split('\n') if l.strip()]
            results.append(([l for l in lines if l.startswith('USE_')], sorted(l for l in lines if not l.startswith('USE_'))))
        if results[0] != results[1]:
            mismatches += 1
            if mismatches <= 3:
                print('mismatch with', [d for d, on in zip(DEFINES, combo) if on] or 'no defines')
                for a, b in zip(results[0][0], results[1][0]):
                    if a != b:
                        print('  old:', a)
                        print('  new:', b)
                if results[0][1] != results[1][1]:
                    print('  code lines differ')
    print(f'{2 ** len(DEFINES)} define combinations, {len(uses)} macros: {mismatches} mismatches')
    sys.exit(1 if mismatches else 0)


if __name__ == '__main__':
    main()
