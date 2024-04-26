## Loki Docker plugin (external configuration)

This plugin has to be installed to all instances/servers from which you plan to gather
logs. It will send logs to the Loki server (defined in the current repo as a docker-compose
service).

[Installation docs](https://grafana.com/docs/loki/latest/send-data/docker-driver/)

```bash
docker plugin \
  install grafana/loki-docker-driver:2.9.2 \
  --alias loki \
  --grant-all-permissions
```

[Configuration docs](https://grafana.com/docs/loki/latest/send-data/docker-driver/configuration/)

Each Docker app has to be configured with a new log driver utilizing
the plugin that was just installed:

```bash
docker run \
    --log-driver=loki \
    --log-opt loki-url="https://<user_id>:<password>@logs-us-west1.grafana.net/loki/api/v1/push" \
    --log-opt loki-retries=5 \
    --log-opt loki-batch-size=400 \
    your-name/your-image
```

Log driver can also be specified in the `docker-compose.yml` file:

```bash
version: "3.7"
services:
  logger:
    image: your-name/your-image
    logging:
      driver: loki
      options:
        loki-url: "https://<user_id>:<password>@logs-prod-us-central1.grafana.net/loki/api/v1/push"
```

## SSL certificates generation

This step is only needed if you plan to run Grafana as a secured HTTPS web app
(either directly or with a reverse proxy like Nginx).

[Route 53 Certbot docs](https://certbot-dns-route53.readthedocs.io/en/stable/)

```bash
# AWS credentials to modify Route 53 entries
# (IAM policy described in the docs)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# domain name to generate certificates for
SSL_DOMAIN_NAME=
```

Execute the script (it will read variables from the `.env` file):

```bash
bash ./generate-ssl-certificates.sh
```

Currently, this script is configured to work with Route 53 DNS provider only,
more providers can be added in the future.

## Running Loki and Grafana

There are multiple ways to run this configuration.
Grafana, Loki and optionally Nginx will be executed
in detached (background) mode.

### 1. Grafana acting as a standalone HTTP web server

```bash
# this mode is default so the main entry script can be executed simply as:
bash ./run.sh

# or you can specify the mode as well:
bash ./run.sh --mode=grafana-http
```

### 2. Grafana acting as an HTTPS web server

Certificates are required for this mode.

Be sure to generate them first using the `generate-ssl-certificates.sh` script.
Grafana service container will be running as a `root` user (not recommended,
but that's how it can access the certificate files). If it's not feasible,
try running with Nginx as a reverse proxy.

```bash
bash ./run.sh --mode=grafana-https
```

### 3. Nginx HTTPS web server as an additional docker-compose service

Certificates are required here as well.

```bash
bash ./run.sh --mode=nginx-https
```

### 4. With Nginx web server beyond this repo

Certificates are required here as well.

They will be copied to this path: `/etc/ssl/live/${SSL_DOMAIN_NAME}`
(it will be automatically created).

The generated virtual host config file will be copied to the directory
specified in the `NGINX_EXTERNAL_FOLDER` variable which defaults to
`/etc/nginx/conf.d`. It can also be set to `/etc/nginx/sites-enabled` if 
that's how your Nginx is configured.

```bash
bash ./run.sh --mode=nginx-external
```

## IP whitelisting for Loki push endpoint in Nginx

If you're running Grafana and Loki behind Nginx, you might want to restrict
access to the Loki push endpoint. This can be done by adding the following
variable to the `.env` file:

```bash
LOKI_IP_WHITELIST=127.0.0.1,127.0.0.2
```

Several addresses can be specified separated by a comma. IP subnets can be
specified as well ([more details](https://nginx.org/en/docs/http/ngx_http_access_module.html#allow)).
