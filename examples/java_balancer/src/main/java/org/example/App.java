package org.example;

import java.util.Arrays;
import java.util.Collections;
import java.util.Random;
import java.util.concurrent.CompletionException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.tarantool.client.crud.TarantoolCrudClient;
import io.tarantool.client.crud.TarantoolCrudSpace;
import io.tarantool.client.factory.TarantoolFactory;
import io.tarantool.pool.InstanceConnectionGroup;

public class App {
    private static final Logger log = LoggerFactory.getLogger(App.class);
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

    private static TestSpaceRecord makeRandomTuple() {
        return TestSpaceRecord.builder()
            .id(rand.nextLong())
            .too(rand.nextLong())
            .foo(randStringBytes(rand.nextInt(32))
            ).build();
    }

    private static void writeOverCrud(TarantoolCrudSpace space) {
        try {
            space.replace(makeRandomTuple()).join();
        } catch (CompletionException ex) {
            log.error("Failed to execute request: %s", ex);
        }
    }

    public static void main(String[] args) throws Exception {
        TarantoolCrudClient client =
            TarantoolFactory.crud()
                .withGroups(Arrays.asList(
                    InstanceConnectionGroup.builder()
                        .withPort(3301)
                        .withUser("admin")
                        .withPassword("secret-cluster-cookie")
                        .withTag("node-a-00")
                        .build(),
                    InstanceConnectionGroup.builder()
                        .withPort(3302)
                        .withUser("admin")
                        .withPassword("secret-cluster-cookie")
                        .withTag("node-b-00")
                        .build()
                ))
                .build();
        TarantoolCrudSpace space = client.space("test");
        try {
            System.out.println("To finish the job, press Ctrl+Z");
            for (;;) {
                writeOverCrud(space);
            }
        } finally {
            client.close();
        }
    }
}
