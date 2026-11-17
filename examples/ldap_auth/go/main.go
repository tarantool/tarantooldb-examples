// Пример аутентификации в Tarantool DB через LDAP: подключение к роутеру
// как ldap:{login} с auth_type pap-sha256 (роль app.roles.tdb_ldap_auth),
// права сессии определяются LDAP-группами пользователя (mapping роли).
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/tarantool/go-tarantool/v2"
	"github.com/tarantool/go-tarantool/v2/crud"
	"github.com/tarantool/go-tlsdialer"
)

const routerAddr = "localhost:3301"

// connectLDAP подключается к TDB как LDAP-пользователь ldap:{login}.
//
// pap-sha256 — единственный auth_type, который принимает роль tdb_ldap_auth:
// chap-sha1 передаёт в слот пароля байты scramble, бесполезные для LDAP-bind.
// pap-sha256 передаёт пароль открытым текстом, поэтому слушатель роутера
// работает через SSL (mTLS).
func connectLDAP(login, password string) (*tarantool.Connection, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	dialer := tlsdialer.OpenSSLDialer{
		Address:     routerAddr,
		User:        "ldap:" + login,
		Password:    password,
		Auth:        tarantool.PapSha256Auth, // единственный auth_type роли tdb_ldap_auth
		SslCaFile:   "../certs/ca/root-ca.pem",
		SslCertFile: "../certs/client/client.pem",
		SslKeyFile:  "../certs/client/client-key.pem",
	}
	return tarantool.Connect(ctx, dialer, tarantool.Opts{})
}

func insertOrder(conn *tarantool.Connection, id uint64, customer string, amount float64) error {
	req := crud.MakeInsertRequest("orders").Tuple(
		[]interface{}{id, nil, customer, amount},
	)
	ret := crud.Result{}
	return conn.Do(req).GetTyped(&ret)
}

func selectOrders(conn *tarantool.Connection) ([]interface{}, error) {
	req := crud.MakeSelectRequest("orders")
	ret := crud.Result{}
	if err := conn.Do(req).GetTyped(&ret); err != nil {
		return nil, err
	}
	rows, ok := ret.Rows.([]interface{})
	if !ok {
		return nil, fmt.Errorf("неожиданный тип строк: %T", ret.Rows)
	}

	return rows, nil
}

// alice — пользователь OpenLDAP из группы readers: только чтение спейса orders.
func aliceScenario() {
	fmt.Println("--- alice (OpenLDAP, группа readers: orders [read]) ---")

	conn, err := connectLDAP("alice", "alice-pass")
	if err != nil {
		log.Printf("alice: ошибка подключения: %s", err)
		return
	}
	defer conn.CloseGraceful()

	rows, err := selectOrders(conn)
	if err != nil {
		log.Printf("alice: crud.select отклонён: %s", err)
	} else {
		fmt.Printf("alice: crud.select выполнен успешно, строк в спейсе orders: %d\n", len(rows))
	}

	if err := insertOrder(conn, 1, "Alice Ltd", 100.0); err != nil {
		fmt.Printf("alice: crud.insert отклонён, как и ожидалось: %s\n", err)
	} else {
		fmt.Println("alice: crud.insert выполнен успешно — НЕ ожидалось, проверьте параметр mapping")
	}
}

// bob — пользователь AD (smblds) из группы tdb-writers: чтение и запись orders.
func bobScenario() {
	fmt.Println("--- bob (AD, группа tdb-writers: orders [read, write]) ---")

	conn, err := connectLDAP("bob", "BobPassw0rd!")
	if err != nil {
		log.Printf("bob: ошибка подключения: %s", err)
		return
	}
	defer conn.CloseGraceful()

	// Уникальный id — чтобы пример можно было запускать повторно
	id := uint64(time.Now().Unix())
	if err := insertOrder(conn, id, "Bob and Co", 250.0); err != nil {
		log.Printf("bob: crud.insert отклонён: %s", err)
		return
	}
	fmt.Println("bob: crud.insert выполнен успешно")

	count, err := selectOrders(conn)
	if err != nil {
		log.Printf("bob: crud.select отклонён: %s", err)
		return
	}
	fmt.Printf("bob: crud.select выполнен успешно, строк в спейсе orders: %d\n", count)
}

// wrongPassword — вход с неверным паролем отклоняется на этапе AUTH.
func wrongPasswordScenario() {
	fmt.Println("--- alice с неверным паролем ---")

	if _, err := connectLDAP("alice", "wrong-password"); err != nil {
		fmt.Printf("подключение отклонено, как и ожидалось: %s\n", err)
	} else {
		fmt.Println("подключение успешно — НЕ ожидалось, проверьте настройки роли")
	}
}

// scenarios — доступные сценарии по имени (аргумент командной строки).
var scenarios = map[string]func(){
	"alice":          aliceScenario,
	"bob":            bobScenario,
	"wrong-password": wrongPasswordScenario,
}

func main() {
	if len(os.Args) > 1 {
		name := os.Args[1]
		fn, ok := scenarios[name]
		if !ok {
			fmt.Printf("неизвестный сценарий %q; доступные: alice, bob, wrong-password\n", name)
			os.Exit(1)
		}
		fn()
		return
	}

	aliceScenario()
	fmt.Println()
	bobScenario()
	fmt.Println()
	wrongPasswordScenario()
}
