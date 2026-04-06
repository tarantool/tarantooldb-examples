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

const (
	USER         = "admin"
	PASS         = "secret-cluster-cookie"
	LETTER_BYTES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
)

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

	instances := make([]pool.Instance, 0, len(routerUriList))
	connOpts := tarantool.Opts{}
	for _, uri := range routerUriList {
		instances = append(instances, pool.Instance{
			Name: uri,
			Dialer: tarantool.NetDialer{
				Address:  uri,
				User:     USER,
				Password: PASS,
			},
			Opts: connOpts,
		})
	}

	routerPool, err := pool.ConnectWithOpts(ctx, instances, pool.Opts{CheckTimeout: time.Second})
	if err != nil || routerPool == nil {
		log.Fatalln("ConnectionPool is not established:", err)
	}
	defer routerPool.Close()

	log.Printf("To finish the job, press Ctrl+Z\n")

	for {
		WriteOverCrud(routerPool)
	}
}
