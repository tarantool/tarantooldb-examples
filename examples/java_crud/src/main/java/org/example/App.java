package org.example;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

import io.tarantool.client.crud.Condition;
import io.tarantool.client.crud.TarantoolCrudClient;
import io.tarantool.client.crud.TarantoolCrudSpace;
import io.tarantool.client.factory.TarantoolFactory;
import io.tarantool.mapping.Tuple;
import io.tarantool.mapping.crud.CrudError;
import io.tarantool.mapping.crud.CrudException;

public class App {

    private static final int DATA_QTY = 10000;
    private static final int BATCH_SIZE = 100;
    private static final int BATCH_QTY = DATA_QTY / BATCH_SIZE;
    private static final String LETTER_BYTES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

    private static final Random rand = new Random();

    private static final List<List<TestSpaceRecord>> batches = new ArrayList<>(BATCH_QTY);

    private static String randStringBytes(int n) {
        StringBuilder sb = new StringBuilder(n);
        for (int i = 0; i < n; i++) {
            int index = rand.nextInt(LETTER_BYTES.length());
            sb.append(LETTER_BYTES.charAt(index));
        }
        return sb.toString();
    }

    private static TestSpaceRecord makeRandomTuple(long id) {
        return TestSpaceRecord.builder()
            .id(id)
            .too(rand.nextLong())
            .foo(randStringBytes(rand.nextInt(32))).build();
    }

    private static void generateBatches() {
        for (int batchNum = 0; batchNum < BATCH_QTY; batchNum++) {
            List<TestSpaceRecord> tuples = new ArrayList<>();
            int n = batchNum * BATCH_SIZE;
            for (int i = 0; i < BATCH_SIZE; i++) {
                long id = i + n + 1;
                tuples.add(makeRandomTuple(id));
            }
            batches.add(tuples);
        }
    }

    private static boolean truncateSpace(TarantoolCrudSpace space) {
        return space.truncate().join();
    }

    private static boolean writePerBatchOverCrud(TarantoolCrudSpace space) {
        boolean result = truncateSpace(space);

        if (!result) {
            return false;
        }

        for (int i = 0; i < BATCH_QTY; i++) {
            List<CrudError> errors = space.insertMany(batches.get(i)).join().getErrors();
            if (errors != null && !errors.isEmpty()) {
                // throw first error, or you can rewrite this line by your own way
                throw new CrudException(errors.get(0));
            }
        }

        return true;
    }

    private static void checkRecords(TarantoolCrudSpace space) {
        for (int i = 0; i < BATCH_QTY; i++) {
            for (int j = 0; j < BATCH_SIZE; j++) {
                TestSpaceRecord tupleWant = batches.get(i).get(j);
                long wantId = tupleWant.getId();
                long wantToo = tupleWant.getToo();
                String wantFoo = tupleWant.getFoo();

                List<Tuple<TestSpaceRecord>> rows = space.select(
                    Collections.singletonList(
                        Condition.builder()
                            .withFieldIdentifier("pk")
                            .withOperator("=")
                            .withValue(wantId)
                            .build()
                    ),
                    TestSpaceRecord.class
                ).join();
                if (rows.isEmpty()) {
                    System.out.println("No data in response for id: " + wantId);
                    return;
                }

                TestSpaceRecord tupleActual = rows.get(0).get();
                long actualId = tupleActual.getId();
                long actualToo = tupleActual.getToo();
                String actualFoo = tupleActual.getFoo();

                if (wantId != actualId || wantToo != actualToo || !wantFoo.equals(actualFoo)) {
                    System.out.println("Records not equal for id: " + wantId);
                    System.out.println("Record want: " + tupleWant);
                    System.out.println("Record actual: " + tupleActual);
                    return;
                }
            }
        }

        System.out.println("Rows verified");
    }

    public static void main(String[] args) throws Exception {
        generateBatches();

        TarantoolCrudClient client =
            TarantoolFactory.crud()
                .withUser("admin")
                .withPassword("secret-cluster-cookie")
                .build();
        TarantoolCrudSpace space = client.space("test");
        try {
            long start = System.currentTimeMillis();
            boolean success = writePerBatchOverCrud(space);
            if (success) {
                System.out.println("Records inserted via CRUD in batches of " + DATA_QTY +
                                       " records in " + (System.currentTimeMillis() - start) + " ms");
            }

            checkRecords(space);
        } finally {
            client.close();
        }
    }
}
