# SafeTrack

SafeTrack is a comprehensive vehicle tracking solution featuring a Flutter frontend and a Python FastAPI backend with PostgreSQL/PostGIS.

## 📂 Project Structure

-   **Backend/**: FastAPI application, Docker configuration, and database schemas.
-   **Frontend/**: Flutter mobile application.
-   **Rapport_Dev_Logiciel/**: LaTeX documentation and reports.

## 🚀 Quick Start

### Backend (MANDATORY: DOCKER REQUIRED)

The backend and database **MUST** be run using Docker.

1.  **Start Services**:
    ```bash
    cd Backend
    docker-compose up -d --build
    ```
2.  **Verify**:
    Ensure `safetrack_backend` and `safetrack_db` are running via `docker ps`.

### Frontend (Mobile App)

1.  **Run App**:
    ```bash
    cd Frontend
    flutter pub get
    flutter run
    ```

For detailed deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## 🛠 Architecture

-   **Backend**: FastAPI, SQLAlchemy, PostgreSQL + PostGIS (Dockerized)
-   **Frontend**: Flutter (Mobile)

## 🔧 Troubleshooting

-   **Backend**: Check logs with `docker logs -f safetrack_backend`.
-   **Database**: Reset with `docker-compose down -v` followed by `up`.
