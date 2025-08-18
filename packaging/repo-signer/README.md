# Repo signer and CI usage

This repo uses GPG to sign `Release` and `InRelease` for the APT repo.

- Secrets to set in GitHub:
  - `GPG_PRIVATE_KEY`: ASCII-armored private key content
  - `GPG_PASSPHRASE`: passphrase for the key (if set)

Example import step for GitHub Actions:

```yaml
- name: Import GPG key
  env:
    GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
    GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
  run: |
    set -e
    echo "$GPG_PRIVATE_KEY" | gpg --batch --passphrase "$GPG_PASSPHRASE" --pinentry-mode loopback --import
    KEY_FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5;exit}')
    echo "$KEY_FPR:6:" | gpg --import-ownertrust
    echo "Using key $KEY_FPR"
```

Remember to remove key material after use if you export it to files.
