FROM python:3

WORKDIR /traffic_encryption/python

COPY . .

RUN apt-get update && apt-get install libssl-dev
RUN pip install --no-cache-dir -r requirements.txt

CMD [ "python", "./connect.py" ]
