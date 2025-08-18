# AGENTS.md — Agent spec: finish repo on first-init and keep it sane

**Språk:** Svenska
**Ton:** rak och handlingsorienterad — agenten ska fråga, föreslå och skapa. Inte gissa stora beslut utan bekräftelse.
**Mål:** gör repot `apt`-repo-redo med single-binary packaging (.deb), CI/release, publish-scripts och rimlig säkerhets-/deploy-konfiguration. Fyll i tomma filer, lägg till .gitignore, skapa grundläggande paket/CI/skript och be användaren om beslut där det behövs.

### Sammanfattning av vad agenten måste göra direkt (first-init)

1. Läs repots nuvarande struktur (kataloger ovan). Bekräfta att `dist/`, `packaging/`, `assets/`, `build/`, `.github/` finns.
2. Skapa eller uppdatera `.gitignore`. (Se template nedan.)
3. Ställ följande frågor till projektägaren (se avsnitt Frågor). Vänta på svar innan du tar beslut i dessa områden: `project_name`, `maintainer`, `homepage`, `default_branch`, `deb_dependencies`, `target_archs`, `CI-deploy-host` och GPG-nyckel-hantering.
4. Generera och skriv ut innehåll för följande nyckelfiler (fyll med placeholders/enhetliga värden där du inte har svar):
    - nfpm.yaml
    - build/publish-apt.sh
    - packaging/debian/control
    - .goreleaser.yml (minimal)
    - .github/workflows/release.yml (anropa goreleaser)
    - Makefile med make build, make package, make publish, make test-package
    - packaging/repo-signer/README.md (instruktioner för signing)

5. Kör lokala sanity-kontroller (ej körbar build): parse YAML, kontrollera att sökvägar i nfpm.yaml matchar assets/ och cmd/. Rapportera fel.
6. Commit-a allt i en initial branch-commit (git add + git commit -m "scaffold: packaging + CI + publish scripts"). Fråga om du ska pusha.

### Frågor agenten måste ställa (svara innan skapande av vissa filer)

1. Vad är projektets namn (paketnamn i apt)? (ex: ordna)
2. Vilken maintainer / e-post ska stå i debian control?
3. Vilken licens (MIT/Apache2/GPL)?
4. Vilka arkitekturer ska byggas (amd64, arm64)?
5. Ska vi signera APT Release med GPG från CI (ja/nej)? Om ja: ange var GPG private key läggs (GitHub secret)?
6. Var ska apt-repo publiceras (SSH host / rsync endpoint / GitHub Pages)? Ange access/metod.
7. Vill du att goreleaser skapar .deb eller vill du använda nfpm manuellt? (rekommenderat: goreleaser + nfpm)
8. Ska paketet installera systemd-unit (assets/appname.service) och autostarta? (ja/nej)
9. Behöver vi en archive-keyring paket för att distribuera repo-key? (rekommenderat: ja)
10. Vill du att agenten automatiskt pushar dev -> nightly eller ska det vara manuellt?

## Viktiga .gitignore (skriv i repo root)
```
# build artifacts
/dist/
/build/
/bin/
/out/

# OS/editor
.DS_Store
*.swp
*.swo
*.log

# keys and secrets
*.gpg
*.asc
private.key
secrets.*
.env

# packaging artifacts
*.deb
*.changes
*.buildinfo

# local test dirs
/tmp/
.vscode/
.idea/

# goreleaser state
.goreleaser.yml
```
> [!WARNING]
> Agent: lägg alltid till dist/ och secrets-filer här.

## Filmallar — kopiera/skriv exakt innehåll (fyll placeholders med svar från frågorna)
`nfpm.yaml` **(minimal)**
```
name: {{PROJECT_NAME}}
version: 0.0.1
arch: amd64
platform: linux
maintainer: "{{MAINTAINER}}"
vendor: "{{MAINTAINER}}"
description: "TODO: short description"
license: "{{LICENSE}}"
homepage: "{{HOMEPAGE}}"
contents:
  - src: ./dist/{{PROJECT_NAME}}
    dst: /usr/bin/{{PROJECT_NAME}}
  - src: ./assets/appname.1
    dst: /usr/share/man/man1/{{PROJECT_NAME}}.1
  - src: ./assets/appname.service
    dst: /lib/systemd/system/{{PROJECT_NAME}}.service
deb:
  depends:
    - ca-certificates
```
> [!IMPORTANT]
> Agent: ersätt placeholders med användar-svar. Spara som `nfpm.yaml`.

`build/publish-apt.sh`
```
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="/srv/apt-repo"
POOL="$REPO_ROOT/pool/main"
DIST_DIR="$1"  # path to .deb file

if [[ -z "$DIST_DIR" ]]; then
  echo "Usage: $0 path/to/package.deb"
  exit 2
fi

cp "$DIST_DIR" "$POOL/"
cd "$REPO_ROOT"
apt-ftparchive packages ./pool/main > ./dists/stable/main/binary-amd64/Packages
gzip -f ./dists/stable/main/binary-amd64/Packages
apt-ftparchive release ./dists/stable > ./dists/stable/Release
# Sign Release (CI should set REPO_GPG_KEY)
if [[ -n "${REPO_GPG_KEY:-}" ]]; then
  gpg --batch --yes --default-key "$REPO_GPG_KEY" --output ./dists/stable/Release.gpg --detach-sign ./dists/stable/Release
fi
echo "Published $DIST_DIR to $REPO_ROOT"
```

> [!IMPORTANT]
> Agent: make executable (`chmod +x`) and warn user that REPO_GPG_KEY must be provided in CI.

`packaging/debian/control` **(skeleton)**

```
Source: {{PROJECT_NAME}}
Section: utils
Priority: optional
Maintainer: {{MAINTAINER}}
Standards-Version: 4.6.0
Build-Depends: debhelper (>= 11)

Package: {{PROJECT_NAME}}
Architecture: any
Depends: ${misc:Depends}, ca-certificates
Description: TODO short description
 Long description here.
```

`.goreleaser.yml` **(minimal)**

```
project_name: {{PROJECT_NAME}}
builds:
  - id: {{PROJECT_NAME}}
    binary: {{PROJECT_NAME}}
    goos: linux
    goarch:
      - amd64
      - arm64
    main: ./cmd/{{PROJECT_NAME}}/main.go

nfpm:
  releases:
    - dist: deb
      section: main
      changelog: packaging/debian/changelog
      # reads nfpm.yaml by default
archives:
  - format: tar.gz
check:
  disable:
    - brew
```

> [!WARNING]
> Agent: replace placeholders; warn user to verify `cmd/` path.

`.github/workflows/release.yml` **(minimal, uses goreleaser)**

```
name: Release
on:
  push:
    tags:
      - 'v*.*.*'
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.20'
      - name: Run goreleaser
        uses: goreleaser/goreleaser-action@v2
        with:
          version: latest
        env:
          GPG_PRIVATE_KEY: ${{ secrets.REPO_GPG_KEY }}
          GPG_PASSPHRASE: ${{ secrets.REPO_GPG_PASSPHRASE }}
```

> [!NOTE]
> Agent: if user picks rsync deployment, create workflow step to `rsync` `.deb` to deploy host.

### Vad agenten får besluta själv (utan att fråga)
- Lägg till `dist/` i `.gitignore`.
- Skapa grundläggande Makefile med `build`, `package`, `publish` mål som anropar goreleaser eller nfpm.
- Skapa `packaging/repo-signer/README.md` med instruktioner för hur CI importerar GPG-nyckel.
- Om `assets/` saknar manpage/systemd, skapa små placeholderfiler med `TODO` text.

### Extra steg agenten ska föreslå efter scaffold
- Test-install: skapa en Dockerfile/test-script som installerar .deb i en clean container och kör smoke tests.
- Keyring package: skapa archive-keyring paketmall och instruktion för användare att lägga till signed-by i sources.list.
- Backup/rollback: dokumentera hur man tar snapshot av pool/ innan publicering.

### Validering / QA-checks agenten kör före commit
1. YAML/JSON lint (nfpm, goreleaser).

2. Kontroll att cmd/{{PROJECT_NAME}}/main.go finns om goreleaser refererar den. Om ej: skapa placeholder main.go som skriver version.

3. Kör nfpm pkg -f nfpm.yaml --target /tmp/test.deb om nfpm finns i environment, annars skip.

4. Kör git status --porcelain och visa vad som kommer att committas innan commit. Begär --yes från användaren.

### Output & kommunikation
- Agenten ska visa en CHANGELOG.md entry: scaffold: packaging + CI + publish scripts samt commit.
- Lista av filer skapade/ändrade i commit.
- En kort checklist för användaren med nästa steg (sätta GitHub secrets, justera nfpm.yaml description, testa publish-apt.sh i staging).

### Failure modes agenten måste hantera tydligt
- Missing GPG secrets → halt med instruktion hur man lägger till REPO_GPG_KEY och REPO_GPG_PASSPHRASE.
- Missing cmd/ binary path → skapa placeholder och varna.
- packaging/debian/control missing mantainer/home → fråga.
- Permissions: se till att build/publish-apt.sh är exekverbar.

### Tidigt prompt-skript (mall) agenten använder för att fråga användaren
```
Project name (packagename): [ordna]
Maintainer (Name <email>): [gg <you@example.org>]
Homepage URL: [https://example.org]
License (MIT/Apache-2.0/GPL-3.0): [MIT]
Target archs (comma): [amd64,arm64]
Deploy method (rsync/github-pages/ssh): [rsync]
CI redeploy host (user@host:/path): []
Sign APT Release with GPG in CI? (y/n): [y]
```

## Slutnot

> [!IMPORTANT]
> Agenten ska vara konservativ: fråga på beslut som påverkar signing, autodeploy eller branch history. Fyll och committa scaffolding men vänta på explicit konfirmering innan du pushar eller kör publish-apt.sh. Efter dessa steg är repot paket-redo men kräver manuella secrets/host-konfigurationer.
