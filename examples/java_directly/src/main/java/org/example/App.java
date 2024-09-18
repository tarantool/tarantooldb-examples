package org.example;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

import io.tarantool.client.box.TarantoolBoxClient;
import io.tarantool.client.box.TarantoolBoxSpace;
import io.tarantool.client.factory.TarantoolFactory;
import io.tarantool.mapping.SelectResponse;
import io.tarantool.mapping.Tuple;

public class App {

    private static final int DATA_QTY = 10000;
    private static final String LETTER_BYTES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

    private static final Random rand = new Random();

    private static String randStringBytes(int n) {
        StringBuilder sb = new StringBuilder(n);
        for (int i = 0; i < n; i++) {
            int index = rand.nextInt(LETTER_BYTES.length());
            sb.append(LETTER_BYTES.charAt(index));
        }
        return sb.toString();
    }

    private static void truncateSpace(TarantoolBoxClient client) {
        client.call("box.space.test:truncate").join();
    }

    private static TestSpaceRecord makeRandomTuple(long id) {
        return TestSpaceRecord.builder()
            .id(id)
            .too(rand.nextLong())
            .foo(randStringBytes(rand.nextInt(32))).build();
    }

    private static void WritePerOne(TarantoolBoxClient client, TarantoolBoxSpace space) {
        truncateSpace(client);

        for (int i = 0; i < DATA_QTY; i++) {
            try {
                space.insert(makeRandomTuple(i)).join();
            } catch (Exception e) {
                System.out.println("Insert error: " + e.getMessage());
            }
        }
    }

    private static void ReadOne(TarantoolBoxSpace space, int id) {
        try {
            SelectResponse<List<Tuple<List<?>>>> tuples = space.select(id).join();
            System.out.println("Tuples: " + tuples.get().get(0));
        } catch (Exception e) {
            System.out.println("Error: " + e.getMessage());
        }
    }

    public static void main(String[] args) throws Exception {
        TarantoolBoxClient client =
            TarantoolFactory.box()
                .withUser("admin")
                .withPort(3301)
                .withHost("localhost")
                .withPassword("secret-cluster-cookie")
                .build();
        TarantoolBoxSpace space = client.space("test");
        try {
            long start = System.currentTimeMillis();
            WritePerOne(client, space);
            System.out.println("Directly recorded " + DATA_QTY + " rows one at a time in " +
                                   (System.currentTimeMillis() - start) + " milliseconds");

            ReadOne(space, 1);
        } finally {
            client.close();
        }
    }
}
