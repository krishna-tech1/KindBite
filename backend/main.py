from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from otp import send_otp, verify_otp
import uvicorn

app = FastAPI()

@app.middleware("http")
async def log_requests(request: Request, call_next):
    print(f"Request: {request.method} {request.url.path}")
    response = await call_next(request)
    return response

@app.get("/")
def read_root():
    return {"status": "Backend is running"}

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PhoneRequest(BaseModel):
    phone: str

class VerifyOtpRequest(BaseModel):
    phone: str
    otp: int

@app.post("/send-otp")
def send_otp_api(data: PhoneRequest):
    try:
        send_otp(data.phone)
        return {"message": "OTP sent"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/verify-otp")
def verify_otp_api(data: VerifyOtpRequest):
    return verify_otp(data.phone, data.otp)

@app.api_route("/{path_name:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def catch_all(request: Request, path_name: str):
    return {
        "error": "Path not found",
        "requested_path": path_name,
        "method": request.method,
        "available_routes": ["/", "/send-otp", "/verify-otp", "/docs"]
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
