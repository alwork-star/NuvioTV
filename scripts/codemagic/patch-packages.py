#!/usr/bin/env python3
"""Patch resolved Swift package checkouts before the archive.

AetherEngine 7.71.x, Diagnostics/PerFrameBenchmark.swift: keyFramePacket(sliceBytes:) builds its NAL list
in one long inferred expression that Xcode 26.6 on Codemagic's M2 gives up on ("unable to type-check this
expression in reasonable time", build 6b087bcd). Same bytes, explicit types and smaller steps.
Usage: patch-packages.py <clonedSourcePackagesDirPath>
"""
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
target = root / "checkouts" / "AetherEngine" / "Sources" / "AetherEngine" / "Diagnostics" / "PerFrameBenchmark.swift"

OLD = """        let nals: [[UInt8]] = [[35 << 1, 1, 0x50], sei]
            + (0 ..< 4).map { i in [19 << 1, 1] + (0 ..< sliceBytes / 4).map { UInt8(0x11 &+ UInt8(truncatingIfNeeded: $0 &* 7 &+ i)) | 1 } }
        return nals.flatMap { nal in
            [UInt8(nal.count >> 24 & 0xFF), UInt8(nal.count >> 16 & 0xFF), UInt8(nal.count >> 8 & 0xFF),
             UInt8(nal.count & 0xFF)] + nal
        }"""

NEW = """        var nals: [[UInt8]] = [[35 << 1, 1, 0x50], sei]
        for i in 0 ..< 4 {
            var slice: [UInt8] = [19 << 1, 1]
            for j in 0 ..< sliceBytes / 4 {
                let mixed: Int = j &* 7 &+ i
                let low: UInt8 = UInt8(truncatingIfNeeded: mixed)
                slice.append(UInt8(0x11 &+ low) | 1)
            }
            nals.append(slice)
        }
        var out: [UInt8] = []
        for nal in nals {
            let n: Int = nal.count
            out.append(UInt8((n >> 24) & 0xFF))
            out.append(UInt8((n >> 16) & 0xFF))
            out.append(UInt8((n >> 8) & 0xFF))
            out.append(UInt8(n & 0xFF))
            out.append(contentsOf: nal)
        }
        return out"""

if not target.exists():
    print(f"patch-packages: {target} not found; nothing to patch")
    sys.exit(0)
src = target.read_text()
if NEW in src:
    print("patch-packages: AetherEngine already patched")
elif OLD in src:
    target.chmod(0o644)
    target.write_text(src.replace(OLD, NEW, 1))
    print("patch-packages: AetherEngine keyFramePacket patched")
else:
    print("patch-packages: WARNING AetherEngine keyFramePacket changed upstream; left as is", file=sys.stderr)
