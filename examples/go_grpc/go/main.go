package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"time"

	pb "example.com/tdb-go-grpc/gen/service/tdb/crud/v1"
	shared "example.com/tdb-go-grpc/gen/service/tdb/shared/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/protobuf/types/known/structpb"
)

func main() {
	address := flag.String("addr", "localhost:9091", "gRPC Gateway address")
	flag.Parse()
	if err := run(*address); err != nil {
		log.Fatal(err)
	}
}

func run(address string) error {
	conn, err := grpc.NewClient(address, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return err
	}
	defer conn.Close()

	client := pb.NewCrudClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	const space = "books"
	key := &pb.Key{Parts: []*structpb.Value{structpb.NewNumberValue(1)}}
	book, err := structpb.NewStruct(map[string]any{
		"id":     1,
		"title":  "First edition",
		"author": "Alice",
	})
	if err != nil {
		return err
	}
	inserted, err := client.Insert(ctx, &pb.InsertRequest{Space: space, Record: book})
	if err != nil {
		return fmt.Errorf("insert: %w", err)
	}
	fmt.Println("Insert:", inserted.GetRecord().GetFields()["title"].GetStringValue())

	deleted := false
	defer func() {
		if !deleted {
			// Clean up only the record created by this invocation.
			cleanupCtx, cleanupCancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cleanupCancel()
			if _, err := client.Delete(cleanupCtx, &pb.DeleteRequest{Space: space, Key: key}); err != nil {
				log.Printf("delete after failure: %v", err)
			}
		}
	}()

	got, err := client.Get(ctx, &pb.GetRequest{Space: space, Key: key})
	if err != nil {
		return fmt.Errorf("get: %w", err)
	}
	fmt.Println("Get:", got.GetRecord().GetFields()["title"].GetStringValue())

	book.Fields["title"] = structpb.NewStringValue("Second edition")
	replaced, err := client.Replace(ctx, &pb.ReplaceRequest{Space: space, Record: book})
	if err != nil {
		return fmt.Errorf("replace: %w", err)
	}
	fmt.Println("Replace:", replaced.GetRecord().GetFields()["title"].GetStringValue())

	updated, err := client.Update(ctx, &pb.UpdateRequest{
		Space: space,
		Key:   key,
		Operations: []*pb.PatchOperation{{
			Field:    "title",
			Operator: pb.PatchOperator_PATCH_OPERATOR_SET,
			Value:    structpb.NewStringValue("Revised edition"),
		}},
	})
	if err != nil {
		return fmt.Errorf("update: %w", err)
	}
	fmt.Println("Update:", updated.GetRecord().GetFields()["title"].GetStringValue())

	selected, err := client.Select(ctx, &pb.SelectRequest{
		Space: space,
		Conditions: []*pb.Condition{{
			Field:    "id",
			Operator: pb.CompareOperator_COMPARE_OPERATOR_EQ,
			Value:    structpb.NewNumberValue(1),
		}},
		Options: &shared.SelectOptions{Limit: 1},
	})
	if err != nil {
		return fmt.Errorf("select: %w", err)
	}
	fmt.Printf("Select: %d record(s)\n", len(selected.GetRecords()))

	removed, err := client.Delete(ctx, &pb.DeleteRequest{Space: space, Key: key})
	if err != nil {
		return fmt.Errorf("delete: %w", err)
	}
	deleted = true
	fmt.Println("Delete:", removed.GetDeleted())
	return nil
}
