# Rollback

What to undo, and how, if you want to back out part or all of this setup.
Nothing here was done destructively, so rollback is generally just
"delete what was added."

## Project repository

The entire project is new (this setup ran `git init`). To remove it
entirely:

```bash
rm -rf ~/dev/projects/neurosync-pro
```

(Not run automatically — this is your call, and `rm -rf` is denied for
agents in this repo's own `.claude/settings.json` for exactly this
reason.)

## ESP-IDF

```bash
rm -rf ~/esp/esp-idf-5.5.4 ~/esp/esp-idf-current
rm -rf ~/.espressif
```

## Codex CLI

```bash
rm -rf ~/.codex
# remove ~/.local/bin/codex if present (the standalone installer symlinks here)
```

The installer did not modify `~/.bashrc` (verified during setup — your
`~/.local/bin` was already on `PATH`), so there's no shell config to
revert for Codex itself.

## VS Code extensions

```bash
code --uninstall-extension ms-vscode-remote.remote-ssh
code --uninstall-extension ms-vscode.cpptools
code --uninstall-extension espressif.esp-idf-extension
```

## SSH

- Remove the dedicated key: `rm ~/.ssh/id_ed25519_neurosync ~/.ssh/id_ed25519_neurosync.pub`
- Restore the pre-setup `~/.ssh/config` from the timestamped backup created
  during Phase 12 (`~/.ssh/config.bak.<timestamp>`), or manually delete the
  `# >>> neurosync-pro >>> ... # <<< neurosync-pro <<<` block.

## Shell helpers

Restore `~/.bashrc` from the timestamped backup created during Phase 16
(`~/.bashrc.bak.<timestamp>`), or manually delete the
`# >>> neurosync-pro >>> ... # <<< neurosync-pro <<<` block.

## Local hardware config

```bash
rm -f ~/.config/neurosync/hardware.env
rmdir ~/.config/neurosync 2>/dev/null || true
```

## dialout group membership

If you no longer want `bowen` in `dialout`:

```bash
sudo gpasswd -d bowen dialout
```

(Only relevant if you ran the manual action in `manual-actions.md` #2.)

## Raspberry Pi

Nothing was installed on the Pi during this setup run (it was unreachable).
If you later run `pi-bootstrap` or `pi-deploy` and want to undo them:

```bash
ssh neurosync-pi 'rm -rf ~/apps/neurosync-pro'
scripts/pi/remove-services.sh --confirm   # only if install-services.sh was ever run
```
