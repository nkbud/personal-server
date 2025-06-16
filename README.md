# Personal Server - Minimal Supabase on DigitalOcean

A minimal Supabase backend deployment optimized for 1GB DigitalOcean droplets.

## Overview

This repository contains a minimal, production-ready Supabase setup that can run on resource-constrained servers. It's specifically optimized for 1GB RAM DigitalOcean droplets while providing core Supabase functionality.

## Features

- **PostgreSQL Database** with optimized memory settings
- **PostgREST API** for automatic REST API generation
- **GoTrue Auth Service** for user authentication
- **Kong API Gateway** for routing and API management
- **Memory optimizations** for 1GB RAM environments
- **Docker Compose** for easy deployment and management

## Quick Start

1. **Deploy to DigitalOcean**: Follow the detailed instructions in [DEPLOY.md](./DEPLOY.md)
2. **Configure environment**: Copy `.env.example` to `.env` and update values
3. **Run services**: `docker-compose up -d`
4. **Check health**: `./health_check.sh`

## Project Structure

```
.
├── docker-compose.yml      # Main service definitions
├── .env.example           # Environment template
├── config/
│   └── kong.yml          # Kong API gateway configuration
├── init/
│   └── init.sql          # Database initialization script
├── health_check.sh       # Service health monitoring
├── DEPLOY.md            # Detailed deployment guide
└── README.md           # This file
```

## Services Included

| Service | Port | Description |
|---------|------|-------------|
| Kong API Gateway | 8000 | Main API endpoint |
| PostgREST | 3000 | Direct REST API access |
| GoTrue Auth | 9999 | Authentication service |
| PostgreSQL | 5432 | Database (internal) |

## Memory Optimization

This setup is specifically tuned for 1GB RAM:

- **PostgreSQL**: Limited to ~256MB with connection pooling
- **Reduced containers**: No Realtime or Storage services
- **Optimized buffers**: Smaller cache sizes and connection limits
- **Swap requirement**: 2GB swap file recommended

## API Usage

### Authentication
```bash
# Sign up a new user
curl -X POST "http://your-server:8000/auth/v1/signup" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password123"}'
```

### Database Access
```bash
# Query your data
curl -X GET "http://your-server:8000/rest/v1/profiles" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Environment Configuration

Key environment variables to set in `.env`:

```env
POSTGRES_PASSWORD=your-secure-password
JWT_SECRET=your-jwt-secret-32-chars-minimum
API_EXTERNAL_URL=http://your-domain.com:8000
SITE_URL=http://your-domain.com:8000
```

See `.env.example` for all available options.

## Monitoring

Use the included health check script:

```bash
./health_check.sh
```

Monitor resources:
```bash
# Memory usage
free -h

# Container stats
docker stats

# Service logs
docker-compose logs
```

## Limitations

- **Memory**: Optimized for 1GB RAM (requires swap)
- **CPU**: Single vCPU performance limitations
- **Concurrency**: ~10-20 concurrent users recommended
- **Features**: No Realtime subscriptions or Storage service
- **Scaling**: Manual vertical scaling required

## Production Considerations

- Use a domain name with SSL/TLS (nginx proxy recommended)
- Set up regular database backups
- Monitor disk space and memory usage
- Keep Docker images updated
- Use strong passwords and JWT secrets

## Support

- Full deployment guide: [DEPLOY.md](./DEPLOY.md)
- Supabase documentation: https://supabase.io/docs
- Issues and questions: GitHub Issues

## License

MIT License - see LICENSE file for details.
