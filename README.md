
# Laravel Docker Setup

This repository provides a Docker-based environment for hosting multiple Laravel applications. The setup includes PHP 8.3, Nginx, Node.js, and MySQL support, along with features to easily manage Laravel projects.

## Features

- **Alpine Linux Base**: Lightweight and efficient.
- **PHP 8.3 with FPM**: Configured to use port `9000` for PHP-FPM.
- **Nginx**: Serves Laravel applications.
- **Node.js 20 LTS**: Supports frontend build tools.
- **Automatic Nginx Configuration**: Easily configure new Laravel apps using a script.
- **Support for Multiple Laravel Applications**: Host multiple Laravel applications within the same Docker container.

## Setup Instructions

### Prerequisites

- Docker installed on your system.
- Basic knowledge of Docker and Laravel.

### Build the Docker Image

1. Clone this repository:

   ```bash
   git clone https://github.com/your-username/laravel-docker-setup.git
   cd laravel-docker-setup
   ```

2. Build the Docker image:

   ```bash
   docker build -t laravel-apps:latest .
   ```

### Run the Docker Container

Start the container with the following command:

```bash
docker run -d --name laravel-apps -v ~/laravel-apps:/var/www/laravel-apps -p 5000:80 laravel-apps:latest
```

- `~/laravel-apps`: This is the directory on your host where you will store your Laravel applications.

### Initialize a Laravel Application

To set up a Laravel application inside the container, use the `init_app` script:

- **Default Domain (`app_directory_name.jotaro.dev`)**:

  ```bash
  docker exec -it laravel-apps init_app app_directory_name
  ```

  This will:
  - Set up the application with the domain `app_directory_name.jotaro.dev`.
  - Save the Nginx configuration as `app_directory_name.jotaro.dev.conf`.

- **Custom Domain**:

  ```bash
  docker exec -it laravel-apps init_app app_directory_name --domain custom.domain.com
  ```

  This will:
  - Set up the application with the specified domain `custom.domain.com`.
  - Save the Nginx configuration as `custom.domain.com.conf`.

> [!NOTE]
> The nginx configurations are saved in `/etc/nginx/conf.d` directory inside docker container.

### Access the Application

- For default domains, access the application at `https://<app_directory_name>.jotaro.dev`.
- For custom domains, access the application at `https://<custom.domain.com>`.

Ensure your local machine's `/etc/hosts` file is configured to map these domains to `127.0.0.1` if necessary.

### Using Nginx Proxy Manager

You can use Nginx Proxy Manager to manage your domains and SSL certificates for the Laravel applications:

1. **Set Up Nginx Proxy Manager**:
   - Run the Nginx Proxy Manager in a separate Docker container.
   - Bind it to port 80, 443 on your host machine to manage incoming HTTP/HTTPS requests.

2. **Add a New Proxy Host**:
   - In the Nginx Proxy Manager dashboard, create a new proxy host.
   - Set the domain to your desired domain (e.g., `cyberspark.jotaro.dev` or `custom.domain.com`).
   - Set the Forward Hostname/IP to `host.docker.internal` (on Docker Desktop) or `localhost`/your server IP (e.g., `10.10.10.7`).
   - Set the Forward Port to `5000`.
   - Enable SSL and configure the certificate as needed.

3. **Access Your Application**:
   - After configuring Nginx Proxy Manager, access your Laravel application through the configured domain with SSL.


### Running Laravel Commands

You can execute Laravel commands inside the container using:

```bash
docker exec -it laravel-apps /bin/bash
cd <project_name>
php artisan migrate
php artisan migrate:fresh --seed
```

### Suppressing NPM Update Warnings

The Docker environment is configured to suppress NPM update notifications:

```Dockerfile
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
```

### Checking Logs

To view Nginx logs:

```bash
docker exec -it laravel-apps tail -f /var/log/nginx/error.log
docker exec -it laravel-apps tail -f /var/log/nginx/access.log
```

## Troubleshooting

### 502 Bad Gateway

If you encounter a `502 Bad Gateway` error, ensure that PHP-FPM is running and that Nginx is correctly configured to communicate with PHP-FPM on port `9000`.

### Database Connection Issues

Ensure the `.env` file for your Laravel application is correctly configured with your database connection details.

## Contributing

Contributions are welcome! Please submit a pull request or open an issue to discuss improvements or fixes.

## License

This project is licensed under the MIT License.
