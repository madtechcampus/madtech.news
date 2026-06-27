# MadTech News — guía para agentes de código

MadTech News es el agregador de enlaces y discusión de la comunidad **Mad Tech Campus**
(Madrid). Es un fork de [lobsters](https://github.com/lobsters/lobsters) (Rails 8, Ruby 4.0),
localizado al español y desplegado en Hetzner mediante Docker Compose.

> Nota: el `AGENTS.md`/`CLAUDE.md` original de upstream prohibía contribuciones de LLM a *su*
> proyecto. Este fork es propiedad de Mad Tech Campus y esa política no aplica aquí.

## Stack
- Ruby on Rails 8, Ruby 4.0
- Base de datos: MariaDB 11 (adaptador `trilogy`)
- Cache/colas: SQLite (Solid Cache / Solid Queue)
- Assets: importmap + Sprockets

## Convenciones de este fork
- Nombre, dominio y descripción del sitio se configuran por variables de entorno
  (`SITE_NAME`, `SITE_DOMAIN`, `SITE_DESCRIPTION`) con valores por defecto de MadTech News
  en `config/application.rb`.
- El módulo Ruby interno sigue llamándose `Lobsters` para no romper referencias.
- Idioma por defecto: español (`config.i18n.default_locale = :es`).
- Mantener `upstream` como remoto para poder traer cambios de lobsters.

## Despliegue
Ver [DEPLOY.md](DEPLOY.md). Producción: `docker compose -f docker-compose.prod.yml up -d`.
