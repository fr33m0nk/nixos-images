{
  lib,
  gcc13Stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  patchelf,
  libdrm,
}:
# Rockchip Media Process Platform (MPP) — tsukumijima's near-mainline fork.
# Userspace codec engine for the /dev/mpp_service kernel interface exposed by
# our out-of-tree rkvenc + rkvdec2 drivers.
#
# Hard-won build notes (each fixes a concrete failure on this toolchain):
#   * GCC 13         — sources predate GCC 14's stricter-C hard errors.
#   * CMAKE_POLICY_VERSION_MINIMUM=3.5 — CMake 4 dropped MPP's old minimum.
#   * cmakeBuildDir  — avoid colliding with MPP's in-source build/ dir.
#   * patchShebangs merge_static_lib.sh — it's run directly; #!/bin/bash ENOENT
#     in the sandbox otherwise ("no such file or directory").
#   * preFixup rpath — strip the /build tree path (forbidden in the output).
#   * .pc rewrite    — MPP joins ${prefix} with an absolute libdir → "//".
#   * libmpp_ext.so  — THIS FORK PUTS THE DECODERS IN libmpp_ext.so, not the
#     core lib (librockchip_mpp.so has only encoders). It must be installed,
#     and LOADED at runtime (e.g. LD_PRELOAD / LD_LIBRARY_PATH) for the decode
#     path to register its parsers.
gcc13Stdenv.mkDerivation (finalAttrs: {
  pname = "mpp-rockchip";
  version = "1.5.0-unstable-2026-01-21";

  src = fetchFromGitHub {
    owner = "tsukumijima";
    repo = "mpp-rockchip";
    rev = "v1.5.0-1-20260121-750e76e";
    # Get the real hash: nix hash path /nix/store/*-source  (or first-build mismatch)
    hash = "sha256-2Pdc7dWW9v+EIdgLV923GmSqwa11BUok3wLUYxR8flc=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    patchelf
  ];

  buildInputs = [
    libdrm
  ];

  postPatch = ''
    patchShebangs merge_static_lib.sh
  '';

  cmakeBuildDir = "nix-cmake-build";

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-DBUILD_TEST=ON"
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/pkgconfig $out/bin $out/include/rockchip

    # shared libs (preserve soname symlinks). libmpp_ext.so holds the DECODERS
    # in this fork — required for any decode path.
    find . \( -name 'librockchip_mpp.so*' -o -name 'librockchip_vpu.so*' -o -name 'libmpp_ext.so*' \) \
      -exec cp -Pv {} $out/lib/ \;

    for t in mpi_dec_test mpi_enc_test mpp_info_test; do
      f="$(find . -type f -executable -name "$t" | head -n1 || true)"
      [ -n "$f" ] && install -Dm755 "$f" "$out/bin/$t"
    done

    cp -rv "$src"/inc/* $out/include/rockchip/ 2>/dev/null || true
    find . -name '*.pc' -exec cp -v {} $out/lib/pkgconfig/ \; 2>/dev/null || true

    # fix the "//" in libdir/includedir that nixpkgs's pkg-config check rejects
    for pc in $out/lib/pkgconfig/*.pc; do
      [ -e "$pc" ] || continue
      sed -i \
        -e 's|^libdir=.*|libdir=''${prefix}/lib|' \
        -e 's|^includedir=.*|includedir=''${prefix}/include/rockchip|' \
        "$pc"
    done

    runHook postInstall
  '';

  # Strip the /build tree rpath from every ELF (tools + libs), keep store deps,
  # add $out/lib. Must be preFixup (before Nix's shrink/audit).
  preFixup = ''
    for f in $out/bin/* $(find $out/lib -type f -name '*.so*'); do
      new="$out/lib"
      for p in $(patchelf --print-rpath "$f" 2>/dev/null | tr ':' ' '); do
        case "$p" in
          /build/*) ;;
          "") ;;
          *) new="$new:$p" ;;
        esac
      done
      patchelf --set-rpath "$new" "$f" 2>/dev/null || true
    done

    # The DECODERS live in libmpp_ext.so, which nothing links by default — so
    # decode fails until it is loaded. Make the tools DT_NEEDED it (resolved via
    # their $out/lib rpath, which DT_NEEDED honors) so they auto-load it at
    # startup — no LD_PRELOAD required.
    ext="$(find $out/lib -type f -name 'libmpp_ext.so*' | head -1)"
    if [ -n "$ext" ]; then
      soname="$(patchelf --print-soname "$ext" 2>/dev/null || basename "$ext")"
      for t in $out/bin/*; do
        patchelf --add-needed "$soname" "$t" 2>/dev/null || true
      done
    fi
  '';

  meta = {
    description = "Rockchip Media Process Platform (MPP), near-mainline fork (tsukumijima)";
    homepage = "https://github.com/tsukumijima/mpp-rockchip";
    license = lib.licenses.asl20;
    platforms = [
      "aarch64-linux"
      "armv7l-linux"
    ];
  };
})
