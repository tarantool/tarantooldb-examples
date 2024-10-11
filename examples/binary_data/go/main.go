package main

import (
	"context"
	"io/ioutil"
	"log"
	"fmt"
	"net/http"
	"path/filepath"
	"time"
	
	"github.com/tarantool/go-tarantool/v2"
	"github.com/tarantool/go-tarantool/v2/crud"
)

const (
	tarantoolAddress  = "127.0.0.1:3301"
	tarantoolUser     = "admin"
	tarantoolPassword = "secret-cluster-cookie"
	imageDir          = "./images"
)

var conn *tarantool.Connection

func main() {
	// Connect to Tarantool
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	
	dialer := tarantool.NetDialer{
		Address:  tarantoolAddress,
		User:     tarantoolUser,
		Password: tarantoolPassword,
	}
	
	opts := tarantool.Opts{
		Timeout: 5 * time.Second,
	}
	
	var err error
	conn, err = tarantool.Connect(ctx, dialer, opts)
	if err != nil {
		log.Fatalf("error: No connection available: %v\n", err)
	}
	defer conn.Close()
	
	// Load images into Tarantool
	loadImagesToTarantool()
	
	// Start HTTP server
	http.HandleFunc("/", fileHandler)
	log.Println("Starting server on :8082")
	log.Fatal(http.ListenAndServe(":8082", nil))
}

func loadImagesToTarantool() {
	files, err := ioutil.ReadDir(imageDir)
	if err != nil {
		log.Fatalf("Failed to read directory: %v\n", err)
	}

	for _, file := range files {
		if !file.IsDir() {
			filePath := filepath.Join(imageDir, file.Name())
			data, err := ioutil.ReadFile(filePath)
			if err != nil {
				log.Printf("Failed to read file %s: %v\n", filePath, err)
				continue
			}
			tuple := []interface{}{file.Name(), nil, string(data)}

			req := crud.MakeReplaceRequest("my_files").Tuple(tuple)
			ret := crud.Result{}
			err = conn.Do(req).GetTyped(&ret)
			if err != nil {
				log.Printf("Failed to execute request: %v\n", err)
			}
		}
	}
}

func fileHandler(w http.ResponseWriter, r *http.Request) {
	fileName := r.URL.Path[1:] // Remove leading '/'
	if fileName == "" {
		http.Error(w, "File name is required", http.StatusBadRequest)
		return
	}

	req := crud.MakeGetRequest("my_files").Key(fileName)
	ret := crud.Result{}
	err := conn.Do(req).GetTyped(&ret)
	if err != nil {
		http.Error(w, fmt.Sprintf("error in do get request is: %v", err), http.StatusInternalServerError)
		return
	}
	rows := ret.Rows.([]interface{})
	if len(rows) < 1 {
		http.NotFound(w, r)
		return
	}

	tuple := rows[0].([]interface{})

	fileData := tuple[2].(string)
	w.Header().Set("Content-Type", "image/jpeg")
	w.Write([]byte(fileData))
}
