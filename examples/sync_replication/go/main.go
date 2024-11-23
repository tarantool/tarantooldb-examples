package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"time"

	"github.com/go-faker/faker/v4"
	"github.com/tarantool/go-tarantool/v2"
	"github.com/tarantool/go-tarantool/v2/crud"
	"github.com/tarantool/go-tarantool/v2/pool"
)

const (
	USER    = "admin"
	PASS    = "secret-cluster-cookie"
	STREAMS = 120
)

var routerUriList = []string{"localhost:3301", "localhost:3302"}

type FakeData struct {
	UUID      string `faker:"uuid_hyphenated"`
	Paragraph string `faker:"paragraph"`
}

type Tuple struct {
	_msgpack struct{} `msgpack:",asArray"` //nolint: structcheck,unused
	Id       string   `msgpack:"uuid"`
	BucketId *uint    `msgpack:"bucket_id"`
	Too      uint     `msgpack:"user_id"`
	Foo      string   `msgpack:"payload"`
}

func MakeRandomTuple(random *rand.Rand) Tuple {
	fakeData := FakeData{}
	err := faker.FakeData(&fakeData)
	if err != nil {
		fmt.Println(err)
	}
	tuple := Tuple{
		Id:       fakeData.UUID,
		BucketId: nil,
		Too:      uint(random.Int63()),
		Foo:      fakeData.Paragraph,
	}
	fmt.Println(tuple)
	return tuple
}

func WriteOverCrud(routerPool *pool.ConnectionPool, space string, random *rand.Rand) {
	tuple := MakeRandomTuple(random)
	req := crud.MakeInsertRequest(space).Tuple(tuple)
	ret := crud.Result{}
	err := routerPool.Do(req, pool.ANY).GetTyped(&ret)
	if err != nil {
		log.Printf("Failed to execute request: %s\n", err)
		return
	}
}

func InfinityLoad(routerPool *pool.ConnectionPool, mode string, random *rand.Rand) {
	var space string
	switch mode {
	case "sync":
		space = "sync_space"
	case "async":
		space = "async_space"
	default:
		fmt.Println("Неизвестное значение аргумента. Используйте target=sync или target=async.")
		return
	}
	for {
		WriteOverCrud(routerPool, space, random)
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Пожалуйста, укажите аргумент target=sync или target=async.")
		return
	}

	var mode string

	for _, arg := range os.Args {
		if strings.HasPrefix(arg, "target=") {
			mode = strings.TrimPrefix(arg, "target=")
		}
	}

	fmt.Println("mode", mode)

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
	sourceRandom := rand.NewSource(time.Now().UnixNano())
	random := rand.New(sourceRandom)
	for i := 0; i < STREAMS; i++ {
		go InfinityLoad(routerPool, mode, random)
	}

	log.Printf("To finish the job, press Ctrl+Z\n")

	for {
		time.Sleep(time.Second)
	}
}
