locals {
  cloud_config = <<-EOT
    #cloud-config
    ${yamlencode({
  write_files = [
    {
      path        = "/etc/systemd/system/caddy.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT2
              [Unit]
              Description=Start Caddy

              [Service]
              ExecStartPre=-/usr/bin/docker pull caddy:alpine
              ExecStart=/usr/bin/docker run --rm --network custom-bridge -p 80:80 -p 443:443 --mount 'type=bind,source=/mnt/disks/data/caddy/Caddyfile,target=/etc/caddy/Caddyfile,readonly' --mount 'type=bind,source=/mnt/disks/data/caddy/data,target=/data' --mount 'type=bind,source=/mnt/disks/data/caddy/config,target=/config' --name=caddy caddy:alpine
              ExecStop=/usr/bin/docker stop caddy
              ExecStopPost=-/usr/bin/docker rm caddy
              Restart=always
              RestartSec=10
              EOT2
    },
    {
      path        = "/etc/systemd/system/actual.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT3
                [Unit]
                Description=Start Actual

                [Service]
                ExecStartPre=-/usr/bin/docker pull ${var.actual_image}
                ExecStart=/usr/bin/docker run --rm --network custom-bridge --env-file /etc/actual.env --mount 'type=bind,source=/mnt/disks/data/actual-data,target=/data' --name=actual_server ${var.actual_image}
                ExecStop=/usr/bin/docker stop actual_server
                ExecStopPost=-/usr/bin/docker rm actual_server
                Restart=always
                RestartSec=10
                EOT3
    },
    {
      # Google sign-in (OpenID Connect). Password login is turned off.
      path        = "/etc/actual.env"
      permissions = "0600"
      owner       = "root"
      content     = <<-EOTENV
                ACTUAL_OPENID_DISCOVERY_URL=https://accounts.google.com
                ACTUAL_OPENID_CLIENT_ID=${var.google_oauth_client_id}
                ACTUAL_OPENID_CLIENT_SECRET=${var.google_oauth_client_secret}
                ACTUAL_OPENID_SERVER_HOSTNAME=https://${var.actual_fqdn}
                ACTUAL_OPENID_ENFORCE=true
                ACTUAL_LOGIN_METHOD=openid
                ACTUAL_ALLOWED_LOGIN_METHODS=openid
                ACTUAL_TOKEN_EXPIRATION=${var.session_lifetime_seconds}
                EOTENV
    },
    {
      # Weekly: re-pull Caddy and Actual (both services pull on start) and clean up old images.
      path        = "/etc/systemd/system/actual-update.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOTUPD
                [Unit]
                Description=Update Actual and Caddy containers

                [Service]
                Type=oneshot
                ExecStart=/usr/bin/systemctl restart caddy.service actual.service
                ExecStartPost=-/usr/bin/docker image prune -f
                EOTUPD
    },
    {
      path        = "/etc/systemd/system/actual-update.timer"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOTUPDT
                [Unit]
                Description=Weekly update of Actual and Caddy

                [Timer]
                OnCalendar=Sun *-*-* 10:00:00 UTC
                RandomizedDelaySec=30m
                Persistent=true
                EOTUPDT
    },
    {
      # Nightly: stop Actual for a few seconds, tar its data, upload to the backup bucket.
      # The VM's service account can create objects there but not read or delete them.
      path        = "/etc/actual-backup.sh"
      permissions = "0700"
      owner       = "root"
      content     = <<-EOTBAK
                #!/bin/bash
                set -euo pipefail
                ts=$(date -u +%Y%m%dT%H%M%SZ)
                f=/mnt/disks/data/actual-backup-$ts.tar.gz
                trap 'rm -f "$f"; systemctl start actual.service' EXIT
                systemctl stop actual.service
                tar -czf "$f" -C /mnt/disks/data actual-data
                systemctl start actual.service
                token=$(curl -sSf -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token | sed -E 's/.*"access_token":"([^"]+)".*/\1/')
                curl -sSf -o /dev/null -X POST -H "Authorization: Bearer $token" -H 'Content-Type: application/gzip' --data-binary @"$f" "https://storage.googleapis.com/upload/storage/v1/b/${google_storage_bucket.backups.name}/o?uploadType=media&name=actual-data-$ts.tar.gz"
                echo "Uploaded actual-data-$ts.tar.gz ($(stat -c %s "$f") bytes)"
                EOTBAK
    },
    {
      path        = "/etc/systemd/system/actual-backup.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOTBAKS
                [Unit]
                Description=Back up Actual data to Cloud Storage

                [Service]
                Type=oneshot
                ExecStart=/bin/bash /etc/actual-backup.sh
                EOTBAKS
    },
    {
      path        = "/etc/systemd/system/actual-backup.timer"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOTBAKT
                [Unit]
                Description=Nightly backup of Actual data

                [Timer]
                OnCalendar=*-*-* 09:00:00 UTC
                RandomizedDelaySec=15m
                Persistent=true
                EOTBAKT
    },
    {
      path        = "/tmp/Caddyfile"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT4
            ${var.actual_fqdn} {
                encode gzip zstd
                reverse_proxy actual_server:5006
            }
            EOT4
    },
    {
      path        = "/var/lib/cloud/scripts/per-instance/fs-prepare.sh"
      permissions = "0544"
      owner       = "root"
      content     = <<-EOT5
        #!/bin/bash

        DEVICE=/dev/disk/by-id/google-persistent-disk-1

        if ! blkid $DEVICE >/dev/null 2>&1; then
          mkfs.ext4 -L data -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard $DEVICE
        fi

        mkdir -p /mnt/disks/data
        mount -t ext4 -o nodev,nosuid $DEVICE /mnt/disks/data
        mkdir -p /mnt/disks/data/caddy
        mkdir -p /mnt/disks/data/caddy/data
        mkdir -p /mnt/disks/data/caddy/config
        mkdir -p /mnt/disks/data/actual-data
        cp /tmp/Caddyfile /mnt/disks/data/caddy/Caddyfile
        EOT5
    }
  ]

  runcmd = [
    "docker network create custom-bridge",
    "systemctl daemon-reload",
    "systemctl start caddy.service",
    "systemctl start actual.service",
    "systemctl start actual-update.timer",
    "systemctl start actual-backup.timer"
  ]

  bootcmd = [
    "fsck.ext4 -tvy /dev/disk/by-id/google-persistent-disk-1",
    "mkdir -p /mnt/disks/data",
    "mount -t ext4 -o nodev,nosuid /dev/disk/by-id/google-persistent-disk-1 /mnt/disks/data",
    "mkdir -p /mnt/disks/data/caddy",
    "mkdir -p /mnt/disks/data/caddy/data",
    "mkdir -p /mnt/disks/data/caddy/config",
    "mkdir -p /mnt/disks/data/actual-data"
  ]
})}
  EOT
}