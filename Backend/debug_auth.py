import os
import sys
# Add current directory to path to ensure we can import app
sys.path.append(os.getcwd())

from app.core import security

print(f"CWD: {os.getcwd()}")
try:
    print(f"Files: {os.listdir('.')}")
except:
    pass

hash_from_db = "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIeWIvJ3Jm"
pwd = "admin123"

print(f"Validating '{pwd}' against '{hash_from_db}'")

try:
    res = security.verify_password(pwd, hash_from_db)
    print(f"Security verify result: {res}")
except Exception as e:
    print(f"Security verify error: {e}")

# Also check directly with passlib
from passlib.context import CryptContext
try:
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    res2 = pwd_context.verify(pwd, hash_from_db)
    print(f"Passlib verify result: {res2}")
except Exception as e:
    print(f"Passlib verify error: {e}")
