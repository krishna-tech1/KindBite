import os
import random
from twilio.rest import Client
from dotenv import load_dotenv
load_dotenv()  # 🔥 loads .env

account_sid = os.getenv("TWILIO_ACCOUNT_SID")
auth_token = os.getenv("TWILIO_AUTH_TOKEN")
TWILIO_PHONE = os.getenv("TWILIO_PHONE_NUMBER")

print(f"Twilio Config: SID={account_sid[:5] if account_sid else 'None'}..., Phone={TWILIO_PHONE}")

client = Client(account_sid, auth_token)

# TEMP STORE (use Redis/DB later)
otp_store = {}

def send_otp(phone: str):
    otp = random.randint(100000, 999999)
    otp_store[phone] = otp

    message = client.messages.create(
        body=f"Your KindBite OTP is {otp}",
        from_=TWILIO_PHONE,
        to=phone
    )
    return True

def verify_otp(phone: str, otp: int):
    saved_otp = otp_store.get(phone)
    if not saved_otp:
        return {"success": False, "message": "OTP expired or not found"}
    if saved_otp == otp:
        del otp_store[phone]  # clear after success
        return {"success": True, "message": "OTP verified"}
    return {"success": False, "message": "Invalid OTP"}
