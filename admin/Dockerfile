FROM python:3.12-alpine

WORKDIR /app

RUN pip install --no-cache-dir django psycopg2-binary

COPY . .

EXPOSE 8000

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]