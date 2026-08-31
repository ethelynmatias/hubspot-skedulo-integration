# HubSpot–Skedulo Integration

A Laravel application that integrates HubSpot with Skedulo. The whole development
environment runs in Docker (PHP-FPM, Nginx, MySQL and Redis) and is driven through
a `Makefile`.

## Requirements

- [Docker](https://docs.docker.com/get-docker/) with the Compose plugin (`docker compose`)
- `make`
- Node.js 20+ and npm — only needed for the frontend assets, which are built on the host

PHP and Composer are **not** required on the host; they live in the `app` container.

## Installation

```bash
git clone <repository-url> hubspot-skedulo-integration
cd hubspot-skedulo-integration
make init
```

`make init` performs the full first-time setup:

1. `make env` — copies `.env.example` to `.env` (only if `.env` does not exist yet) and
   sets `DOCKER_UID`/`DOCKER_GID` to your user so bind-mounted files stay writable.
2. `make build` — builds the `app` image.
3. `make up` — starts the containers.
4. `make install` — runs `composer install` in the container and `npm install` on the host.
5. `make key` — generates `APP_KEY`.
6. `make migrate` — runs the database migrations.

When it finishes the app is available at <http://localhost:8000> (or whatever
`APP_PORT` is set to in `.env`).

For the frontend during development, run the Vite dev server in a second terminal:

```bash
make dev
```

### Doing it by hand

If you would rather not use `make`:

```bash
cp .env.example .env
docker compose build
docker compose up -d
docker compose exec app composer install
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate
npm install && npm run dev
```

## Configuration

Everything is configured through `.env`. The values worth knowing about:

| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_PORT` | `8000` | Host port Nginx is published on |
| `FORWARD_DB_PORT` | `3307` | Host port for MySQL, for a GUI client |
| `FORWARD_REDIS_PORT` | `6380` | Host port for Redis |
| `DOCKER_UID` / `DOCKER_GID` | `1000` | Host user ids the container runs as |
| `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` | `hubspot_skedulo` / `hubspot_skedulo` / `secret` | Application database credentials |
| `DB_ROOT_PASSWORD` | `root` | MySQL root password |

`DB_HOST` and `REDIS_HOST` point at the `mysql` and `redis` service names — leave
them as they are so the app can reach them over the Compose network.

Changing `DB_*` or the forwarded ports after the stack has been created requires
`make fresh-start` (which deletes the database volume) followed by `make up`.

## Services

| Service | Container | Description |
| --- | --- | --- |
| `app` | `hubspot-skedulo-app` | PHP 8.4 FPM with the application code |
| `nginx` | `hubspot-skedulo-nginx` | Web server, published on `APP_PORT` |
| `mysql` | `hubspot-skedulo-mysql` | MySQL 8.4, data kept in the `mysql-data` volume |
| `redis` | `hubspot-skedulo-redis` | Redis for cache, sessions and queues |

## Make targets

Run `make help` to see this list in your terminal.

### Setup

| Target | Description |
| --- | --- |
| `make init` | First-time setup: env, build, start, install deps, key, migrate |
| `make env` | Create `.env` and set `DOCKER_UID`/`DOCKER_GID` to your user |
| `make install` | Install PHP and JS dependencies |
| `make key` | Generate the application key |

### Containers

| Target | Description |
| --- | --- |
| `make build` | Build the app image |
| `make up` | Start the stack in the background |
| `make down` | Stop the stack |
| `make restart` | Restart the stack |
| `make fresh-start` | Stop the stack and delete its volumes (**drops the database**) |
| `make ps` | Show container status |
| `make logs` | Tail logs for all containers |
| `make shell` | Open a shell in the app container |

### Application

| Target | Description |
| --- | --- |
| `make artisan cmd="route:list"` | Run any artisan command |
| `make composer cmd="require vendor/pkg"` | Run any composer command |
| `make migrate` | Run database migrations |
| `make migrate-fresh` | Drop all tables, re-run migrations and seeders |
| `make seed` | Run database seeders |
| `make tinker` | Open a Tinker REPL |
| `make queue` | Run the queue worker in the foreground |
| `make fresh` | Clear cached config, routes, views and events |

### Frontend

| Target | Description |
| --- | --- |
| `make dev` | Run the Vite dev server on the host |
| `make assets` | Build frontend assets for production |

### Quality

| Target | Description |
| --- | --- |
| `make test` | Run the test suite |
| `make lint` | Format PHP with Pint |
| `make lint-check` | Check PHP formatting without changing files |

## Troubleshooting

**Port already in use** — another service is on `APP_PORT`, `FORWARD_DB_PORT` or
`FORWARD_REDIS_PORT`. Change the value in `.env` and run `make restart`.

**Permission errors on `storage/` or `bootstrap/cache/`** — the container user's ids
do not match yours. Run `make env` to fix them, then `make build && make up`.

**`vendor/` looks empty on the host** — that is expected. `vendor` is a container-only
volume, so run Composer through `make composer cmd="..."` rather than on the host.

**MySQL connection refused right after `make up`** — MySQL is still initialising.
The app container waits for its healthcheck; give it a few seconds and check
`make logs`.
