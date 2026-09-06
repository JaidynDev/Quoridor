# Stage 1: Build the Flutter web application
FROM debian:bookworm-slim AS build

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Set up Flutter
ENV FLUTTER_ROOT=/usr/local/flutter
RUN git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_ROOT
ENV PATH="$FLUTTER_ROOT/bin:$PATH"

# Verify install and config
RUN flutter doctor
RUN flutter config --enable-web

# Copy app files
WORKDIR /app
COPY . .

# Build the web app
RUN flutter pub get
RUN flutter build web

# Stage 2: Serve the app using Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
# Configure Nginx to bind to $PORT if needed, but standard is 80. 
# Cloud Run expects 8080 by default.
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf
CMD ["nginx", "-g", "daemon off;"]
