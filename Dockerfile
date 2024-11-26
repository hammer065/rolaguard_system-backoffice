# Use an official Python runtime as a parent image
FROM python:3.6-slim-buster

LABEL version="1.0"

# Set the working directory
WORKDIR "/iot_home"

# Copy requirements file to install dependencies
# Dockers layer caching and skips installing Python requirements if the requirements.txt file does not change
COPY ./requirements.txt ./

# Install any needed packages specified in requirements.txt
RUN apt-get update \
  && apt-get install -y cron \
  && pip install --upgrade pip \
  && pip install --upgrade --trusted-host pypi.python.org --no-cache-dir --timeout 1900 -r requirements.txt \
  && find /usr/local/ \( -type d -a -name test -o -name tests \) -o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -delete \
  && apt-get clean autoclean \
  && apt-get autopurge -y \
  && rm -rf /var/lib/apt/lists/*

# Copy the current directory contents into the container at /iot_home
COPY . .

# Define environment variable
ENV PYTHONPATH="/iot_home"
ENV PATH="/iot_home:"$PATH 
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

ENTRYPOINT sh crontab.sh
