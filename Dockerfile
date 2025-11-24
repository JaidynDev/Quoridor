# Stage 1: Build the Flutter Web application
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Run as root to ensure permissions for file copying and building
USER root

WORKDIR /app

# Copy dependency definitions first to leverage Docker cache
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application code
COPY . .

# Build the web application
RUN flutter build web --release

# Stage 2: Serve the application with Nginx
FROM nginx:alpine

# Copy the build output from the previous stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy custom Nginx configuration for SPA support (handling client-side routing)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 8080 (required for Cloud Run)
EXPOSE 8080

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
