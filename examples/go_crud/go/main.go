package main

import (
	"context"
	"log"
	"math/rand"
	"reflect"
	"time"

	"github.com/tarantool/go-tarantool/v2"
	"github.com/tarantool/go-tarantool/v2/crud"
)

const (
	DATA_QTY     = 10000
	BATCH_SIZE   = 100
	BATCH_QTY    = DATA_QTY / BATCH_SIZE
	LETTER_BYTES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
)

var batches [BATCH_QTY][]crud.Tuple

func RandStringBytes(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = LETTER_BYTES[rand.Intn(len(LETTER_BYTES))]
	}
	return string(b)
}

func MakeRandomTuple(ID uint) []any {
	return []any{
		ID,                             // id
		nil,                            // bucket_id
		uint(rand.Intn(1e4)),           // too
		RandStringBytes(rand.Intn(32)), // foo
	}
}

func GenerateBatches() {
	for batchNum := 0; batchNum < BATCH_QTY; batchNum++ {
		tuples := []crud.Tuple{}
		n := batchNum * BATCH_SIZE
		for i := 0; i < BATCH_SIZE; i++ {
			id := uint(i + n + 1)
			tuples = append(tuples, MakeRandomTuple(id))
		}
		batches[batchNum] = tuples
	}
}

func TruncateSpace(conn *tarantool.Connection) bool {
	req := crud.MakeTruncateRequest("test")
	_, err := conn.Do(req).Get()
	if err != nil {
		log.Printf("error in do truncate request is %v\n", err)
		return false
	}

	return true
}

func WritePerBatchOverCrud(conn *tarantool.Connection) bool {
	res := TruncateSpace(conn)
	if !res {
		return false
	}

	for i := 0; i < BATCH_QTY; i++ {
		req := crud.MakeInsertManyRequest("test").
			Tuples(batches[i])
		ret := crud.Result{}
		err := conn.Do(req).GetTyped(&ret)
		if err != nil {
			log.Printf("Failed to execute request: %v\n", err)
			return false
		}
	}

	return true
}

func CheckRecords(conn *tarantool.Connection) {
	for i := 0; i < BATCH_QTY; i++ {
		for j := 0; j < BATCH_SIZE; j++ {
			record_want := batches[i][j].([]interface{})
			want_id := convertToInt(record_want[0])
			want_too := convertToInt(record_want[2])
			want_foo := record_want[3].(string)

			req := crud.MakeGetRequest("test").Key(want_id)
			ret := crud.Result{}
			err := conn.Do(req).GetTyped(&ret)
			if err != nil {
				log.Printf("error in do get request is %s", err)
				return
			}
			rows := ret.Rows.([]interface{})
			if len(rows) < 1 {
				log.Printf("error in do get request - no data in response")
				return
			}

			record_actual := rows[0].([]interface{})
			actual_id := convertToInt(record_actual[0])
			actual_too := convertToInt(record_actual[2])
			actual_foo := record_actual[3].(string)

			if want_id != actual_id || want_too != actual_too || want_foo != actual_foo {
				log.Printf("error in do get request - records not equals\n")
				log.Printf("record want: %#v\n", record_want)
				log.Printf("record actual: %#v\n", record_actual)
				return
			}
		}
	}

	log.Printf("Rows verified\n")
}

func convertToInt(value interface{}) (intVal int) {
	switch v := value.(type) {
	case int:
		intVal = v
	case int8, int16, int32, int64:
		intVal = int(reflect.ValueOf(value).Int())
	case uint, uint8, uint16, uint32, uint64:
		intVal = int(reflect.ValueOf(value).Uint())
	default:
		log.Fatalf("Failed to convert to int: unknown type %T\n", value)
	}
	return intVal
}

func main() {
	GenerateBatches()

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	dialer := tarantool.NetDialer{
		Address:  "127.0.0.1:3301",
		User:     "admin",
		Password: "secret-cluster-cookie",
	}

	opts := tarantool.Opts{
		Timeout: 5 * time.Second,
	}

	conn, err := tarantool.Connect(ctx, dialer, opts)
	if err != nil {
		log.Printf("error: No connection available: %v\n", err)
		return
	}
	defer conn.Close()

	start := time.Now()
	ok := WritePerBatchOverCrud(conn)
	if ok {
		log.Printf("Recorded via crud in batches of %d records in %v\n", DATA_QTY, time.Since(start))
	}

	CheckRecords(conn)
}
