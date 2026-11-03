package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/tarantool/go-tarantool/v3"
	"github.com/tarantool/go-tarantool/v3/crud"
)

const (
	addr = "127.0.0.1:3301"
	user = "admin"
	pass = "secret-cluster-cookie"

	clientID       = 1
	transferAmount = uint(100)
	transferID     = uint(1001)
)

// do runs a request and returns the decoded response.
func do(conn *tarantool.Connection, req tarantool.Request) ([]any, error) {
	future := conn.Do(req)
	defer future.Release()

	return future.Get()
}

// doTyped runs a request and decodes the response into result.
func doTyped(conn *tarantool.Connection, req tarantool.Request, result any) error {
	future := conn.Do(req)
	defer future.Release()

	return future.GetTyped(result)
}

// buildTransferOperations returns a batch of CRUD operations that transfer
// amount from fromAccount to toAccount and write a record to the transfers
// journal. All operations target the same client_id, so they belong to the
// same bucket and are applied atomically.
func buildTransferOperations(txnID uint, fromAccount, toAccount string, amount uint) []any {
	return []any{
		map[string]any{
			"type":       "update",
			"space":      "accounts",
			"key":        []any{clientID, fromAccount},
			"operations": []any{[]any{"-", "balance", amount}},
		},
		map[string]any{
			"type":       "update",
			"space":      "accounts",
			"key":        []any{clientID, toAccount},
			"operations": []any{[]any{"+", "balance", amount}},
		},
		map[string]any{
			"type":  "insert",
			"space": "transfers",
			"tuple": []any{txnID, clientID, nil, fromAccount, toAccount, amount, uint(time.Now().Unix())},
		},
	}
}

// atomicBatch calls crud.atomic_batch over IPROTO_CALL and returns the result
// data together with the CRUD error, if any.
func atomicBatch(conn *tarantool.Connection, operations []any) (any, any) {
	req := tarantool.NewCallRequest("crud.atomic_batch").
		Args([]any{operations, map[string]any{"timeout": 5}})

	data, err := do(conn, req)
	if err != nil {
		log.Fatalf("crud.atomic_batch call failed: %v", err)
	}
	if len(data) < 2 {
		log.Fatalf("unexpected crud.atomic_batch response: %#v", data)
	}

	return data[0], data[1]
}

// countRows returns the number of rows in the data field of the atomic_batch
// result.
func countRows(res any) int {
	m, ok := res.(map[any]any)
	if !ok {
		return 0
	}
	if rows, ok := m["data"].([]any); ok {
		return len(rows)
	}
	return 0
}

// formatBatchError extracts the error message from a CRUD error table.
func formatBatchError(err any) string {
	if err == nil {
		return "<nil>"
	}
	m, ok := err.(map[any]any)
	if !ok {
		return fmt.Sprintf("%v", err)
	}
	if msg, ok := m["err"].(string); ok {
		return msg
	}
	return fmt.Sprintf("%v", err)
}

// seedAccounts truncates the spaces and inserts the initial account balances,
// so the example can be run repeatedly.
func seedAccounts(conn *tarantool.Connection) {
	for _, space := range []string{"transfers", "accounts"} {
		if _, err := do(conn, crud.NewTruncateRequest(space)); err != nil {
			log.Fatalf("failed to truncate %s: %v", space, err)
		}
	}

	accounts := []any{
		[]any{clientID, "main", nil, uint(1000)},
		[]any{clientID, "savings", nil, uint(500)},
	}
	for _, tuple := range accounts {
		req := crud.NewInsertRequest("accounts").Tuple(tuple)
		if _, err := do(conn, req); err != nil {
			log.Fatalf("failed to seed account %v: %v", tuple, err)
		}
	}
}

// getBalance returns the balance of the given account, or nil if the account
// does not exist.
func getBalance(conn *tarantool.Connection, accountType string) any {
	req := crud.NewGetRequest("accounts").Key([]any{clientID, accountType})

	var result crud.Result
	if err := doTyped(conn, req, &result); err != nil {
		log.Fatalf("failed to get balance of %q: %v", accountType, err)
	}

	rows, ok := result.Rows.([]any)
	if !ok || len(rows) == 0 {
		return nil
	}

	// accounts format: client_id, account_type, bucket_id, balance.
	row, ok := rows[0].([]any)
	if !ok || len(row) < 4 {
		return nil
	}

	return row[3]
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	dialer := tarantool.NetDialer{
		Address:  addr,
		User:     user,
		Password: pass,
	}
	opts := tarantool.Opts{Timeout: 5 * time.Second}

	conn, err := tarantool.Connect(ctx, dialer, opts)
	if err != nil {
		log.Fatalf("failed to connect: %v", err)
	}
	defer conn.Close()

	seedAccounts(conn)

	fmt.Printf("Balances before transfer: main=%v savings=%v\n",
		getBalance(conn, "main"), getBalance(conn, "savings"))

	// A successful transfer: both balance updates and the journal insert are
	// applied atomically.
	operations := buildTransferOperations(transferID, "main", "savings", transferAmount)
	res, callErr := atomicBatch(conn, operations)
	if callErr != nil {
		log.Fatalf("transfer %d failed: %v", transferID, formatBatchError(callErr))
	}
	fmt.Printf("Transfer %d applied (%d rows returned)\n", transferID, countRows(res))
	fmt.Printf("Balances after transfer:  main=%v savings=%v\n",
		getBalance(conn, "main"), getBalance(conn, "savings"))

	// Re-running the same transfer fails on a duplicate key, so the whole
	// batch is rolled back and the balances stay unchanged.
	_, callErr = atomicBatch(conn, buildTransferOperations(transferID, "main", "savings", transferAmount))
	if callErr == nil {
		log.Fatalf("duplicate transfer %d unexpectedly succeeded", transferID)
	}
	fmt.Printf("Duplicate transfer %d rolled back: %s\n", transferID, formatBatchError(callErr))
	fmt.Printf("Balances after rollback:  main=%v savings=%v\n",
		getBalance(conn, "main"), getBalance(conn, "savings"))
}
