# M78 Accelerator x86_64

This directory contains the OpenWrt 25.12+ package wrapper for the M78 OpenWrt client.

The original package supplied to ChatGPT is a legacy IPK-style archive. The import script keeps only the x86_64 client and the LuCI/config/service files.

## Import the original package

From the repository root:

```bash
./scripts/import-m78-ipk.sh /path/to/78.ipk
```

Default behavior is intentionally slim:

- keep `netflow_x86_64`
- remove ARM/AArch64/MIPS binaries
- keep LuCI/controller/view, UCI config and procd init script
- omit the bundled GeoIP/GeoSite databases to avoid adding ~44 MiB of frequently-changing data to Git

If you explicitly want to vendor the GeoIP/GeoSite databases too:

```bash
./scripts/import-m78-ipk.sh /path/to/78.ipk --with-geodata
```

After import, review the generated files and commit them. The main build scripts automatically copy this package into `package/xiaotan/luci-app-m78accelerator`.

The package is only selected when `files/usr/bin/netflow_x86_64` exists, so the normal firmware build remains usable before the binary is imported.
