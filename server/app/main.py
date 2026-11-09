import os
from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
import psycopg
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import Depends, FastAPI, HTTPException, Response, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from pydantic_settings import BaseSettings, SettingsConfigDict
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    database_url: str = "postgresql://rxbridge:local_only@db:5432/rxbridge"
    jwt_secret: str = "CHANGE_ME_BEFORE_STARTING"
    jwt_issuer: str = "rxbridge-staging"
    token_minutes: int = 30
    cors_origins: str = "http://localhost:3000,http://localhost:8080"
    staging_mode: bool = True
    auth_provider: str = "local"
    supabase_url: str = ""
    supabase_publishable_key: str = ""


settings = Settings()
if settings.auth_provider not in {"local", "supabase"}:
    raise RuntimeError("AUTH_PROVIDER must be either local or supabase")
if settings.auth_provider == "local" and (len(settings.jwt_secret) < 32 or settings.jwt_secret == "CHANGE_ME_BEFORE_STARTING"):
    raise RuntimeError("JWT_SECRET must be a unique random secret of at least 32 characters")
if settings.auth_provider == "supabase" and (
    not settings.supabase_url.startswith("https://") or not settings.supabase_publishable_key
):
    raise RuntimeError("SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required for Supabase authentication")
app = FastAPI(title="RxBridge Staging API", version="0.1.0")
oauth2 = OAuth2PasswordBearer(tokenUrl="/v1/auth/token")
hasher = PasswordHasher()
_supabase_jwks_client = None


def _supabase_issuer() -> str:
    return settings.supabase_url.rstrip("/") + "/auth/v1"


def _verify_supabase_token(token: str) -> dict:
    """Verify Supabase access tokens; never trust client-supplied role metadata."""
    global _supabase_jwks_client
    try:
        header = jwt.get_unverified_header(token)
        algorithm = header.get("alg")
        if algorithm in {"ES256", "RS256"}:
            if not header.get("kid"):
                raise ValueError("Missing JWT key identifier")
            if _supabase_jwks_client is None:
                _supabase_jwks_client = jwt.PyJWKClient(
                    settings.supabase_url.rstrip("/") + "/auth/v1/.well-known/jwks.json",
                    cache_keys=True,
                    timeout=5,
                )
            signing_key = _supabase_jwks_client.get_signing_key_from_jwt(token)
            claims = jwt.decode(
                token, signing_key.key, algorithms=[algorithm],
                issuer=_supabase_issuer(), audience="authenticated",
                options={"require": ["exp", "iat", "sub", "iss", "aud"]},
                leeway=30,
            )
        elif algorithm == "HS256":
            # Legacy symmetric keys are verified by Supabase Auth itself.
            claims = jwt.decode(
                token,
                options={
                    "verify_signature": False, "verify_exp": True,
                    "verify_iat": True, "verify_aud": False,
                    "verify_iss": False,
                    "require": ["exp", "iat", "sub", "iss", "aud"],
                },
                leeway=30,
            )
            audience = claims.get("aud")
            if claims.get("iss") != _supabase_issuer() or not (
                audience == "authenticated" or
                isinstance(audience, list) and "authenticated" in audience
            ):
                raise ValueError("Invalid Supabase token issuer or audience")
            response = httpx.get(
                _supabase_issuer() + "/user",
                headers={
                    "apikey": settings.supabase_publishable_key,
                    "Authorization": f"Bearer {token}",
                },
                timeout=5.0,
            )
            if response.status_code != 200:
                raise ValueError("Supabase Auth rejected the access token")
            auth_user = response.json()
            if str(auth_user.get("id")) != str(claims["sub"]):
                raise ValueError("Supabase user identity mismatch")
        else:
            raise ValueError("Unsupported Supabase JWT algorithm")
        if claims.get("role") != "authenticated":
            raise ValueError("Token is not an authenticated user session")
        UUID(str(claims["sub"]))
        return claims
    except (jwt.InvalidTokenError, ValueError, KeyError, httpx.HTTPError) as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired Supabase access token") from exc



def connect():
    return psycopg.connect(settings.database_url, row_factory=dict_row)


def current_user(token: Annotated[str, Depends(oauth2)]):
    if settings.auth_provider == "supabase":
        payload = _verify_supabase_token(token)
        uid = payload["sub"]
    else:
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
    if settings.auth_provider == "supabase":
        raise HTTPException(status_code=404, detail="Use Supabase Auth sign-in from the client")
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
import hashlib
import json
from uuid import UUID
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


def _audit_event(conn, pharmacy_id, actor_user_id, event_type, target_id=None, payload=None):
    conn.execute("""
        INSERT INTO pharmacy_audit_events
          (pharmacy_id, actor_user_id, event_type, target_id, payload)
        VALUES (%s,%s,%s,%s,%s)
    """, (pharmacy_id, actor_user_id, event_type, target_id, Jsonb(payload or {})))


def _notify(conn, recipient_user_id, actor_user_id, event_type, title, body, entity_type, entity_id):
    conn.execute("""
        INSERT INTO app_notifications
          (recipient_user_id, actor_user_id, event_type, title, body, entity_type, entity_id)
        VALUES (%s,%s,%s,%s,%s,%s,%s)
    """, (recipient_user_id, actor_user_id, event_type, title, body, entity_type, entity_id))


@app.get("/v1/notifications/me")
def list_my_notifications(user=Depends(current_user)):
    with connect() as conn:
        rows = conn.execute("""
            SELECT id, event_type, title, body, entity_type, entity_id, read_at, created_at
            FROM app_notifications
            WHERE recipient_user_id=%s
            ORDER BY created_at DESC LIMIT 100
        """, (user["id"],)).fetchall()
        unread = conn.execute("""
            SELECT count(*) AS count FROM app_notifications
            WHERE recipient_user_id=%s AND read_at IS NULL
        """, (user["id"],)).fetchone()["count"]
    return {"items": rows, "unread_count": unread}


@app.post("/v1/notifications/{notification_id}/read")
def mark_notification_read(notification_id: UUID, user=Depends(current_user)):
    with connect() as conn:
        row = conn.execute("""
            UPDATE app_notifications SET read_at=COALESCE(read_at,now())
            WHERE id=%s AND recipient_user_id=%s
            RETURNING id, read_at
        """, (notification_id, user["id"])).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    return row


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
              is_published=CASE
                WHEN pharmacy_profiles.latitude IS DISTINCT FROM EXCLUDED.latitude
                  OR pharmacy_profiles.longitude IS DISTINCT FROM EXCLUDED.longitude
                  OR pharmacy_profiles.address IS DISTINCT FROM EXCLUDED.address
                  OR pharmacy_profiles.pharmacy_name IS DISTINCT FROM EXCLUDED.pharmacy_name
                THEN FALSE
                ELSE (EXCLUDED.is_published AND pharmacy_profiles.verification_status='verified')
              END,
              verification_status=CASE
                WHEN pharmacy_profiles.latitude IS DISTINCT FROM EXCLUDED.latitude
                  OR pharmacy_profiles.longitude IS DISTINCT FROM EXCLUDED.longitude
                  OR pharmacy_profiles.address IS DISTINCT FROM EXCLUDED.address
                  OR pharmacy_profiles.pharmacy_name IS DISTINCT FROM EXCLUDED.pharmacy_name
                THEN 'pending' ELSE pharmacy_profiles.verification_status END,
              updated_at=now()
            RETURNING *
        """, (user["id"], body.pharmacy_name.strip(), body.address.strip(),
              body.phone, body.latitude, body.longitude)).fetchone()
        _audit_event(conn, row["id"], user["id"], "pharmacy.profile.saved", row["id"],
                     {"changed_fields": ["pharmacy_name", "address", "phone", "location"]})
    return {"profile": row, "note": "Publication remains disabled until an administrator verifies the pharmacy."}


@app.put("/v1/pharmacies/me/inventory")
def upsert_pharmacy_inventory(body: PharmacyInventoryInput, user=Depends(require_roles("pharmacist"))):
    with connect() as conn:
        profile = conn.execute(
            "SELECT id FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
        ).fetchone()
        if not profile:
            raise HTTPException(status_code=409, detail="Create the pharmacy profile first")
        existing = conn.execute("""
            SELECT id FROM pharmacy_inventory
            WHERE pharmacy_id=%s AND lower(medicine_name)=lower(%s)
              AND lower(dosage_form)=lower(%s) AND lower(strength)=lower(%s)
              AND lower(package_label)=lower(%s)
            FOR UPDATE
        """, (profile["id"], body.medicine_name.strip(), body.dosage_form.strip(),
              body.strength.strip(), body.package_label.strip())).fetchone()
        if existing:
            held = conn.execute("""
                SELECT COALESCE(SUM(ri.quantity),0) AS quantity
                FROM pharmacy_reservation_items ri
                JOIN pharmacy_reservations r ON r.id=ri.reservation_id
                WHERE ri.inventory_id=%s AND r.status='held' AND r.expires_at > now()
            """, (existing["id"],)).fetchone()["quantity"]
            if body.stock_quantity < held:
                raise HTTPException(status_code=409, detail="Stock cannot be reduced below active reservation holds")
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
        _audit_event(conn, profile["id"], user["id"], "inventory.item.upserted", row["id"],
                     {"medicine_name": row["medicine_name"], "stock_quantity": row["stock_quantity"],
                      "unit_price": row["unit_price"], "is_active": row["is_active"]})
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
                SELECT i.medicine_name, i.dosage_form, i.strength, i.package_label,
                       i.unit_price, i.stock_quantity,
                       GREATEST(i.stock_quantity - COALESCE((
                         SELECT SUM(ri.quantity)
                         FROM pharmacy_reservation_items ri
                         JOIN pharmacy_reservations r ON r.id=ri.reservation_id
                         WHERE ri.inventory_id=i.id AND r.status='held' AND r.expires_at > now()
                       ),0),0) AS available_quantity,
                       i.updated_at
                FROM pharmacy_inventory i
                WHERE i.pharmacy_id=%s AND i.is_active=TRUE
                ORDER BY updated_at DESC, id
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
                if candidate is None or candidate["available_quantity"] < requested.quantity:
                    complete = False
                    missing.append({
                        "medicine_name": requested.medicine_name,
                        "requested_quantity": requested.quantity,
                        "available_quantity": 0 if candidate is None else candidate["available_quantity"],
                    })
                    if candidate is not None:
                        available_subtotal += candidate["unit_price"] * min(candidate["available_quantity"], requested.quantity)
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
        if row:
            _audit_event(conn, row["id"], user["id"], "pharmacy.verification.changed", row["id"],
                         {"verification_status": body.verification_status})
    if not row:
        raise HTTPException(status_code=404, detail="Pharmacy not found")
    return row


class PharmacyReservationInput(BaseModel):
    idempotency_key: UUID
    items: list[PrescriptionSearchItem] = Field(min_length=1, max_length=100)


def _reservation_payload(conn, reservation):
    lines = conn.execute("""
        SELECT medicine_name, dosage_form, strength, package_label,
               quantity, unit_price, line_total
        FROM pharmacy_reservation_items
        WHERE reservation_id=%s ORDER BY medicine_name
    """, (reservation["id"],)).fetchall()
    return {
        "id": str(reservation["id"]),
        "pharmacy_id": str(reservation["pharmacy_id"]),
        "status": reservation["status"],
        "expires_at": reservation["expires_at"],
        "created_at": reservation["created_at"],
        "confirmed_at": reservation["confirmed_at"],
        "cancelled_at": reservation["cancelled_at"],
        "items": lines,
        "total_price": sum(line["line_total"] for line in lines),
        "synthetic_data_only": settings.staging_mode,
    }


@app.post("/v1/pharmacies/{pharmacy_id}/reservations", status_code=201)
def create_pharmacy_reservation(pharmacy_id: UUID, body: PharmacyReservationInput,
                                response: Response,
                                user=Depends(require_roles("patient"))):
    request_hash = hashlib.sha256(json.dumps(
        body.model_dump(mode="json", exclude={"idempotency_key"}),
        sort_keys=True, ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")).hexdigest()
    with connect() as conn:
        existing = conn.execute("""
            SELECT * FROM pharmacy_reservations
            WHERE patient_user_id=%s AND idempotency_key=%s
        """, (user["id"], body.idempotency_key)).fetchone()
        if existing:
            if existing["request_hash"] != request_hash:
                raise HTTPException(status_code=409, detail="Idempotency key was already used for a different request")
            response.status_code = 200
            return _reservation_payload(conn, existing)

        pharmacy = conn.execute("""
            SELECT id FROM pharmacy_profiles
            WHERE id=%s AND is_published=TRUE AND verification_status='verified'
            FOR SHARE
        """, (pharmacy_id,)).fetchone()
        if not pharmacy:
            raise HTTPException(status_code=404, detail="Verified pharmacy not found")

        # Lock inventory rows in a stable order to serialize competing reservations.
        inventory = conn.execute("""
            SELECT id, medicine_name, dosage_form, strength, package_label,
                   unit_price, stock_quantity
            FROM pharmacy_inventory
            WHERE pharmacy_id=%s AND is_active=TRUE
            ORDER BY id
            FOR UPDATE
        """, (pharmacy_id,)).fetchall()

        selected = []
        seen = set()
        for requested in body.items:
            key = tuple(_norm(v) for v in (
                requested.medicine_name, requested.dosage_form,
                requested.strength, requested.package_label
            ))
            if key in seen:
                raise HTTPException(status_code=422, detail="Duplicate prescription item; combine quantities")
            seen.add(key)
            candidate = next((row for row in inventory if tuple(_norm(row[k]) for k in (
                "medicine_name", "dosage_form", "strength", "package_label"
            )) == key), None)
            if candidate is None:
                raise HTTPException(status_code=409, detail=f"Medicine unavailable: {requested.medicine_name}")
            held = conn.execute("""
                SELECT COALESCE(SUM(ri.quantity),0) AS quantity
                FROM pharmacy_reservation_items ri
                JOIN pharmacy_reservations r ON r.id=ri.reservation_id
                WHERE ri.inventory_id=%s AND r.status='held' AND r.expires_at > now()
            """, (candidate["id"],)).fetchone()["quantity"]
            available = candidate["stock_quantity"] - held
            if available < requested.quantity:
                raise HTTPException(status_code=409, detail=f"Insufficient stock: {requested.medicine_name}")
            selected.append((candidate, requested))

        reservation = conn.execute("""
            INSERT INTO pharmacy_reservations
              (pharmacy_id, patient_user_id, idempotency_key, request_hash)
            VALUES (%s,%s,%s,%s)
            ON CONFLICT (patient_user_id,idempotency_key) DO NOTHING
            RETURNING *
        """, (pharmacy_id, user["id"], body.idempotency_key, request_hash)).fetchone()
        if reservation is None:
            reservation = conn.execute("""
                SELECT * FROM pharmacy_reservations
                WHERE patient_user_id=%s AND idempotency_key=%s
            """, (user["id"], body.idempotency_key)).fetchone()
            if reservation["request_hash"] != request_hash:
                raise HTTPException(status_code=409, detail="Idempotency key was already used for a different request")
            response.status_code = 200
            return _reservation_payload(conn, reservation)

        for candidate, requested in selected:
            line_total = candidate["unit_price"] * requested.quantity
            conn.execute("""
                INSERT INTO pharmacy_reservation_items
                  (reservation_id, inventory_id, medicine_name, dosage_form,
                   strength, package_label, quantity, unit_price, line_total)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
            """, (reservation["id"], candidate["id"], candidate["medicine_name"],
                  candidate["dosage_form"], candidate["strength"], candidate["package_label"],
                  requested.quantity, candidate["unit_price"], line_total))
        _audit_event(conn, pharmacy_id, user["id"], "reservation.created", reservation["id"],
                     {"item_count": len(selected), "total_price": sum(
                         candidate["unit_price"] * requested.quantity
                         for candidate, requested in selected
                     )})
        return _reservation_payload(conn, reservation)


@app.get("/v1/pharmacies/reservations/me")
def list_patient_reservations(user=Depends(require_roles("patient"))):
    with connect() as conn:
        rows = conn.execute("""
            SELECT * FROM pharmacy_reservations
            WHERE patient_user_id=%s ORDER BY created_at DESC LIMIT 100
        """, (user["id"],)).fetchall()
        return [_reservation_payload(conn, row) for row in rows]


@app.get("/v1/pharmacies/me/reservations")
def list_pharmacy_reservations(user=Depends(require_roles("pharmacist"))):
    with connect() as conn:
        pharmacy = conn.execute(
            "SELECT id FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
        ).fetchone()
        if not pharmacy:
            return []
        rows = conn.execute("""
            SELECT * FROM pharmacy_reservations
            WHERE pharmacy_id=%s ORDER BY created_at DESC LIMIT 100
        """, (pharmacy["id"],)).fetchall()
        return [_reservation_payload(conn, row) for row in rows]


@app.post("/v1/pharmacies/reservations/{reservation_id}/confirm")
def confirm_pharmacy_reservation(reservation_id: UUID,
                                 user=Depends(require_roles("pharmacist"))):
    with connect() as conn:
        pharmacy = conn.execute(
            "SELECT id FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
        ).fetchone()
        if not pharmacy:
            raise HTTPException(status_code=404, detail="Pharmacy profile not found")
        reservation = conn.execute("""
            SELECT * FROM pharmacy_reservations
            WHERE id=%s AND pharmacy_id=%s FOR UPDATE
        """, (reservation_id, pharmacy["id"])).fetchone()
        if not reservation:
            raise HTTPException(status_code=404, detail="Reservation not found")
        if reservation["status"] != "held":
            raise HTTPException(status_code=409, detail="Reservation is not active")
        if reservation["expires_at"] <= datetime.now(timezone.utc):
            conn.execute("UPDATE pharmacy_reservations SET status='expired' WHERE id=%s",
                         (reservation_id,))
            raise HTTPException(status_code=409, detail="Reservation has expired")
        lines = conn.execute("""
            SELECT inventory_id, quantity FROM pharmacy_reservation_items
            WHERE reservation_id=%s ORDER BY inventory_id
        """, (reservation_id,)).fetchall()
        for line in lines:
            updated = conn.execute("""
                UPDATE pharmacy_inventory
                SET stock_quantity=stock_quantity-%s, updated_at=now()
                WHERE id=%s AND stock_quantity >= %s
                RETURNING id
            """, (line["quantity"], line["inventory_id"], line["quantity"])).fetchone()
            if not updated:
                raise HTTPException(status_code=409, detail="Inventory changed; reservation cannot be confirmed")
        conn.execute("""
            UPDATE pharmacy_reservations
            SET status='confirmed', confirmed_at=now()
            WHERE id=%s
        """, (reservation_id,))
        _audit_event(conn, pharmacy["id"], user["id"], "reservation.confirmed", reservation_id,
                     {"item_count": len(lines)})
        reservation = conn.execute(
            "SELECT * FROM pharmacy_reservations WHERE id=%s", (reservation_id,)
        ).fetchone()
        return _reservation_payload(conn, reservation)


@app.post("/v1/pharmacies/reservations/{reservation_id}/cancel")
def cancel_pharmacy_reservation(reservation_id: UUID,
                                user=Depends(require_roles("patient"))):
    with connect() as conn:
        reservation = conn.execute("""
            UPDATE pharmacy_reservations
            SET status='cancelled', cancelled_at=now()
            WHERE id=%s AND patient_user_id=%s AND status='held'
              AND expires_at > now()
            RETURNING *
        """, (reservation_id, user["id"])).fetchone()
        if not reservation:
            raise HTTPException(status_code=404, detail="Active reservation not found")
        _audit_event(conn, reservation["pharmacy_id"], user["id"], "reservation.cancelled",
                     reservation_id, {})
        return _reservation_payload(conn, reservation)


class PharmacyPublicationInput(BaseModel):
    is_published: bool


@app.patch("/v1/pharmacies/me/publication")
def set_my_pharmacy_publication(body: PharmacyPublicationInput,
                                user=Depends(require_roles("pharmacist"))):
    with connect() as conn:
        row = conn.execute("""
            UPDATE pharmacy_profiles
            SET is_published=%s, updated_at=now()
            WHERE user_id=%s AND verification_status='verified'
            RETURNING id, pharmacy_name, verification_status, is_published
        """, (body.is_published, user["id"])).fetchone()
        if not row:
            exists = conn.execute(
                "SELECT id FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
            ).fetchone()
            if not exists:
                raise HTTPException(status_code=404, detail="Pharmacy profile not found")
            raise HTTPException(status_code=409, detail="Pharmacy must be verified before publication")
        _audit_event(conn, row["id"], user["id"], "pharmacy.publication.changed", row["id"],
                     {"is_published": body.is_published})
        return row


@app.get("/v1/admin/pharmacies/pending")
def list_pending_pharmacies(user=Depends(require_roles("admin"))):
    with connect() as conn:
        rows = conn.execute("""
            SELECT id, user_id, pharmacy_name, address, phone, latitude, longitude,
                   verification_status, is_published, created_at, updated_at
            FROM pharmacy_profiles
            WHERE verification_status='pending'
            ORDER BY created_at ASC
            LIMIT 200
        """).fetchall()
    return rows



@app.get("/v1/pharmacies/me/activity")
def list_pharmacy_activity(user=Depends(require_roles("pharmacist"))):
    with connect() as conn:
        pharmacy = conn.execute(
            "SELECT id FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
        ).fetchone()
        if not pharmacy:
            return []
        rows = conn.execute("""
            SELECT id, actor_user_id, event_type, target_id, payload, created_at
            FROM pharmacy_audit_events
            WHERE pharmacy_id=%s
            ORDER BY created_at DESC
            LIMIT 100
        """, (pharmacy["id"],)).fetchall()
    return rows


class PharmacyOrderCreateInput(BaseModel):
    reservation_id: UUID
    patient_note: str = Field(default="", max_length=1000)


class PharmacyOrderTransitionInput(BaseModel):
    action: str = Field(pattern="^(accept|start_preparing|mark_ready|dispense|cancel)$")
    pharmacy_note: str = Field(default="", max_length=1000)


def _order_payload(conn, order):
    lines = conn.execute("""
        SELECT medicine_name, dosage_form, strength, package_label,
               quantity, unit_price, line_total
        FROM pharmacy_reservation_items
        WHERE reservation_id=%s ORDER BY medicine_name
    """, (order["reservation_id"],)).fetchall()
    return {
        "id": str(order["id"]),
        "reservation_id": str(order["reservation_id"]),
        "pharmacy_id": str(order["pharmacy_id"]),
        "patient_user_id": str(order["patient_user_id"]),
        "status": order["status"],
        "patient_note": order["patient_note"],
        "pharmacy_note": order["pharmacy_note"],
        "submitted_at": order["submitted_at"],
        "accepted_at": order["accepted_at"],
        "preparing_at": order["preparing_at"],
        "ready_at": order["ready_at"],
        "dispensed_at": order["dispensed_at"],
        "cancelled_at": order["cancelled_at"],
        "updated_at": order["updated_at"],
        "items": lines,
        "total_price": sum(line["line_total"] for line in lines),
        "synthetic_data_only": settings.staging_mode,
    }


@app.post("/v1/pharmacies/orders", status_code=201)
def create_pharmacy_order(body: PharmacyOrderCreateInput, response: Response,
                           user=Depends(require_roles("patient"))):
    with connect() as conn:
        reservation = conn.execute("""
            SELECT * FROM pharmacy_reservations
            WHERE id=%s AND patient_user_id=%s
            FOR UPDATE
        """, (body.reservation_id, user["id"])).fetchone()
        if not reservation:
            raise HTTPException(status_code=404, detail="Reservation not found")
        existing = conn.execute(
            "SELECT * FROM pharmacy_orders WHERE reservation_id=%s",
            (body.reservation_id,)
        ).fetchone()
        if existing:
            response.status_code = 200
            return _order_payload(conn, existing)
        if reservation["status"] != "held" or reservation["expires_at"] <= datetime.now(timezone.utc):
            raise HTTPException(status_code=409, detail="Only an active reservation can become an order")
        order = conn.execute("""
            INSERT INTO pharmacy_orders
              (reservation_id, pharmacy_id, patient_user_id, patient_note)
            VALUES (%s,%s,%s,%s)
            RETURNING *
        """, (reservation["id"], reservation["pharmacy_id"], user["id"],
              body.patient_note.strip())).fetchone()
        _audit_event(conn, reservation["pharmacy_id"], user["id"], "order.submitted",
                     order["id"], {"reservation_id": str(reservation["id"])})
        pharmacy_owner = conn.execute(
            "SELECT user_id FROM pharmacy_profiles WHERE id=%s", (reservation["pharmacy_id"],)
        ).fetchone()
        if pharmacy_owner:
            _notify(conn, pharmacy_owner["user_id"], user["id"], "order.submitted",
                    "سفارش جدید", "یک سفارش جدید برای بررسی ثبت شده است.",
                    "pharmacy_order", order["id"])
        return _order_payload(conn, order)


@app.get("/v1/pharmacies/orders/me")
def list_my_pharmacy_orders(user=Depends(require_roles("patient"))):
    with connect() as conn:
        orders = conn.execute("""
            SELECT * FROM pharmacy_orders
            WHERE patient_user_id=%s ORDER BY submitted_at DESC LIMIT 100
        """, (user["id"],)).fetchall()
        return [_order_payload(conn, order) for order in orders]


@app.get("/v1/pharmacies/me/orders")
def list_incoming_pharmacy_orders(user=Depends(require_roles("pharmacist"))):
    with connect() as conn:
        pharmacy = conn.execute(
            "SELECT id FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
        ).fetchone()
        if not pharmacy:
            return []
        orders = conn.execute("""
            SELECT * FROM pharmacy_orders
            WHERE pharmacy_id=%s ORDER BY submitted_at DESC LIMIT 100
        """, (pharmacy["id"],)).fetchall()
        return [_order_payload(conn, order) for order in orders]


@app.post("/v1/pharmacies/orders/{order_id}/transition")
def transition_pharmacy_order(order_id: UUID, body: PharmacyOrderTransitionInput,
                              user=Depends(current_user)):
    if user["role"] not in {"patient", "pharmacist"}:
        raise HTTPException(status_code=403, detail="Insufficient role")
    with connect() as conn:
        order = conn.execute(
            "SELECT * FROM pharmacy_orders WHERE id=%s FOR UPDATE",
            (order_id,)
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        if body.action == "dispense":
            if user["role"] != "patient" or str(order["patient_user_id"]) != str(user["id"]):
                raise HTTPException(status_code=403, detail="Only the ordering patient can confirm pickup")
            if order["status"] != "ready":
                raise HTTPException(status_code=409, detail="Order is not ready for pickup")
            new_status = "dispensed"
            conn.execute("""
                UPDATE pharmacy_orders SET status='dispensed', dispensed_at=now(),
                  updated_at=now() WHERE id=%s
            """, (order_id,))
            _audit_event(conn, order["pharmacy_id"], user["id"], "order.dispensed",
                         order_id, {})
            _notify(conn, order["patient_user_id"], user["id"], "order.dispensed",
                    "تحویل سفارش ثبت شد", "دریافت سفارش شما ثبت شد.",
                    "pharmacy_order", order_id)
        elif body.action == "cancel":
            if user["role"] == "patient":
                if str(order["patient_user_id"]) != str(user["id"]) or order["status"] != "submitted":
                    raise HTTPException(status_code=403, detail="Patient can cancel only an unaccepted order")
            else:
                pharmacy = conn.execute(
                    "SELECT id FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
                ).fetchone()
                if not pharmacy or str(pharmacy["id"]) != str(order["pharmacy_id"]):
                    raise HTTPException(status_code=403, detail="Order belongs to another pharmacy")
                if order["status"] not in {"submitted", "accepted", "preparing", "ready"}:
                    raise HTTPException(status_code=409, detail="Order cannot be cancelled")
            if order["status"] in {"accepted", "preparing", "ready"}:
                lines = conn.execute("""
                    SELECT inventory_id, quantity FROM pharmacy_reservation_items
                    WHERE reservation_id=%s ORDER BY inventory_id
                """, (order["reservation_id"],)).fetchall()
                for line in lines:
                    conn.execute("""
                        UPDATE pharmacy_inventory
                        SET stock_quantity=stock_quantity+%s, updated_at=now()
                        WHERE id=%s
                    """, (line["quantity"], line["inventory_id"]))
            conn.execute("""
                UPDATE pharmacy_reservations SET status='cancelled', cancelled_at=now()
                WHERE id=%s AND status IN ('held','confirmed')
            """, (order["reservation_id"],))
            conn.execute("""
                UPDATE pharmacy_orders SET status='cancelled', cancelled_at=now(),
                  pharmacy_note=%s, updated_at=now() WHERE id=%s
            """, (body.pharmacy_note.strip(), order_id))
            _audit_event(conn, order["pharmacy_id"], user["id"], "order.cancelled",
                         order_id, {"previous_status": order["status"]})
            _notify(conn, order["patient_user_id"], user["id"], "order.cancelled",
                    "سفارش لغو شد", "وضعیت سفارش شما به لغوشده تغییر کرد.",
                    "pharmacy_order", order_id)
        else:
            if user["role"] != "pharmacist":
                raise HTTPException(status_code=403, detail="Only the pharmacy can change fulfilment status")
            pharmacy = conn.execute(
                "SELECT id FROM pharmacy_profiles WHERE user_id=%s", (user["id"],)
            ).fetchone()
            if not pharmacy or str(pharmacy["id"]) != str(order["pharmacy_id"]):
                raise HTTPException(status_code=403, detail="Order belongs to another pharmacy")
            transitions = {
                ("submitted", "accept"): "accepted",
                ("accepted", "start_preparing"): "preparing",
                ("preparing", "mark_ready"): "ready",
            }
            new_status = transitions.get((order["status"], body.action))
            if not new_status:
                raise HTTPException(status_code=409, detail="Invalid order status transition")
            if body.action == "accept":
                reservation = conn.execute("""
                    SELECT * FROM pharmacy_reservations WHERE id=%s FOR UPDATE
                """, (order["reservation_id"],)).fetchone()
                if reservation["status"] != "held" or reservation["expires_at"] <= datetime.now(timezone.utc):
                    raise HTTPException(status_code=409, detail="Reservation expired before pharmacy acceptance")
                lines = conn.execute("""
                    SELECT inventory_id, quantity FROM pharmacy_reservation_items
                    WHERE reservation_id=%s ORDER BY inventory_id
                """, (order["reservation_id"],)).fetchall()
                for line in lines:
                    updated = conn.execute("""
                        UPDATE pharmacy_inventory SET stock_quantity=stock_quantity-%s,
                          updated_at=now()
                        WHERE id=%s AND stock_quantity >= %s RETURNING id
                    """, (line["quantity"], line["inventory_id"], line["quantity"])).fetchone()
                    if not updated:
                        raise HTTPException(status_code=409, detail="Inventory changed; cannot accept order")
                conn.execute("""
                    UPDATE pharmacy_reservations SET status='confirmed', confirmed_at=now()
                    WHERE id=%s
                """, (order["reservation_id"],))
                timestamp_field = "accepted_at"
            elif body.action == "start_preparing":
                timestamp_field = "preparing_at"
            else:
                timestamp_field = "ready_at"
            conn.execute(f"""
                UPDATE pharmacy_orders SET status=%s, {timestamp_field}=now(),
                  pharmacy_note=%s, updated_at=now() WHERE id=%s
            """, (new_status, body.pharmacy_note.strip(), order_id))
            _audit_event(conn, order["pharmacy_id"], user["id"], f"order.{new_status}",
                         order_id, {})
            patient_messages = {
                "accepted": ("سفارش پذیرفته شد", "داروخانه سفارش شما را پذیرفته است."),
                "preparing": ("سفارش در حال آماده‌سازی", "آماده‌سازی سفارش شما آغاز شده است."),
                "ready": ("سفارش آماده تحویل است", "برای دریافت سفارش با داروخانه هماهنگ کنید."),
            }
            title, message = patient_messages[new_status]
            _notify(conn, order["patient_user_id"], user["id"], f"order.{new_status}",
                    title, message, "pharmacy_order", order_id)
        updated_order = conn.execute(
            "SELECT * FROM pharmacy_orders WHERE id=%s", (order_id,)
        ).fetchone()
        return _order_payload(conn, updated_order)



@app.post("/v1/admin/maintenance/expire-reservations")
def expire_reservations(user=Depends(require_roles("admin"))):
    with connect() as conn:
        row = conn.execute(
            "SELECT expire_pharmacy_reservations(%s) AS expired_count", (500,)
        ).fetchone()
    return {"expired_count": row["expired_count"], "synthetic_data_only": settings.staging_mode}
