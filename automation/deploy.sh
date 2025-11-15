#!/bin/bash
#
# Echoelmusic Deployment Script
# Automated deployment to production servers
#
# Usage: ./deploy.sh [environment] [version]
# Example: ./deploy.sh production v1.2.3
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-staging}
VERSION=${2:-$(git describe --tags --abbrev=0)}
PROJECT_NAME="echoelmusic"
DOCKER_REGISTRY="ghcr.io/echoelmusic"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."

    command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed."; exit 1; }
    command -v docker-compose >/dev/null 2>&1 || { log_error "Docker Compose is required but not installed."; exit 1; }
    command -v aws >/dev/null 2>&1 || { log_error "AWS CLI is required but not installed."; exit 1; }

    log_success "All requirements met"
}

validate_environment() {
    log_info "Validating environment: $ENVIRONMENT"

    if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
        log_error "Invalid environment. Must be: development, staging, or production"
        exit 1
    fi

    if [ "$ENVIRONMENT" == "production" ]; then
        read -p "$(echo -e ${YELLOW}Are you sure you want to deploy to PRODUCTION? [y/N]: ${NC})" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Deployment cancelled"
            exit 0
        fi
    fi

    log_success "Environment validated"
}

run_tests() {
    log_info "Running tests..."

    cd backend
    npm test
    cd ..

    log_success "All tests passed"
}

build_docker_images() {
    log_info "Building Docker images..."

    # Backend API
    docker build -t $DOCKER_REGISTRY/backend:$VERSION -t $DOCKER_REGISTRY/backend:latest backend/

    log_success "Docker images built"
}

push_docker_images() {
    log_info "Pushing Docker images to registry..."

    docker push $DOCKER_REGISTRY/backend:$VERSION
    docker push $DOCKER_REGISTRY/backend:latest

    log_success "Docker images pushed"
}

deploy_to_server() {
    log_info "Deploying to $ENVIRONMENT servers..."

    case $ENVIRONMENT in
        development)
            SERVER="dev.echoelmusic.com"
            ;;
        staging)
            SERVER="staging.echoelmusic.com"
            ;;
        production)
            SERVER="api.echoelmusic.com"
            ;;
    esac

    # Deploy via SSH
    ssh deploy@$SERVER << EOF
        cd /opt/echoelmusic
        docker-compose pull
        docker-compose up -d
        docker system prune -f
EOF

    log_success "Deployed to $SERVER"
}

run_migrations() {
    log_info "Running database migrations..."

    cd backend
    npm run migrate
    cd ..

    log_success "Migrations completed"
}

health_check() {
    log_info "Running health check..."

    HEALTH_URL="https://api.echoelmusic.com/health"
    if [ "$ENVIRONMENT" == "staging" ]; then
        HEALTH_URL="https://staging.echoelmusic.com/health"
    fi

    sleep 5  # Wait for services to start

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

    if [ $RESPONSE -eq 200 ]; then
        log_success "Health check passed"
    else
        log_error "Health check failed with status code: $RESPONSE"
        exit 1
    fi
}

send_notification() {
    log_info "Sending deployment notification..."

    MESSAGE="✅ Deployed $PROJECT_NAME $VERSION to $ENVIRONMENT"

    # Slack notification
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$MESSAGE\"}" \
            $SLACK_WEBHOOK
    fi

    log_success "Notification sent"
}

rollback() {
    log_error "Deployment failed! Rolling back..."

    # Rollback to previous version
    ssh deploy@$SERVER << EOF
        cd /opt/echoelmusic
        docker-compose down
        docker-compose up -d --force-recreate
EOF

    log_warning "Rolled back to previous version"
    exit 1
}

# Main deployment flow
main() {
    log_info "==================== Echoelmusic Deployment ===================="
    log_info "Environment: $ENVIRONMENT"
    log_info "Version: $VERSION"
    log_info "=============================================================="

    check_requirements
    validate_environment
    run_tests
    build_docker_images
    push_docker_images
    deploy_to_server
    run_migrations || rollback
    health_check || rollback
    send_notification

    log_success "==================== Deployment Complete ===================="
    log_success "Version $VERSION is now live on $ENVIRONMENT!"
}

# Run main function
main
