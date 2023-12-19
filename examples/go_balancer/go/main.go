package main

import (
	"context"
	"log"
	"math/rand"
	"time"

	"github.com/tarantool/go-tarantool/v2"
	"github.com/tarantool/go-tarantool/v2/crud"
	"github.com/tarantool/go-tarantool/v2/pool"
)

const USER = "admin"
const PASS = "secret"
const LETTER_BYTES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

var routerUriList = []string{"localhost:3301", "localhost:3302"}

type Tuple struct {
	_msgpack struct{} `msgpack:",asArray"` //nolint: structcheck,unused
	Id       uint     `msgpack:"id"`
	BucketId *uint    `msgpack:"bucket_id"`
	Too      uint     `msgpack:"too"`
	Foo      string   `msgpack:"foo"`
}

func RandStringBytes(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = LETTER_BYTES[rand.Intn(len(LETTER_BYTES))]
	}
	return string(b)
}

func MakeRandomTuple() Tuple {
	return Tuple{
		Id:       uint(rand.Intn(1e6)),
		BucketId: nil,
		Too:      uint(rand.Intn(1e4)),
		Foo:      RandStringBytes(rand.Intn(32)),
	}
}

func WriteOverCrud(routerPool *pool.ConnectionPool) {
	tuple := MakeRandomTuple()
	req := crud.MakeReplaceRequest("test").Tuple(tuple)
	ret := crud.Result{}
	err := routerPool.Do(req, pool.ANY).GetTyped(&ret)
	if err != nil {
		log.Printf("Failed to execute request: %s\n", err)
		return
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	dialersMap := map[string]tarantool.Dialer{}
	for _, uri := range routerUriList {
		dialersMap[uri] = tarantool.NetDialer{
			Address:  uri,
			User:     USER,
			Password: PASS,
		}
	}

	connOpts := tarantool.Opts{}
	routerPool, err := pool.Connect(ctx, dialersMap, connOpts)
	if err != nil || routerPool == nil {
		log.Fatalln("ConnectionPool is not established:", err)
	}
	defer routerPool.Close()

	log.Printf("To finish the job, press Ctrl+Z\n")

	for {
		WriteOverCrud(routerPool)
	}
}
