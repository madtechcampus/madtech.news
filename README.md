# MadTech News

**MadTech News** ([madtech.news](https://madtech.news)) es el agregador de enlaces y discusión
estilo Hacker News / [lobste.rs](https://lobste.rs) de la comunidad **Mad Tech Campus** (Madrid),
en español.

Es un fork de [lobsters/lobsters](https://github.com/lobsters/lobsters) (Ruby on Rails 8,
Ruby 4.0, MariaDB), rebautizado y localizado al español, preparado para desplegarse en Hetzner
mediante Docker Compose.

## Desarrollo local

Con Docker (recomendado):

```sh
docker compose up --build
# La app queda en http://localhost:3000
```

Sin Docker, ver la guía original de lobsters en [CONTRIBUTING.md](CONTRIBUTING.md)
(requiere Ruby 4.0 y MariaDB 11).

## Despliegue en producción (Hetzner)

Ver **[DEPLOY.md](DEPLOY.md)**. Resumen:

```sh
cp .env.production.sample .env.production   # y editar secretos/dominio
docker compose -f docker-compose.prod.yml up -d
```

## Configuración del sitio

El nombre, dominio y descripción se controlan por variables de entorno (con valores por
defecto de MadTech News en `config/application.rb`):

| Variable           | Por defecto                                                      |
|--------------------|-----------------------------------------------------------------|
| `SITE_NAME`        | `MadTech News`                                                   |
| `SITE_DOMAIN`      | `madtech.news`                                                   |
| `SITE_DESCRIPTION` | `Agregador de enlaces y discusión de la comunidad Mad Tech Campus.` |

Idioma por defecto: español (`config.i18n.default_locale = :es`).

## Relación con upstream

Este repo mantiene el remoto `upstream` apuntando a lobsters para poder traer mejoras:

```sh
git fetch upstream
git merge upstream/main   # resolver conflictos en branding/traducciones
```

## Licencia

Hereda la licencia de lobsters. Ver [LICENSE](LICENSE).

---

Hecho con ❤️ para la comunidad Mad Tech Campus.
