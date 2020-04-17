# Use an official Python runtime as a parent image
FROM python:3.6.10-slim-buster

LABEL version="1.0"

# Set the working directory
ARG WORK_DIR="/iot_home"
WORKDIR ${WORK_DIR}

# Copy requirements file to install dependencies
# Docker’s layer caching and skips installing Python requirements if the requirements.txt file does not change
COPY requirements.txt ${WORK_DIR}

# Install any needed packages specified in requirements.txt
RUN apt-get update \
  && pip install --upgrade pip \
  && pip install --no-cache-dir --trusted-host pypi.python.org -r requirements.txt \
  && find /usr/local/ \( -type d -a -name test -o -name tests \) -o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -delete

# Copy the current directory contents into the container at /app
COPY . ${WORK_DIR}

# Define environment variable
ENV PYTHONPATH=${WORK_DIR}
ENV PATH=${WORK_DIR}":"$PATH 
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1


