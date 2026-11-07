FROM python:3.12-slim

WORKDIR /code

COPY runner.py /code/runner.py

RUN useradd --create-home --uid 10001 runner

USER 10001:10001

ENTRYPOINT ["python", "-I", "/code/runner.py"]