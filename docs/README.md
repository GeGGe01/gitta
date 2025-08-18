# deb-builder
Skeleton for single binary (.deb)

## Principer
> [!TIP]
> One binary: bygg en enda körbar artefakt per målplattform. Paketeringen (deb) innehåller bara binären + metadata (manpage, systemd, config exempel).
> Reproducerbar build: bygg i en kontrollerad miljö (Docker / CI runner). Inget beroende på dev-maskin.
> Automatisera: CI bygger artefakter, signerar, och uppdaterar APT-repo automatiskt.

> [!WARNING]
> Säker publicering: signera .deb (optionellt) och alltid signera APT Release med GPG; public key distribueras via *-archive-keyring paket eller README.

> [!IMPORTANT]
> Simplicity first: använd goreleaser/nfpm eller fpm beroende på vad du föredrar — men välj ett verktyg och håll dig till det.

```
project/
├── .github/
│   └── workflows/
│       ├── ci.yml            # build + test
│       └── release.yml       # build + package + publish (goreleaser)
├── build/
│   ├── docker/               # Dockerfile(s) för reproducible build
│   ├── pack-deb.sh          # helper script (calls nfpm/fpm/dpkg-deb)
│   └── publish-apt.sh       # uploader / repo-updater
├── packaging/
│   ├── debian/              # optional if using dpkg-buildpackage
│   │   ├── control
│   │   ├── changelog
│   │   └── install
│   └── repo-signer/         # reprepro/aptly config or apt-ftparchive config
├── scripts/                 # small dev utilities (install-local, lint)
├── dist/                    # CI artifacts (.deb, tar.gz)  (gitignored)
├── src/ OR cmd/             # language-specific source (e.g. cmd/main or src/)
│   └── ...                  # your code / main entrypoint
├── assets/
│   ├── appname.1            # manpage
│   └── appname.service      # optional systemd unit
├── docs/
│   ├── README.md
│   └── APT_PUBLISH.md       # how to host the repo & key distribution
├── nfpm.yaml OR fpm.conf    # package config if using nfpm/fpm
├── .goreleaser.yml          # optional: create debs and build artifacts
├── Makefile
└── LICENSE
```
