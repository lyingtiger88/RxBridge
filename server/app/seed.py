import os, sys, psycopg
from argon2 import PasswordHasher
url=os.environ["DATABASE_URL"]
password=os.environ.get("DEMO_SEED_PASSWORD","")
if len(password)<14:
 print("Set a unique DEMO_SEED_PASSWORD (14+ chars); refusing to seed.",file=sys.stderr); raise SystemExit(2)
hashed=PasswordHasher().hash(password)
users=[("admin01","admin","مدیر آزمایشی"),("doctor01","doctor","پزشک نمونه ۱"),("doctor02","doctor","پزشک نمونه ۲"),("patient01","patient","بیمار نمونه ۱"),("patient02","patient","بیمار نمونه ۲"),("pharmacy01","pharmacist","داروساز نمونه"),("insurer01","insurer","کارشناس بیمه نمونه"),("lab01","laboratory","آزمایشگاه نمونه")]
with psycopg.connect(url) as db:
 for username,role,name in users:
  db.execute("INSERT INTO app_users(username,password_hash,role,display_name) VALUES (%s,%s,%s,%s) ON CONFLICT(username) DO NOTHING",(username,hashed,role,name))
 db.execute("INSERT INTO demo_patients(display_code,display_name) VALUES ('PATIENT-DEMO-001','بیمار ساختگی ۰۰۱'),('PATIENT-DEMO-002','بیمار ساختگی ۰۰۲') ON CONFLICT(display_code) DO NOTHING")
print("Synthetic accounts seeded. Rotate passwords before inviting testers.")
