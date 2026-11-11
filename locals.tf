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
                ExecStart=/usr/bin/docker run --rm --network custom-bridge --mount 'type=bind,source=/mnt/disks/data/actual-data,target=/data' --name=actual_server ${var.actual_image}
                ExecStop=/usr/bin/docker stop actual_server
                ExecStopPost=-/usr/bin/docker rm actual_server
                Restart=always
                RestartSec=10
                EOT3
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
    "systemctl start actual.service"
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