## Scripts
| Path | Purpose |
| --- | --- |
| `Debian/nvidia-update` | Update, reinstall, or install a specific NVIDIA driver (signed DKMS module) |
| `Emby/emby-update` | Install the latest (or a given) Emby Server release |
| `Emby/update-emby-owner` | Switch the Emby service to run as UID 1000; called by `emby-update` |
| `Plex/plex-update` | Install the latest public (or a given) Plex Media Server release |
| `Komga/komga-updater` | Back up, update, and clean up Komga in one go |
| `Komga/komga-*` | Individual Komga backup / update / cleanup steps |
| `Komga/komga.conf` | Shared Komga settings, installed as `/usr/local/etc/komga.conf` |
| `Services/*.service` | systemd units for Komga and Sonarr |
| `FreeBSD/rpoudriere` | Update poudriere ports trees, reapply patches, bulk build |
| `FreeBSD/port-test` | Build a port and its test dependencies in a poudriere jail |

## Dependencies
Komga: `sudo apt install openjdk-21-jre jq wget sqlite3`

Plex: `sudo apt install jq wget`

Emby / NVIDIA: `sudo apt install wget`

# Acknowledgements
Komga Scripts modifed for use on Debian sourced from [Fuji44 Komga TrueNAS Plugin](https://github.com/fuji44/iocage-plugin-komga)

Update Emby Owner Script sourced from [Forum Topic 78581](https://emby.media/community/index.php?/topic/78581-how-to-change-the-user-emby-runs-as/).
