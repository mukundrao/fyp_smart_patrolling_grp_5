FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .

# Use apt-get directly, no sudo
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    python3-dev \
    libgl1-mesa-glx \
    libglu1-mesa \
    libxcb-xinerama0 \
    qt5-qmake \
    qtbase5-dev \
    qtbase5-dev-tools \
    && rm -rf /var/lib/apt/lists/*  # Clean up

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "anpr_reciever7.py"]
