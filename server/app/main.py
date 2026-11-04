import os
from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
import psycopg
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from pydantic_settings import BaseSettings, SettingsConfigDict
from psycopg.rows import dict_row


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    database_url: str = "postgresql://rxbridge:local_only@db:5432/rxbridge"
    jwt_secret: str = "CHANGE_ME_BEFORE_STARTING"
    jwt_issuer: str = "rxbridge-staging"
    token_minutes: int = 30
    cors_origins: str = "http://localhost:3000,http://localhost:8080"
    staging_mode: bool = True


settings = Settings()
if len(settings.jwt_secret) < 32 or settings.jwt_secret == "CHANGE_ME_BEFORE_STARTING":
    raise RuntimeError("JWT_SECRET must be a unique random secret of at least 32 characters")
app = FastAPI(title="RxBridge Staging API", version="0.1.0")
oauth2 = OAuth2PasswordBearer(tokenUrl="/v1/auth/token")
hasher = PasswordHasher()


def connect():
    return psycopg.connect(settings.database_url, row_factory=dict_row)


def current_user(token: Annotated[str, Depends(oauth2)]):
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"], issuer=settings.jwt_issuer)
        uid = payload.get("sub")
        if not uid:
            raise ValueError("missing subject")
    except (jwt.InvalidTokenError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    with connect() as conn:
        row = conn.execute(
            "SELECT id, username, role, display_name, active FROM app_users WHERE id=%s", (uid,)
        ).fetchone()
    if not row or not row["active"]:
        raise HTTPException(status_code=401, detail="Account unavailable")
    return row


def require_roles(*roles):
    def dependency(user=Depends(current_user)):
        if user["role"] not in roles:
            raise HTTPException(status_code=403, detail="Insufficient role")
        return user
    return dependency


@app.get("/health")
def health():
    try:
        with connect() as conn:
            conn.execute("SELECT 1")
        return {"status": "ok", "environment": "staging", "database": "ok"}
    except Exception:
        raise HTTPException(status_code=503, detail="Database unavailable")


@app.post("/v1/auth/token")
def login(form: Annotated[OAuth2PasswordRequestForm, Depends()]):
    with connect() as conn:
        user = conn.execute(
            "SELECT id, username, role, display_name, password_hash, active FROM app_users WHERE username=%s",
            (form.username,),
        ).fetchone()
    if not user or not user["active"]:
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    try:
        hasher.verify(user["password_hash"], form.password)
    except VerifyMismatchError:
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    exp = datetime.now(timezone.utc) + timedelta(minutes=settings.token_minutes)
    token = jwt.encode(
        {"sub": str(user["id"]), "iss": settings.jwt_issuer, "iat": datetime.now(timezone.utc), "exp": exp},
        settings.jwt_secret, algorithm="HS256"
    )
    return {"access_token": token, "token_type": "bearer", "expires_in": settings.token_minutes * 60,
            "role": user["role"], "display_name": user["display_name"]}


@app.get("/v1/me")
def me(user=Depends(current_user)):
    return {k: str(v) if k == "id" else v for k, v in user.items()}


@app.get("/v1/demo/summary")
def demo_summary(user=Depends(require_roles("admin", "doctor", "patient", "laboratory", "pharmacist", "insurer"))):
    # Synthetic fixture counts only. Patient-level access APIs are intentionally not exposed yet.
    with connect() as conn:
        row = conn.execute("""
          SELECT
            (SELECT count(*) FROM demo_patients) AS patients,
            (SELECT count(*) FROM demo_lab_orders) AS lab_orders,
            (SELECT count(*) FROM demo_glucose_readings) AS glucose_readings,
            (SELECT count(*) FROM demo_prescriptions) AS prescriptions
        """).fetchone()
    return {"environment": "staging", "synthetic_data_only": True, "counts": row}


class ConsentRequest(BaseModel):
    patient_id: str
    scope: str
    granted: bool


@app.post("/v1/demo/consents")
def record_demo_consent(body: ConsentRequest, user=Depends(require_roles("admin", "patient"))):
    if not settings.staging_mode:
        raise HTTPException(status_code=404, detail="Not found")
    if body.scope not in {"clinical_record", "confidential_record", "lab_results"}:
        raise HTTPException(status_code=422, detail="Unsupported consent scope")
    # Consent is recorded as a demo event; actual patient relationship checks are not implemented.
    with connect() as conn:
        row = conn.execute(
            "INSERT INTO demo_consent_events(patient_id, actor_user_id, scope, granted) VALUES (%s,%s,%s,%s) RETURNING id, created_at",
            (body.patient_id, user["id"], body.scope, body.granted),
        ).fetchone()
    return {"id": str(row["id"]), "created_at": row["created_at"], "synthetic": True}


@app.get("/")
def root():
    return {"service": "RxBridge Staging API", "docs": "/docs", "warning": "Synthetic test data only"}
