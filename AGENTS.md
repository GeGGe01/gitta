# AGENTS.md — Agent spec: finish repo on first-init and keep it sane

**Språk:** Svenska  
**Ton:** rak och handlingsorienterad — agenten ska fråga, föreslå och skapa. Inte gissa stora beslut utan bekräftelse.  
**Mål:** gör repot apt‑repo‑redo med single‑binary packaging (.deb), CI/release, publish‑scripts och säker nyckelhantering. Fyll i tomma filer, lägg till .gitignore, skapa grundläggande paket/CI/skript och be användaren om beslut där det behövs.

---

## 1. Kort målbild
Agenten ska kunna köra en `first‑init` som

- skapar / uppdaterar nödvändig packaging‑scaffold (nfpm, goreleaser, debian/control, Makefile)
- lägger in säkra `.gitignore`‑regler
- genererar publish‑skript (`publish‑apt.sh`) som producerar `Packages`, `Release`, **InRelease** och signerar korrekt
- validerar att refererade filer (binär i `cmd/`, `assets/`) finns och felar tidigt om inte
- committar scaffold i en ny branch och frågar innan push

Agenten ska *inte* force‑pusha eller ändra repo‑policyer utan uttryckligt godkännande.

---

## 2. First‑init — steg (konkret)
1. Läs repo och bekräfta att huvudmappar finns: `dist/`, `packaging/`, `assets/`, `build/`, `.github/`, `cmd/` eller `src/`.
2. Skapa/uppdatera `.gitignore` (se template nedan). Ta *inte* med `.goreleaser.yml` i `.gitignore`.
3. Ställ frågor (se avsnitt **Frågor**) och spara svar som placeholders som används i mallfiler.
4. Generera dessa filer (med placeholders där användaren ej svarat):
   - `nfpm.yaml`
   - `build/publish‑apt.sh` (skapar `Packages`, `Release`, **InRelease**, signerar)
   - `packaging/debian/control`
   - `.goreleaser.yml` (minimal)
   - `.github/workflows/release.yml` (kallar goreleaser eller bygger + nfpm)
   - `Makefile` med `build`, `package`, `publish`, `test-package`
   - `packaging/repo-signer/README.md` (instruktion: hur CI importerar GPG och signerar)
   - placeholder `cmd/{{PROJECT_NAME}}/main.go` om saknas (skriv version och help)
   - `scripts/smoke-test.sh` (installerar .deb i en container och kör smoke)
5. Validera: parse YAML (nfpm, goreleaser), kontrollera att sökvägar matchar `assets/` och `cmd/`. Fel → abort och rapportera.
6. Skapa en backup‑branch: `git branch scaffold-backup`.
7. `git add` + `git commit -m "scaffold: packaging + CI + publish scripts"` i branch `scaffold/packaging`.
8. Fråga användaren om den vill push:a branchen och/eller öppna PR.

---

## 3. Frågor agenten måste ställa före generering
Agenten ska **alltid** fråga dessa och spara svar. Svaren används för att ersätta placeholders.

1. **Project name** (paketnamn i apt) — ex: `ordna`
2. **Maintainer** (Name <email>)
3. **Homepage** (URL)
4. **License** (MIT / Apache-2.0 / GPL‑3.0)
5. **Target architectures** (comma separated, t.ex. `amd64,arm64`)
6. **Sign APT Release in CI?** (ja/nej). Om ja: ange GitHub secret‑namn för private key och passphrase.
7. **Deploy method** (rsync / ssh / github-pages). Ange endpoint om relevant.
8. **Use goreleaser or manual nfpm?** (rekommend: goreleaser + nfpm)
9. **Install systemd unit & enable by default?** (ja/nej)
10. **Create archive‑keyring package?** (rekommend: ja)

> Agenten får inte anta defaults för signering, deploy‑access eller auto‑enable av systemd — fråga.

---

## 4. .gitignore (template)
```
# build artifacts
dist/
build/
bin/
out/

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
packaging/repo-signer/private*

# packaging artifacts
*.deb
*.changes
*.buildinfo

# local test dirs
/tmp/
.vscode/
.idea/

# CI artefacts
dist/

# keep config files in repo: do NOT ignore .goreleaser.yml
```
> **OBS:** Ta bort eventuella rader som ignorerar `.goreleaser.yml` — den ska finnas i repo.

---

## 5. Viktiga mall‑filer och noter (agentens output)
Agenten skapar filer med placeholders. Här är korta noter och viktiga implementationer agenten använder.

### 5.1 `build/publish-apt.sh` — signera med InRelease
Agenten skapar ett publiceringsskript som **genererar `Packages`, `Release`, `InRelease`** och signerar med GPG. Viktigt: använd både `Release.gpg` (detached) och `InRelease` (clearsigned):

```bash
# create Packages
apt-ftparchive packages ./pool/main > ./dists/stable/main/binary-amd64/Packages
gzip -f ./dists/stable/main/binary-amd64/Packages
# create Release
apt-ftparchive release ./dists/stable > ./dists/stable/Release
# create InRelease (clearsigned)
gpg --batch --yes --default-key "$REPO_GPG_KEY" --output ./dists/stable/InRelease --clearsign ./dists/stable/Release
# create detached signature for clients that expect it
gpg --batch --yes --default-key "$REPO_GPG_KEY" --output ./dists/stable/Release.gpg --detach-sign ./dists/stable/Release
```

Agenten lägger en kommentar om att **REPO_GPG_KEY** ska finnas som GitHub Secret och importeras säkert i CI‑jobbet.

### 5.2 GPG import i GitHub Actions (secure snippet)
Agenten skapar ett säkert jobbsteg för att importera GPG‑nyckel i GH Actions runner:

```yaml
- name: Import GPG key
  env:
    GPG_PRIVATE_KEY: ${{ secrets.REPO_GPG_KEY }}
    GPG_PASSPHRASE: ${{ secrets.REPO_GPG_PASSPHRASE }}
  run: |
    set -e
    # Import key
    echo "$GPG_PRIVATE_KEY" | gpg --batch --import
    # Mark ownertrust ultimate for that key
    KEY_FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5;exit}')
    echo "$KEY_FPR:6:" | gpg --import-ownertrust
```
Agenten tar bort nyckeln (and trust) innan steget är klart om så önskas.

---

## 6. Validering och QA (vad agenten kör innan commit)
1. YAML‑lint på `nfpm.yaml` och `.goreleaser.yml` (yaml parser).  
2. Kontrollera att `cmd/{{PROJECT_NAME}}/main.go` eller motsvarande exekverbara källa finns — om ej: skapa placeholder och markera i commit.  
3. Kontrollera att `nfpm.yaml` innehåller `src:` vägar som faktiskt existerar i repo — annars fel.  
4. Kör `nfpm pkg -f nfpm.yaml --target /tmp/test.deb` om `nfpm` finns i miljön (CI).  
5. Kör `scripts/smoke-test.sh` i en container i CI (valfritt steg) för en snabb sanity install.  
6. Visa `git status --porcelain` och lista filer som kommer att committas — begär explicit ack från användaren.

---

## 7. Commit & push policy
- Skapa alltid backup‑branch före ändringar: `git branch scaffold-backup`.
- Gör commit i en dedikerad branch: `scaffold/packaging`.
- Fråga användaren innan push eller PR‑öppning.  
- Agenten får **inte** force‑pusha till skyddade branches utan klar confirm.

---

## 8. Extra som agenten får besluta automatiskt
- Lägga till `dist/` i `.gitignore` och andra build‑artifacts.  
- Skapa grundläggande `Makefile` med targets för `build`, `package`, `publish`.  
- Skapa placeholder‑manpage och systemd‑unit i `assets/` om de saknas.

---

## 9. Failure modes agenten måste hantera och meddelanden
- **Missing GPG secrets** → halt och instruktion: hur man lägger till `REPO_GPG_KEY` och `REPO_GPG_PASSPHRASE` i GitHub Secrets.
- **Missing cmd/ binary path** → skapa placeholder eller be användaren fixa; abort om user vill.
- **packaging/debian/control missing maintainer/homepage** → fråga användaren.
- **Permissions** → se till att `build/publish-apt.sh` är exekverbar; sätt `chmod +x`.

---

## 10. Snabb prompt‑mall agenten använder
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

---

## 11. Next steps (efter att scaffold är committat)
- Användaren: sätt GitHub Secrets (`REPO_GPG_KEY`, `REPO_GPG_PASSPHRASE`, `SSH_DEPLOY_KEY`).
- Test: kör CI:s release pipeline mot en staging apt‑repo (inte produktion första gången).
- Validera apt‑client: på en test‑VM lägg till keyring och gör `apt update` + `apt install project`.

---

> **Kort och tydligt:** agenten scaffoldar allt som behövs för att paketera en single‑binary som .deb och publicera i ett apt‑repo. Den frågar om signering, deploy och systemd‑policy, validerar slingan och committar i en branch — men den pushar eller deployar bara efter bekräftelse.
