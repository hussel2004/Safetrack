from app.core import security
try:
    hash_val = "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIeWIvJ3Jm"
    pwd = "admin123"
    result = security.verify_password(pwd, hash_val)
    with open("verification_result.txt", "w") as f:
        f.write(f"RESULT: {result}")
except Exception as e:
    with open("verification_result.txt", "w") as f:
        f.write(f"ERROR: {e}")
