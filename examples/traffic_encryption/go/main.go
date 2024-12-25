package main

import (
	"context"
	"fmt"
	"time"

	"github.com/tarantool/go-tarantool/v2"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	dialer := tarantool.OpenSslDialer{
		Address:     "tarantool-router-msk:3301",
		User:        "admin",
		Password:    "secret-cluster-cookie",
		SslKeyFile:  "./certs/client-key.pem",
		SslCertFile: "./certs/client-cert.pem",
		SslCaFile:   "./certs/ca-cert.pem",
		SslPassword: "54321",
	}

	opts := tarantool.Opts{}

	conn, err := tarantool.Connect(ctx, dialer, opts)
	if err != nil {
		fmt.Println(err)
		return
	}

	fmt.Println(conn.Greeting.Version)

	conn.CloseGraceful()

	return
}
