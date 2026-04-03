# BHL Dashboard

Interactive dashboard for the [Biodiversity Heritage Library](https://www.biodiversitylibrary.org/) built with [Metabase](https://www.metabase.com/) and SQLite.

## Local development

**Prerequisites:** Docker Desktop

```bash
cp .env.example .env        # adjust METABASE_PORT if 3000 is taken
docker compose up -d
open http://localhost:3000
```

On first run, Metabase walks you through setup (~2 minutes). When adding your database, choose **SQLite** and set the path to `/data/your-file.sqlite` (files in the `data/` directory are mounted read-only inside the container).

## Adding your SQLite database

Drop your SQLite file(s) into the `data/` directory:

```bash
cp /path/to/bhl.sqlite data/
```

In Metabase → Admin → Databases → Add database:
- **Database type:** SQLite
- **Filename:** `/data/bhl.sqlite`

## Production deployment (Hetzner)

### Server setup (one-time)

1. Create a Hetzner VPS (CX22 or larger recommended).
2. Point your domain's A record at the server IP.
3. SSH in and install Docker:
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```
4. Create the app directory and `.env`:
   ```bash
   mkdir -p /opt/bhl-dashboard
   cat > /opt/bhl-dashboard/.env <<EOF
   DOMAIN=bhl.example.com
   EOF
   ```

### Deploy

```bash
./deploy.sh root@your-server-ip
```

This rsyncs all project files and the `data/` directory, then starts Metabase behind Caddy (which handles HTTPS automatically via Let's Encrypt).

### Update

Just run `./deploy.sh` again. Caddy and Metabase configuration is preserved across deploys in Docker volumes.

## Architecture

```
Internet → Caddy (HTTPS/443) → Metabase (:3000) → SQLite (read-only volume)
```

- **Metabase** stores its own application data (users, dashboards, questions) in an H2 database persisted in the `metabase-data` Docker volume.
- **SQLite** BHL data is mounted read-only from `./data/`.
- **Caddy** automatically provisions and renews TLS certificates.

## Updating Metabase

```bash
docker compose pull && docker compose up -d   # local
./deploy.sh root@your-server-ip               # production
```
