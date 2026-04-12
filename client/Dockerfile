# Build Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy workspace for pub get
COPY pubspec.yaml ./
COPY packages/ohhell_engine/pubspec.yaml packages/ohhell_engine/
COPY packages/ohhell_protocol/pubspec.yaml packages/ohhell_protocol/
COPY server/pubspec.yaml server/
COPY client/pubspec.yaml client/

COPY packages/ packages/
COPY client/ client/
COPY server/pubspec.yaml server/

RUN dart pub get
RUN flutter build web --release -C client

# Serve with nginx
FROM nginx:alpine

COPY --from=build /app/client/build/web /usr/share/nginx/html
COPY client/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
