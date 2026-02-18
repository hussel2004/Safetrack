# SafeTrack Deployment Guide

This guide provides step-by-step instructions for deploying the SafeTrack application, comprising a FastAPI backend (with PostgreSQL/PostGIS) and a Flutter frontend.

## Prerequisites

Ensure you have the following installed:
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Git](https://git-scm.com/downloads)

## Backend Deployment

The backend is containerized and managed via Docker Compose.

1.  **Navigate to the Backend directory:**
    ```bash
    cd Backend
    ```

2.  **Environment Configuration:**
    Ensure a `.env` file exists (or `docker-compose.yml` has the correct environment variables set).
    *Note: The current setup uses `docker-compose.yml` for configuration.*

3.  **Start Services:**
    Run the following command to build and start the backend containers in detached mode:
    ```bash
    docker-compose up -d --build
    ```

    This will launch:
    -   **safetrack_db**: PostgreSQL database with PostGIS extension (Port 5432).
    -   **safetrack_backend**: FastAPI application (Port 8000).

4.  **Verify Status:**
    Check if the containers are running:
    ```bash
    docker ps
    ```
    You should see `safetrack_backend` and `safetrack_db` with status `Up`.

5.  **View Logs:**
    To check backend logs:
    ```bash
    docker logs -f safetrack_backend
    ```

6.  **Database Reset (Optional):**
    If you need to wipe the database and start fresh:
    ```bash
    docker-compose down -v
    docker-compose up -d --build
    ```

## Frontend Deployment

The frontend is a Flutter mobile application.

1.  **Navigate to the Frontend directory:**
    ```bash
    cd Frontend
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run on Device:**
    Connect your Android/iOS device (ensure USB debugging is enabled) and run:
    ```bash
    flutter run
    ```
    Select your device if prompted.

4.  **Build APK (Android):**
    To create a release APK:
    ```bash
    flutter build apk --release
    ```
    The output will be in `build/app/outputs/flutter-apk/app-release.apk`.

## TroubleShooting

-   **Backend Connection Issues:** ensure your phone and computer are on the same network if running the app on a physical device, and verify the `API_URL` in the frontend config matches your computer's local IP address (not `localhost`).
-   **Docker Errors:** Ensure Docker Desktop is running and you have sufficient permissions.
