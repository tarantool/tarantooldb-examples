FROM golang:1.23

WORKDIR /traffic_encryption/go

COPY . .

RUN apt-get update && apt-get install -y libssl-dev
RUN go mod download && go mod verify
RUN go build -o main

CMD ["./main"]
