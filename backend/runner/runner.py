

import base64
import contextlib
import os
import sys
import traceback
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
MAX_OUTPUT_SIZE = 100_000


class LimitedOutput:
    def __init__(self, limit):
        self.limit = limit
        self.parts = []
        self.size = 0
        self.truncated = False

    def write(self, text):
        remaining = self.limit - self.size

        if remaining > 0:
            saved = text[:remaining]
            self.parts.append(saved)
            self.size += len(saved)

        if len(text) > remaining:
            self.truncated = True

        return len(text)

    def flush(self):
        pass

    def getvalue(self):
        result = "".join(self.parts)

        if self.truncated:
            result += "\n[Output truncated]"

        return result


def main():
    stdout_buffer = LimitedOutput(MAX_OUTPUT_SIZE)
    stderr_buffer = LimitedOutput(MAX_OUTPUT_SIZE)
    exit_code = 0

    try:
        encoded_code = os.environ.get("USER_CODE_B64")

        if not encoded_code:
            raise ValueError("Python code was not provided.")

        source_code = base64.b64decode(
            encoded_code,
            validate=True
        ).decode("utf-8")

        compiled_code = compile(
            source_code,
            "<user_code>",
            "exec"
        )

        with contextlib.redirect_stdout(stdout_buffer):
            with contextlib.redirect_stderr(stderr_buffer):
                exec(compiled_code, {"__name__": "__main__"})

    except BaseException:
        exit_code = 1
        traceback.print_exc(file=stderr_buffer)

    sys.stdout.write(stdout_buffer.getvalue())
    sys.stderr.write(stderr_buffer.getvalue())

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
