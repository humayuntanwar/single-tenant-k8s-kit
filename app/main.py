import os
import socket

from fastapi import FastAPI, HTTPException

app = FastAPI()


# COnfig comes from enviornment variables, so one iamge serves every customer

TENANT  = os.getenv("TENANT_NAME","unset")
VERSION = os.getenv("APP_VERSION","dev")
ALLOW_CRASH =os.getenv("ALLOW_CRASH","false").lower() == "true"

@app.get("/")
def whoami():
    return{"tenant":TENANT,"pod":socket.gethostname(),"version":VERSION}


@app.get("/healthz")
def healthz():
    #liveness: only "is the process alive?" keep it simple
    return {"status":"ok"}

@app.get("/readyz")
def readyz():
    # Readiness: "can I take traffic?" Dependency checks would go here
    return {"status":"ready"}

@app.post("/crash")
def crash():
    #drill only, off unless ALLOW_CRASH=true
    if not ALLOW_CRASH:
        raise HTTPException(status_code=404)
    os._exit(1)