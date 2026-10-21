# ps5-opengl 0.3.0 recovery audit (2026-10-21)

## Verified inputs
- `tools/build-driver-chain.sh` requests `blackbearreloaded/ps5-opengl` release `v0.3.0` archive and requires SHA-256 `a7bd6b85f00398eaf8d87ecc58fa0bde7cab79e065acc783268070d2f14b403c`. Its URL returned HTTP 404 in GitHub Actions run 39532174603.
- `darkxex/ps5-opengl` publishes a v1.0.2 release and contains `docs/release-0.3.0.md`. Documentation of 0.3.0 does not establish availability of the exact release archive or compatibility of 1.0.2.
- `mihawk-99/PS5_Vulkan`, `tools/adapt-opengl-sdk.sh`, documents two accepted input shapes: release directory, or a checkout containing the version-specific toolchain and compiler files. It checks `dependencies.json`, `toolchain/opengnm-psbc-ps5.patch`, `toolchain/opengnm-psbc-host.mak`, `tools/agc_shader_package_writer.py`, and PS5 platform shim files.
- That project's `tooling/sdk/assemble-psbc-fork.sh` verifies both the source patch SHA-256 and the patched Git tree against the SDK manifest; a replacement must preserve these identities or be explicitly treated as a new unvalidated port.

## Technical blockers
1. Original 0.3.0 archive is not available at the pinned URL.
2. A 1.0.2 archive is not a drop-in replacement for the 0.3.0 archive and may change ABI, structures, compiler metadata and expected file layout.
3. Rebuilding PSBC alone does not reconstruct the full 0.3.0 release's assets or prove its RADV integration works.

## Safe acceptance gates for a replacement
1. Identify immutable source revision and verify the required checkout layout.
2. Validate `dependencies.json` pinned revisions, SHA-256 of the patch and the resulting Git tree before compiling.
3. Compare `libpsbc` headers, metadata schema, and SDK adaptation requirements before trying new source versions.
4. Compile PSBC and RADV on an isolated feature branch; never label this as a working PS5 game emulator until a console test confirms it.
5. Do not bypass the original digest by editing the expected hash to accept a different archive.

## References
- https://github.com/darkxex/ps5-opengl/blob/main/docs/release-0.3.0.md
- https://github.com/darkxex/ps5-opengl/blob/main/dependencies.json
- https://github.com/mihawk-99/PS5_Vulkan/blob/main/tools/adapt-opengl-sdk.sh
- https://github.com/mihawk-99/PS5_Vulkan/blob/main/tooling/sdk/assemble-psbc-fork.sh
- https://github.com/EdwardDanielSalazar/rpcs3-PS5/actions/runs/39532174603

No PS5 build or runtime compatibility is claimed by this audit.
