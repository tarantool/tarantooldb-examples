package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"syscall"
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

type Tuple struct {
	Id       string
	BucketId *uint
	Too      int64
	Foo      string
}

type Loader struct {
	pool   *pool.ConnectionPool
	space  string
	random *rand.Rand
}

func MakeRandomTuple(r *rand.Rand) Tuple {
	return Tuple{
		Id:  faker.UUIDHyphenated(),
		Too: r.Int63(),
		Foo: faker.Paragraph(),
	}
}

func (l *Loader) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		default:
			tuple := MakeRandomTuple(l.random)
			req := crud.MakeInsertRequest(l.space).Tuple(tuple)

			_, err := l.pool.Do(req, pool.ANY).Get()
			if err != nil {
				if ctx.Err() == nil {
					log.Printf("Insert error: %v", err)
				}
			}
		}
	}
}

func main() {
	modePtr := flag.String("target", "", "Target space: sync or async")
	flag.Parse()

	if *modePtr != "sync" && *modePtr != "async" {
		fmt.Println("Error: invalid or missing target.")
		flag.Usage()
		os.Exit(1)
	}

	fmt.Printf("Starting %s load (%d streams). Press Ctrl+C to stop.\n", *modePtr, STREAMS)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	instances := make([]pool.Instance, 0, len(routerUriList))
	for _, uri := range routerUriList {
		instances = append(instances, pool.Instance{
			Name: uri,
			Dialer: tarantool.NetDialer{
				Address:  uri,
				User:     USER,
				Password: PASS,
			},
		})
	}

	routerPool, err := pool.ConnectWithOpts(ctx, instances, pool.Opts{CheckTimeout: time.Second})
	if err != nil {
		log.Printf("Connection failed: %v\n", err)
		os.Exit(1)
	}
	defer routerPool.Close()

	loadCtx, loadCancel := context.WithCancel(context.Background())
	space := *modePtr + "_space"
	for i := 0; i < STREAMS; i++ {
		l := &Loader{
			pool:   routerPool,
			space:  space,
			random: rand.New(rand.NewSource(time.Now().UnixNano() + int64(i))),
		}
		go l.Run(loadCtx)
	}

	go func() {
		symbols := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
		i := 0
		for {
			fmt.Printf("\r\033[32m%s\033[0m Loading...", symbols[i%len(symbols)])
			i++
			time.Sleep(100 * time.Millisecond)
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	<-sigChan

	loadCancel()
	fmt.Println("\nStopping load...")
	routerPool.Close()
	fmt.Println("Done.")
}
