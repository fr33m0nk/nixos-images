{
  lib,
  gcc13Stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  patchelf,
  libdrm,
}:
# Rockchip Media Process Platform (MPP) — tsukumijima's near-mainline fork of
# HermanChen/mpp. Userspace codec engine that talks to the /dev/mpp_service
# kernel interface exposed by our out-of-tree rkvenc + rkvdec2 drivers.
# ffmpeg-rockchip links against the shared lib; mpi_dec_test / mpp_info are
# used to bring up and test the decoder.
#
# Pinned to GCC 13 (sources predate GCC 14's stricter-C errors).
#
# NOTE: MPP's static-lib assembly runs a helper (merge_static_lib.sh) invoked
# directly, so its #!/bin/bash shebang is used — and /bin/bash doesn't exist in
# the Nix sandbox ("no such file or directory"). patchShebangs fixes it so the
# full build (shared + static + tools) completes. A full build matters: the
# shared lib force-links the codec archives (--whole-archive), which is what
# registers the self-registering decoder parsers (h264, etc.).
gcc13Stdenv.mkDerivation (finalAttrs: {
  pname = "mpp-rockchip";
  version = "1.5.0-unstable-2026-01-21";

  src = fetchFromGitHub {
    owner = "tsukumijima";
    repo = "mpp-rockchip";
    rev = "v1.5.0-1-20260121-750e76e";
    # First build prints the real hash; paste it here.
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    patchelf
  ];

  buildInputs = [
    libdrm
  ];

  # merge_static_lib.sh is run directly; fix its /bin/bash shebang for the sandbox.
  postPatch = ''
    patchShebangs merge_static_lib.sh
  '';

  # MPP ships its own in-source `build/` dir; avoid colliding with it.
  cmakeBuildDir = "nix-cmake-build";

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    # CMake 4 dropped compatibility with MPP's ancient cmake_minimum_required.
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-DBUILD_TEST=ON"
    # print the exact commands (so the failing static-lib merge is visible)
    "-DCMAKE_VERBOSE_MAKEFILE=ON"
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error";

  # --whole-archive linking (required for codec parser registration)
  # only runs during the install target.  The static lib build is broken
  # in this repo, so we nuke the .a files after install.
  installPhase = ''
    runHook preInstall
    cmake --install nix-cmake-build --prefix $out
    rm -f $out/lib/*.a $out/lib/*.la
    runHook postInstall
  '';

  # The tools were linked against the shared lib in the build tree, so their
  # RPATH contains a /build/... entry (forbidden in the output, and dangling
  # anyway). Rewrite RPATH to $out/lib plus the original store-path entries,
  # dropping /build. Must run in preFixup, before Nix's shrink/audit step.
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
