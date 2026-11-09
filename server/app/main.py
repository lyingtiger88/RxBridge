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


import math
from pydantic import Field

class PharmacyProfileInput(BaseModel):
    pharmacy_name: str = Field(min_length=2, max_length=180)
    address: str = Field(min_length=5, max_length=500)
    phone: str | None = Field(default=None, max_length=40)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    is_published: bool = False


class PharmacyInventoryInput(BaseModel):
    medicine_name: str = Field(min_length=2, max_length=180)
    dosage_form: str = Field(min_length=1, max_length=80)
    strength: str = Field(default="", max_length=80)
    package_label: str = Field(default="", max_length=120)
    unit_price: int = Field(ge=0, le=100_000_000_000)
    stock_quantity: int = Field(ge=0, le=10_000_000)
    is_active: bool = True


class PrescriptionSearchItem(BaseModel):
    medicine_name: str = Field(min_length=2, max_length=180)
    dosage_form: str = Field(min_length=1, max_length=80)
    strength: str = Field(default="", max_length=80)
    package_label: str = Field(default="", max_length=120)
    quantity: int = Field(ge=1, le=100_000)


class PharmacySearchRequest(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    radius_km: float = Field(default=20, gt=0, le=100)
    items: list[PrescriptionSearchItem] = Field(min_length=1, max_length=100)


def _distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 6371.0088
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _norm(value: str) -> str:
    return " ".join(value.casefold().split())


@app.get("/v1/pharmacies/me")
def get_my_pharmacy(user=Depends(require_roles("pharmacist"))):
    with connect() as conn:
        profile = conn.execute(
            "SELECT * FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
        ).fetchone()
        if not profile:
            return {"profile": None, "inventory": []}
        inventory = conn.execute(
            "SELECT * FROM pharmacy_inventory WHERE pharmacy_id=%s ORDER BY medicine_name",
            (profile["id"],),
        ).fetchall()
    return {"profile": profile, "inventory": inventory}


@app.put("/v1/pharmacies/me")
def save_my_pharmacy(body: PharmacyProfileInput, user=Depends(require_roles("pharmacist"))):
    if (body.latitude is None) != (body.longitude is None):
        raise HTTPException(status_code=422, detail="Latitude and longitude must be supplied together")
    with connect() as conn:
        row = conn.execute("""
            INSERT INTO pharmacy_profiles
              (user_id, pharmacy_name, address, phone, latitude, longitude, is_published)
            VALUES (%s,%s,%s,%s,%s,%s,FALSE)
            ON CONFLICT(user_id) DO UPDATE SET
              pharmacy_name=EXCLUDED.pharmacy_name,
              address=EXCLUDED.address,
              phone=EXCLUDED.phone,
              latitude=EXCLUDED.latitude,
              longitude=EXCLUDED.longitude,
              is_published=(EXCLUDED.is_published AND pharmacy_profiles.verification_status='verified'),
              verification_status=CASE
                WHEN pharmacy_profiles.latitude IS DISTINCT FROM EXCLUDED.latitude
                  OR pharmacy_profiles.longitude IS DISTINCT FROM EXCLUDED.longitude
                  OR pharmacy_profiles.address IS DISTINCT FROM EXCLUDED.address
                THEN 'pending' ELSE pharmacy_profiles.verification_status END,
              updated_at=now()
            RETURNING *
        """, (user["id"], body.pharmacy_name.strip(), body.address.strip(),
              body.phone, body.latitude, body.longitude)).fetchone()
    return {"profile": row, "note": "Publication remains disabled until an administrator verifies the pharmacy."}


@app.put("/v1/pharmacies/me/inventory")
def upsert_pharmacy_inventory(body: PharmacyInventoryInput, user=Depends(require_roles("pharmacist"))):
    with connect() as conn:
        profile = conn.execute(
            "SELECT id FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
        ).fetchone()
        if not profile:
            raise HTTPException(status_code=409, detail="Create the pharmacy profile first")
        row = conn.execute("""
            INSERT INTO pharmacy_inventory
              (pharmacy_id, medicine_name, dosage_form, strength, package_label,
               unit_price, stock_quantity, is_active)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (pharmacy_id, medicine_name, dosage_form, strength, package_label)
            DO UPDATE SET unit_price=EXCLUDED.unit_price,
              stock_quantity=EXCLUDED.stock_quantity, is_active=EXCLUDED.is_active,
              updated_at=now()
            RETURNING *
        """, (profile["id"], body.medicine_name.strip(), body.dosage_form.strip(),
              body.strength.strip(), body.package_label.strip(), body.unit_price,
              body.stock_quantity, body.is_active)).fetchone()
    return row


@app.post("/v1/pharmacies/search")
def search_pharmacies(body: PharmacySearchRequest, user=Depends(require_roles("patient"))):
    with connect() as conn:
        pharmacies = conn.execute("""
            SELECT id, pharmacy_name, address, phone, latitude, longitude
            FROM pharmacy_profiles
            WHERE is_published=TRUE AND verification_status='verified'
              AND latitude IS NOT NULL AND longitude IS NOT NULL
        """).fetchall()
        results = []
        for pharmacy in pharmacies:
            distance = _distance_km(body.latitude, body.longitude,
                                    pharmacy["latitude"], pharmacy["longitude"])
            if distance > body.radius_km:
                continue
            inventory = conn.execute("""
                SELECT medicine_name, dosage_form, strength, package_label,
                       unit_price, stock_quantity, updated_at
                FROM pharmacy_inventory
                WHERE pharmacy_id=%s AND is_active=TRUE
            """, (pharmacy["id"],)).fetchall()
            matched = []
            missing = []
            available_subtotal = 0
            full_total = 0
            complete = True
            freshness = None
            for requested in body.items:
                candidates = [item for item in inventory
                    if _norm(item["medicine_name"]) == _norm(requested.medicine_name)
                    and _norm(item["dosage_form"]) == _norm(requested.dosage_form)
                    and _norm(item["strength"]) == _norm(requested.strength)
                    and _norm(item["package_label"]) == _norm(requested.package_label)]
                # Exact deterministic match; do not silently substitute a different medicine or pack.
                candidate = candidates[0] if candidates else None
                if candidate is None or candidate["stock_quantity"] < requested.quantity:
                    complete = False
                    missing.append({
                        "medicine_name": requested.medicine_name,
                        "requested_quantity": requested.quantity,
                        "available_quantity": 0 if candidate is None else candidate["stock_quantity"],
                    })
                    if candidate is not None:
                        available_subtotal += candidate["unit_price"] * min(candidate["stock_quantity"], requested.quantity)
                    continue
                line_total = candidate["unit_price"] * requested.quantity
                available_subtotal += line_total
                full_total += line_total
                matched.append({
                    "medicine_name": requested.medicine_name,
                    "quantity": requested.quantity,
                    "unit_price": candidate["unit_price"],
                    "line_total": line_total,
                })
                updated = candidate["updated_at"]
                freshness = updated if freshness is None or updated > freshness else freshness
            coverage = round((len(matched) / len(body.items)) * 100)
            results.append({
                "pharmacy_id": str(pharmacy["id"]),
                "pharmacy_name": pharmacy["pharmacy_name"],
                "address": pharmacy["address"],
                "phone": pharmacy["phone"],
                "latitude": pharmacy["latitude"],
                "longitude": pharmacy["longitude"],
                "distance_km": round(distance, 2),
                "coverage_percent": coverage,
                "complete": complete,
                "total_price": full_total if complete else None,
                "available_items_subtotal": available_subtotal,
                "matched_items": matched,
                "missing_items": missing,
                "inventory_updated_at": freshness,
            })
    # Rank by coverage first; compare total price only among complete baskets.
    results.sort(key=lambda x: (
        -x["coverage_percent"],
        x["total_price"] if x["complete"] else x["available_items_subtotal"],
        x["distance_km"],
    ))
    return {
        "synthetic_data_only": settings.staging_mode,
        "matching_policy": "exact medicine, dosage form, strength and package; no automatic substitution",
        "results": results,
    }


class PharmacyVerificationInput(BaseModel):
    verification_status: str = Field(pattern="^(verified|rejected|suspended)$")


@app.patch("/v1/admin/pharmacies/{pharmacy_id}/verification")
def set_pharmacy_verification(pharmacy_id: str, body: PharmacyVerificationInput,
                              user=Depends(require_roles("admin"))):
    with connect() as conn:
        row = conn.execute("""
            UPDATE pharmacy_profiles
            SET verification_status=%s,
                is_published=CASE WHEN %s='verified' THEN is_published ELSE FALSE END,
                updated_at=now()
            WHERE id=%s
            RETURNING id, user_id, pharmacy_name, verification_status, is_published
        """, (body.verification_status, body.verification_status, pharmacy_id)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Pharmacy not found")
    return row
