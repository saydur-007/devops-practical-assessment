import time
import uuid
import json
from typing import Callable

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse

app = FastAPI()
SERVICE_NAME = "service-b"


def _now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime()) + "Z"


@app.middleware("http")
async def log_requests(request: Request, call_next: Callable):
    # reuse client X-Request-ID if provided, else generate
    request_id = request.headers.get("X-Request-ID") or request.headers.get("x-request-id") or str(uuid.uuid4())
    start = time.time()
    try:
        response: Response = await call_next(request)
        status_code = response.status_code
    except Exception as exc:  # pragma: no cover - intentionally surface 5xx
        status_code = 500
        log_obj = {
            "timestamp": _now_iso(),
            "level": "error",
            "service": SERVICE_NAME,
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": status_code,
            "message": str(exc),
        }
        print(json.dumps(log_obj), flush=True)
        raise
    finally:
        duration_ms = int((time.time() - start) * 1000)
        log_obj = {
            "timestamp": _now_iso(),
            "level": "info" if status_code < 500 else "error",
            "service": SERVICE_NAME,
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": status_code,
            "duration_ms": duration_ms,
            "message": "request completed",
        }
        print(json.dumps(log_obj), flush=True)

    # attach request id to response
    response.headers["X-Request-ID"] = request_id
    return response


@app.get("/api/v2/health")
async def health():
    return {"status": "healthy", "service": SERVICE_NAME}


@app.get("/api/v2/orders")
async def orders():
    orders_list = [
        {"id": 1, "item": "Laptop", "status": "completed"},
        {"id": 2, "item": "Keyboard", "status": "pending"},
    ]
    return {"service": SERVICE_NAME, "orders": orders_list}


@app.get("/api/v2/error")
async def error_endpoint(request: Request):
    # Log the error and return 500
    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    log_obj = {
        "timestamp": _now_iso(),
        "level": "error",
        "service": SERVICE_NAME,
        "request_id": request_id,
        "method": request.method,
        "path": request.url.path,
        "status_code": 500,
        "message": "intentional error for testing",
    }
    print(json.dumps(log_obj), flush=True)
    return JSONResponse(status_code=500, content={"error": "internal server error"})


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8000, log_level="info")
