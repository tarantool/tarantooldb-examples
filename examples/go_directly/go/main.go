package main

import (
	"context"
	"fmt"
	"math/rand"
	"time"

	"github.com/tarantool/go-tarantool/v2"
)

const (
	DATA_QTY     = 10000
	LETTER_BYTES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	TT_HOST      = "127.0.0.1"
	TT_PORT      = "3301"
	TT_USER      = "admin"
	TT_PASS      = "secret-cluster-cookie"
)

type Tuple struct {
	// Instruct msgpack to pack this struct as array, so no custom packer
	// is needed.
	_msgpack struct{} `msgpack:",asArray"` //nolint: structcheck,unused
	Id       uint
	Too      uint
	Foo      string
}

func RandStringBytes(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = LETTER_BYTES[rand.Intn(len(LETTER_BYTES))]
	}
	return string(b)
}

func TruncateSpace(conn *tarantool.Connection) {
	request := tarantool.NewCallRequest("box.space.test:truncate")
	_, err := conn.Do(request).Get()
	if err != nil {
		fmt.Printf("error in do truncate request is %s\n", err.Error())
		return
	}
}

func WritePerOne(conn *tarantool.Connection) {
	TruncateSpace(conn)

	for i := 0; i < DATA_QTY; i++ {
		id := uint(i + 1)
		too := uint(rand.Intn(100))
		foo := RandStringBytes(rand.Intn(100))

		req := tarantool.NewInsertRequest("test").Tuple([]interface{}{id, too, foo})
		_, err := conn.Do(req).Get()
		if err != nil {
			fmt.Printf("insert error %s\n", err.Error())
		}
	}
}

func ReadOne(conn *tarantool.Connection, id int) {
	var tuples []Tuple
	key := []interface{}{id}
	req := tarantool.NewSelectRequest("test").Limit(1).Key(key)
	err := conn.Do(req).GetTyped(&tuples)
	if err != nil {
		fmt.Printf("Error %s\n", err)
	} else {
		fmt.Printf("Tuples %v\n", tuples)
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	dialer := tarantool.NetDialer{
		Address:  TT_HOST + ":" + TT_PORT,
		User:     TT_USER,
		Password: TT_PASS,
	}
	opts := tarantool.Opts{}

	conn, err := tarantool.Connect(ctx, dialer, opts)
	if err != nil {
		fmt.Println(err)
		return
	}

	start := time.Now()
	WritePerOne(conn)
	fmt.Printf("Directly recorded %d rows one at a time in %v\n", DATA_QTY, time.Since(start))

	ReadOne(conn, 1)
}
