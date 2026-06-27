# Desplegar MadTech News en Hetzner

Guía para desplegar **MadTech News** (fork de lobsters) en un único VPS de Hetzner
Cloud usando Docker Compose. La pila es:

```
Internet ──▶ Caddy (TLS automático) ──▶ app (Puma)  ─┐
                                          worker (Solid Queue) ─┤──▶ db (MariaDB 11)
```

- **Caddy** obtiene y renueva certificados Let's Encrypt automáticamente.
- **app**: servidor web Puma. Aplica migraciones al arrancar (`db:prepare`).
- **worker**: procesa los jobs en segundo plano (Solid Queue).
- **db**: MariaDB 11 con volumen persistente.
- Cache y colas usan SQLite dentro del volumen `app_storage`.

---

## 1. Crear el servidor en Hetzner

1. Hetzner Cloud → **Add Server**.
   - Imagen: **Ubuntu 24.04**.
   - Tipo: **CPX21** (3 vCPU / 4 GB) como mínimo recomendado; CPX11 (2 GB) sirve
     para empezar con poca gente.
   - Añade tu **clave SSH**.
2. (Opcional pero recomendado) Activa **Backups** y un **Firewall** que permita
   solo los puertos **22, 80, 443**.
3. Anota la IP pública (IPv4 y, si la usas, IPv6).

## 2. DNS

En tu proveedor de DNS para `madtech.news`, crea:

| Tipo | Nombre | Valor              |
|------|--------|--------------------|
| A    | `@`    | IP IPv4 del server |
| AAAA | `@`    | IP IPv6 (opcional) |

Espera a que propague (`dig +short madtech.news` debe devolver la IP). Caddy no
podrá emitir el certificado TLS hasta que el DNS apunte al servidor.

## 3. Preparar el servidor

Conéctate por SSH (`ssh root@TU_IP`) y:

```sh
# Crear un usuario sin privilegios para operar
adduser deploy && usermod -aG sudo deploy
rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy

# Instalar Docker Engine + Compose plugin (script oficial)
curl -fsSL https://get.docker.com | sh
usermod -aG docker deploy
```

Reconéctate como `deploy` (`ssh deploy@TU_IP`).

## 4. Obtener el código

```sh
git clone <URL_DE_TU_REPO_MADTECH_NEWS> madtech-news
cd madtech-news
```

> Si aún no has publicado el repo, créalo (GitHub/GitLab) y haz `git push`.
> El remoto `upstream` ya apunta a lobsters para traer mejoras en el futuro.

## 5. Configurar secretos

```sh
cp .env.sample .env

# Generar un SECRET_KEY_BASE y la contraseña de BD
openssl rand -hex 64        # pégalo en SECRET_KEY_BASE
openssl rand -hex 24        # úsalo para DATABASE_PASSWORD
openssl rand -hex 24        # úsalo para DATABASE_ROOT_PASSWORD

nano .env
```

Rellena como mínimo: `SECRET_KEY_BASE`, `DATABASE_PASSWORD`,
`DATABASE_ROOT_PASSWORD`, `TLS_EMAIL`, y los datos `SMTP_*` de tu proveedor de
correo (Brevo, Mailgun, Postmark, Amazon SES, ...). El correo es necesario para
las **invitaciones** y el **restablecimiento de contraseña**.

`.env` está en `.gitignore`: nunca se sube al repositorio.

## 6. Arrancar

```sh
docker compose -f docker-compose.prod.yml up -d --build
```

La primera vez construye la imagen (unos minutos). Sigue los logs:

```sh
docker compose -f docker-compose.prod.yml logs -f app
```

Verás `Preparing database (db:prepare)...` y luego Puma escuchando. Caddy pedirá
el certificado en cuanto el DNS resuelva. Visita **https://madtech.news**.

## 7. Crear el primer usuario administrador

Lobsters es **por invitación** y no trae usuarios por defecto. Crea el primer
admin desde la consola de Rails:

```sh
docker compose -f docker-compose.prod.yml exec app bin/rails runner '
  u = User.new(
    username: "admin",
    email: "ricardo@pwngu.in",
    password: "CAMBIA_ESTA_CONTRASEÑA",
    password_confirmation: "CAMBIA_ESTA_CONTRASEÑA"
  )
  u.save!
  u.update!(is_admin: true, is_moderator: true)
  puts "Admin creado: #{u.username}"
'
```

Inicia sesión en `/login` y desde ahí ya puedes **invitar** a más gente
(menú de usuario → invitaciones) y crear **etiquetas/categorías** desde el panel
de moderación.

> Para abrir registros públicos temporalmente (p.ej. durante un evento de Mad
> Tech Campus), pon `OPEN_SIGNUPS=true` en `.env` y reinicia `app`. Léete la
> advertencia sobre spam en `config/application.rb` antes.

## 8. Operación diaria

```sh
# Ver estado / logs
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f app worker

# Consola de Rails
docker compose -f docker-compose.prod.yml exec app bin/rails console

# Reiniciar solo la app
docker compose -f docker-compose.prod.yml restart app
```

### Actualizar el sitio

```sh
git pull                      # o: git fetch upstream && git merge upstream/main
docker compose -f docker-compose.prod.yml up -d --build
```

Las migraciones se aplican solas al arrancar `app`.

### Copias de seguridad

La base de datos es el dato crítico. Vuelca MariaDB periódicamente:

```sh
docker compose -f docker-compose.prod.yml exec -T db \
  mariadb-dump -u root -p"$DATABASE_ROOT_PASSWORD" madtech \
  | gzip > backup-$(date +%F).sql.gz
```

Guarda también el volumen `app_storage` (subidas de Active Storage) y tu `.env`.
Automatízalo con un cron en el host y súbelo fuera del servidor (p.ej. Hetzner
Storage Box o un bucket S3).

### Restaurar

```sh
gunzip < backup-FECHA.sql.gz | docker compose -f docker-compose.prod.yml exec -T db \
  mariadb -u root -p"$DATABASE_ROOT_PASSWORD" madtech
```

---

## Notas

- **Branding/idioma**: nombre, dominio, descripción, idioma y zona horaria se
  controlan por variables de entorno en `.env` (ver `.env.sample`).
- **Logo/iconos**: los iconos en `public/` siguen siendo la langosta de lobsters.
  Sustituye `public/favicon.ico`, `public/touch-icon*.png` y el CSS de `#logo`
  por la imagen de MadTech Campus cuando la tengáis.
- **Correo en pruebas**: si dejas `SMTP_ADDRESS` vacío, el correo no se envía
  (solo se registra en el log). Útil para una primera prueba, pero las
  invitaciones por email no llegarán.
- **Recursos**: con poca gente, CPX11/CPX21 sobra. Si crece, sube el plan o
  separa la BD a su propio servidor.
