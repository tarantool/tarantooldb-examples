FROM golang:1.21.1

WORKDIR /traffic_encryption/go

COPY . .

RUN apt-get update && apt-get -y install libssl-dev
RUN go mod download && go mod verify
RUN go build -o main

CMD ["./main"]
