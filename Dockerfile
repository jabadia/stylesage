FROM python:3.7-slim

ENV DOCKERIZE_VERSION v0.6.1

RUN pip install pipenv && \
    mkdir -p /app

ENV PROJECT_DIR /app

WORKDIR ${PROJECT_DIR}

COPY Pipfile Pipfile.lock ${PROJECT_DIR}/

RUN pipenv install --system --deploy

USER 1000

COPY --chown=1000 iotd .
