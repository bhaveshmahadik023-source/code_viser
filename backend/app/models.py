
from pydantic import BaseModel, Field
from typing import Any


class ExecutionRequest(BaseModel):
    code: str = Field(
        ...,
        min_length=1,
        max_length=10000,
        description="Python source code submitted by the user"
    )

    timeout: int = Field(
        default=5,
        ge=1,
        le=10,
        description="Maximum execution time in seconds"
    )


class ExecutionEvent(BaseModel):
    event_id: int
    event_type: str
    line_number: int
    variables: dict[str, Any] = {}
    output: str = ""


class ExecutionResponse(BaseModel):
    success: bool

    output: str = ""

    error: str = ""

    execution_time: float = 0.0

    events: list[ExecutionEvent] = []
