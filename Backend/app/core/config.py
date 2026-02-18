from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "SafeTrack API"
    API_V1_STR: str = "/api/v1"
    
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str
    POSTGRES_DB: str
    DATABASE_URL: str | None = None
    
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    BACKEND_CORS_ORIGINS: list[str] = ["*"]

    CHIRPSTACK_API_URL: str = "http://192.168.1.102:8080"
    CHIRPSTACK_API_KEY: str = ""


    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True)

settings = Settings()
