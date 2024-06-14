package main

import (
	"fmt"
	"math/rand"
	"reflect"
	"time"

	"github.com/tarantool/go-tarantool/v2"
	"github.com/tarantool/go-tarantool/v2/crud"
	"github.com/vmihailenco/msgpack/v5"
)

const (
	DATA_QTY     = 10000
	BATCH_SIZE   = 100
	BATCH_QTY    = DATA_QTY / BATCH_SIZE
	LETTER_BYTES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	TIMEOUT      = uint(2)
	TT_HOST      = "127.0.0.1"
	TT_PORT      = "3301"
	TT_USER      = "admin"
	TT_PASS      = "secret-cluster-cookie"
)

var batches [BATCH_QTY][]crud.Tuple

type TestRecord struct {
	Id  uint64 `json:"id"`
	Too uint64 `json:"too"`
	Foo string `json:"foo"`
}

func (c *TestRecord) EncodeMsgpack(e *msgpack.Encoder) error {
	// Мы кодируем тапл, который представляет из себя массив значений. Здесь мы
	// обозначаем сколько значений будет закодировано, обозначаем длину массива
	if err := e.EncodeArrayLen(4); err != nil {
		return err
	}

	// Кодируем значение столбца Id
	if err := e.EncodeUint(c.Id); err != nil {
		return err
	}

	// Обратите внимание, что в базе данных в данной таблице есть дополнительный столбец для
	// шардинга - `bucket_id`. Поэтому здесь мы должны закодировать значение этого столбца.
	// Если передать nil, то номер бакета будет определять функционал модуля CRUD
	if err := e.EncodeNil(); err != nil {
		return err
	}

	// Кодируем значение столбца Too
	if err := e.EncodeUint(c.Too); err != nil {
		return err
	}

	// Кодируем значение столбца Foo
	if err := e.EncodeString(c.Foo); err != nil {
		return err
	}

	return nil
}

func (c *TestRecord) DecodeMsgpack(d *msgpack.Decoder) error {
	var err error
	var l int

	// Мы получаем тапл, который представляет из себя массив значений. Здесь мы
	// определяем сколько значений закодировано, получаем длину массива
	if l, err = d.DecodeArrayLen(); err != nil {
		return err
	}

	// Проверяем число значений
	if l != 4 {
		return fmt.Errorf("array len doesn't match: %d", l)
	}

	// Декодируем значение столбца Id
	if c.Id, err = d.DecodeUint64(); err != nil {
		return err
	}

	// Декодируем значение столбца BucketId
	if _, err = d.DecodeUint64(); err != nil {
		return err
	}

	// Декодируем значение столбца Too
	if c.Too, err = d.DecodeUint64(); err != nil {
		return err
	}

	// Декодируем значение столбца Foo
	if c.Foo, err = d.DecodeString(); err != nil {
		return err
	}
	return nil
}

func RandStringBytes(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = LETTER_BYTES[rand.Intn(len(LETTER_BYTES))]
	}
	return string(b)
}

func GenerateBatchesAuto() {
	for batchNum := 0; batchNum < BATCH_QTY; batchNum++ {
		tuples := []crud.Tuple{}
		n := batchNum * BATCH_SIZE
		for i := 0; i < BATCH_SIZE; i++ {
			id := i + n + 1
			too := uint(rand.Intn(100))
			foo := RandStringBytes(rand.Intn(100))

			tuples = append(tuples, []interface{}{id, nil, too, foo})
		}
		batches[batchNum] = tuples
	}
}

func GenerateBatchesCustom() {
	for batchNum := 0; batchNum < BATCH_QTY; batchNum++ {
		tuples := []crud.Tuple{}
		n := batchNum * BATCH_SIZE
		for i := 0; i < BATCH_SIZE; i++ {
			tuple := TestRecord{
				Id:  uint64(i + n + 1),
				Too: uint64(rand.Intn(100)),
				Foo: RandStringBytes(rand.Intn(100)),
			}
			tuples = append(tuples, &tuple)
		}
		batches[batchNum] = tuples
	}
}

func WritePerBatchOverCrud(conn *tarantool.Connection) bool {
	var opManyOpts = crud.OperationManyOpts{
		Timeout: crud.MakeOptUint(TIMEOUT),
	}

	for i := 0; i < BATCH_QTY; i++ {
		req := crud.MakeReplaceManyRequest("test").
			Tuples(batches[i]).
			Opts(opManyOpts)
		ret := crud.Result{}
		err := conn.Do(req).GetTyped(&ret)
		if err != nil {
			fmt.Printf("failed to execute request: %s\n", err.Error())
			return false
		}
	}

	return true
}

func CheckRecords(conn *tarantool.Connection) {
	var opts = crud.GetOpts{
		Timeout: crud.MakeOptUint(TIMEOUT),
	}

	for i := 0; i < BATCH_QTY; i++ {
		for j := 0; j < BATCH_SIZE; j++ {
			record_want := batches[i][j].(*TestRecord)
			req := crud.MakeGetRequest("test").Key(record_want.Id).Opts(opts)
			ret := crud.MakeResult(reflect.TypeOf(TestRecord{}))
			err := conn.Do(req).GetTyped(&ret)
			if err != nil {
				fmt.Printf("error in do get request is %s\n", err)
				return
			}
			rows := ret.Rows.([]TestRecord)
			if len(rows) < 1 {
				fmt.Printf("error in do get request - no data in response\n")
				return
			}

			record_actual := rows[0]
			if record_want.Id != record_actual.Id || record_want.Too != record_actual.Too || record_want.Foo != record_actual.Foo {
				fmt.Printf("error in do get request - records not equal\n")
				fmt.Printf("record want: %#v\n", record_want)
				fmt.Printf("record actual: %#v\n", record_actual)
				return
			}
		}
	}

	fmt.Printf("Rows verified\n")
}

func main() {
	opts := tarantool.Opts{User: TT_USER, Pass: TT_PASS}
	conn, err := tarantool.Connect(TT_HOST + ":" + TT_PORT, opts)
	if err != nil {
		fmt.Printf("database connection error: %s\n", err.Error())
		return
	}

	GenerateBatchesAuto()

	start := time.Now()
	ok := WritePerBatchOverCrud(conn)
	if ok {
		fmt.Printf("Rows via crud in batches of %d records in %v - auto-encoder\n", DATA_QTY, time.Since(start))
	}

	GenerateBatchesCustom()

	start = time.Now()
	ok = WritePerBatchOverCrud(conn)
	if ok {
		fmt.Printf("Rows via crud in batches of %d records in %v - custom-encoder\n", DATA_QTY, time.Since(start))
	}

	start = time.Now()
	CheckRecords(conn)
	fmt.Printf("Rows via crud of %d readed in %v\n", DATA_QTY, time.Since(start))
}
