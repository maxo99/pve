# zfs_mirror role

Creates a mirrored ZFS pool and, optionally, an encrypted dataset on a Proxmox host.

What it does (short)

- Installs ZFS packages (Debian-family)
- Creates a mirrored zpool using device-by-id paths
- Sets recommended pool properties (compression=lz4, atime=off)
- Optionally creates an encrypted dataset using a passphrase from HashiCorp Vault
- Deploys the dataset key to `/etc/zfs/keys/...` (root:0600) and installs a systemd unit to load keys at boot
- Registers the pool in `/etc/pve/storage.cfg` so it appears in the Proxmox GUI

Key points (practical)

- Secrets: The role expects `zfs_encryption_key` to be provided (recommended via Vault). The playbook in this repo fetches or generates the key on the controller and writes it to Vault (KV v2 under `terraform/data/zfs_keys`).
- Auto-unlock: The role installs `zfs-load-keys.service` which invokes `zfs load-key -a` at boot; the unit is written so transient errors do not leave it failed.
- Vault Agent alternative: If you prefer not to store keys on disk, set `zfs_deploy_key_to_host: false` and use a host-side Vault Agent to render the key file before boot.

Safety and flags

- This role can destroy data. Set variables deliberately.
  - `zfs_force_wipe`: when true, will wipe existing signatures (LUKS/FS) on listed disks.
  - `zfs_redeploy`: when true, will export/destroy an existing pool and optionally wipe devices before recreating.
- Use `/dev/disk/by-id/...` device paths in `zfs_disks`.

Minimal variables (defaults in `defaults/main.yml`)

- `zfs_pool_name` (default: `tank`)
- `zfs_disks` (list of device-by-id paths) — required
- `zfs_create_encrypted_dataset` (default: true)
- `zfs_encrypted_dataset_name` (default: `longterm`)
- `zfs_encryption_key` (empty by default; provide via Vault)
- `zfs_deploy_key_to_host` (default: true)
- `zfs_force_wipe` (default: true in this repo; set to false after initial run)
- `zfs_redeploy` (default: false)

Access from unprivileged LXC containers

- `zfs_mapped_uid` / `zfs_mapped_gid` (defaults: 100000): when set, the role will set the owner/group of the pool and dataset mountpoints to these numeric IDs so that LXC containers using userns high-mapped ranges (common default: 100000) can access the files. Set empty to skip.
- `zfs_chown_enable` (default: true): enable applying the ownership change.
- `zfs_chown_recursive` (default: false): whether to recurse the ownership change into existing files — use with caution on large datasets.

Note: setting these values only updates the host-side owner/group of the mountpoint. Ensure your LXC's /etc/subuid and /etc/subgid and container configuration map the same high range (typically 100000+) so UIDs inside the container align with the host numeric IDs.

Run (controller)

- Preferred: use the repository playbook which integrates Vault fetch/generation:

   ANSIBLE_ROLES_PATH=ansible/roles ansible-playbook ansible/playbooks/create_zfs_mirror.yml -i ansible/inventory/hosts.ini

Minimal troubleshooting

- If dataset creation fails with "no such pool": verify `zpool list` on the target and check earlier play output for pool creation errors.
- If the systemd unit fails at boot, inspect `systemctl status zfs-load-keys.service` and `journalctl -xeu zfs-load-keys.service`.

Security

- Keep `no_log: true` when handling secrets in playbooks. Prefer short-lived Vault auth.

That's it.
