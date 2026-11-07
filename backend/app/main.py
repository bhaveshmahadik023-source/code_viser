
import base64
import time

import docker
from docker.errors import DockerException, ImageNotFound
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.models import ExecutionRequest, ExecutionResponse


# --------------------------------------------------
# FASTAPI APPLICATION
# --------------------------------------------------

app = FastAPI(
    title="Code Visualizer API",
    description="Backend for executing and visualizing Python code.",
    version="1.0.0"
)


# --------------------------------------------------
# CORS CONFIGURATION
# Allows Flutter Web running on localhost or 127.0.0.1
# --------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --------------------------------------------------
# DOCKER RUNNER IMAGE
# --------------------------------------------------

RUNNER_IMAGE = "codevisualizer-runner:dev"


# --------------------------------------------------
# HOME ROUTE
# --------------------------------------------------

@app.get("/")
def home():
    return {
        "message": "Welcome to Code Visualizer API",
        "status": "running"
    }


# --------------------------------------------------
# HEALTH CHECK
# --------------------------------------------------

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "Python Execution Backend"
    }


# --------------------------------------------------
# PYTHON CODE EXECUTION
# --------------------------------------------------

@app.post("/execute", response_model=ExecutionResponse)
def execute_code(request: ExecutionRequest):

    start_time = time.perf_counter()
    container = None

    try:

        # Connect to Docker.
        client = docker.from_env()

        # Encode user code.
        encoded_code = base64.b64encode(
            request.code.encode("utf-8")
        ).decode("ascii")

        # Create isolated execution container.
        container = client.containers.run(
            image=RUNNER_IMAGE,
            detach=True,

            environment={
                "USER_CODE_B64": encoded_code
            },

            # Disable network access.
            network_disabled=True,

            # Resource restrictions.
            mem_limit="128m",
            nano_cpus=500_000_000,
            pids_limit=32,

            # Container restrictions.
            read_only=True,
            tmpfs={
                "/tmp": "rw,noexec,nosuid,size=16m"
            },
            cap_drop=["ALL"],
            security_opt=["no-new-privileges:true"],
            user="10001:10001",

            labels={
                "app": "codevisualizer",
                "purpose": "python-execution"
            }
        )

        # Wait for execution.
        try:

            result = container.wait(
                timeout=request.timeout
            )

        except Exception:

            container.kill()

            return ExecutionResponse(
                success=False,
                output="",
                error=(
                    f"Execution timed out after "
                    f"{request.timeout} seconds."
                ),
                execution_time=round(
                    time.perf_counter() - start_time,
                    4
                )
            )

        # Read execution output.
        logs = container.logs(
            stdout=True,
            stderr=True
        ).decode(
            "utf-8",
            errors="replace"
        )

        exit_code = result.get("StatusCode", 1)

        # Return result.
        return ExecutionResponse(
            success=(exit_code == 0),

            output=(
                logs if exit_code == 0 else ""
            ),

            error=(
                logs if exit_code != 0 else ""
            ),

            execution_time=round(
                time.perf_counter() - start_time,
                4
            )
        )

    except ImageNotFound:

        raise HTTPException(
            status_code=500,
            detail="Python runner image was not found."
        )

    except DockerException:

        raise HTTPException(
            status_code=503,
            detail="Docker execution service is unavailable."
        )

    finally:

        # Always remove execution container.
        if container is not None:

            try:
                container.remove(force=True)

            except DockerException:
                pass
