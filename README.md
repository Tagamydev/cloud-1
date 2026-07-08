*This project has been created as part of the 42 curriculum by andresmejiaro, samusanc.*

# cloud-1 — WordPress Docker Stack

## Description

This repository holds the **containerized application** deployed by the Cloud-1
project: a WordPress site built from the *Inception* services, orchestrated with
**Docker Compose**. Each service runs in its own container (**1 process = 1
container**):

| Container | Image | Role |
|-----------|-------|------|
| `nginx` | `nginx:1.27-alpine` | TLS termination, HTTP→HTTPS redirect, reverse proxy |
| `wordpress` | `wordpress:6.7-fpm-alpine` | WordPress (PHP-FPM) |
| `mysql` | `mysql:8.0` | Database |
| `phpmyadmin` | `phpmyadmin:5.2-apache` | DB admin UI, served behind nginx at `/phpmyadmin/` |
| `wp-cli` | `wordpress:cli-2.11` | One-shot: imports the seed DB and configures WordPress |

The containers communicate over a private Docker network. Only nginx publishes
ports (80/443); MySQL and phpMyAdmin are **not** exposed on their native ports.
Data persists in Docker named volumes (`wordpress_vol`, `data_base_vol`), so it
survives container recreation and host reboots.

This stack is normally deployed automatically to a cloud server by the companion
repository
[**Cloud-1-deployment**](https://github.com/samusanc/Cloud-1-deployment) (Terraform
+ cloud-init). It can also be run manually, as below.

## Instructions

### Run manually (on an Ubuntu host with Docker)

```bash
# 1. Secrets — copy the template and fill in real values
cp docker/.env.example docker/.env
nano docker/.env

# 2. Launch (generates a self-signed TLS cert, then starts the stack)
sudo bash docker/setup.sh
```

`setup.sh` is idempotent: it generates the TLS certificate if missing, opens the
firewall (22/80/443), and runs `docker compose up -d` (using whichever Compose —
v1 or v2 — is installed). Once MySQL is initialised (~30 s):

```
HTTP  : http://localhost   (redirects to HTTPS)
HTTPS : https://localhost
phpMyAdmin : https://localhost/phpmyadmin/   (log in with the MySQL credentials)
```

### Layout

```
docker/
├── docker-compose.yml     # orchestrates the 5 containers
├── setup.sh               # one-shot provisioning (certs, firewall, compose up)
├── .env.example           # secrets template  (.env is git-ignored)
├── nginx/nginx.conf       # TLS + reverse proxy (WordPress + phpMyAdmin)
├── sql/database.sql       # seed database
└── wp/                    # PHP/WordPress config + wp-setup.sh
cloud-init/                # user-data/meta-data + ISO builder for local VM testing
```

> **Note:** `docker/.env` and `docker/certs/` are git-ignored — no secrets are
> committed. When deployed via Cloud-1-deployment, `.env` is injected at boot.

## Resources

- [Docker Compose](https://docs.docker.com/compose/) · [Docker Hub images](https://hub.docker.com/)
- [WordPress on Docker](https://hub.docker.com/_/wordpress) · [WP-CLI](https://developer.wordpress.org/cli/commands/)
- [nginx reverse proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html) · [FastCGI + PHP-FPM](https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/)
- [MySQL 8.0 Docker image](https://hub.docker.com/_/mysql) · [phpMyAdmin](https://docs.phpmyadmin.net/)
- 42 *Inception* project (the origin of this service layout)

### Use of AI

AI (Claude / Claude Code) was used as a reviewed coding partner. It helped with
**general debugging**, **integrating the scripts we developed separately** into the
provisioning flow (e.g. `setup.sh` bringing the Compose stack up), and
**documentation** — drafting this README and commenting the code. All service
choices and the Compose design were made and verified by us; AI sped up debugging
and cleanup, not the design decisions.
