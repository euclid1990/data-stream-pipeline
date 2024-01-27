import * as dotenv from 'dotenv';
import { ar, faker } from '@faker-js/faker';
import { join } from 'path';
import { readFileSync, writeFileSync } from 'fs';
import { Kinesis, PutRecordsCommandOutput, PutRecordsInput, PutRecordsRequestEntry } from '@aws-sdk/client-kinesis';

interface IStackOutputs {
  lambdaFunctionName: string;
  s3BucketName: string;
  kinesisDataStreamName: string;
  kinesisFirehoseDeliveryStreamName: string;
}

class KinesisDataStream {
  private kinesis: Kinesis;
  private stackOutputs: IStackOutputs;
  private idFilePath: string = join(__dirname, './id.txt');

  constructor() {
    this.initialize();
  }

  initialize() {
    dotenv.config();
    this.kinesis = new Kinesis({
      apiVersion: '2013-12-02',
      region: process.env.CDK_REGION
    });
    try {
      const contents = readFileSync(join(__dirname, './outputs.json'), 'utf-8');
      const parsed = JSON.parse(contents)
      this.stackOutputs = parsed[process.env.CDK_STACK as string] as IStackOutputs;
    } catch (err) {
      throw err;
    }
  }

  readIncrementId(): number {
    let id: number;
    try {
      // Try to read the existing file
      const content = readFileSync(this.idFilePath, 'utf-8');
      // Parse the content as an integer
      id = parseInt(content, 10);
      // Check if id is NaN and set it to 0 in that case
      if (isNaN(id)) {
        id = 1;
      }
    } catch (error: any) {
      // If the file doesn't exist, create a new file and initialize ID to 1
      if (error.code === 'ENOENT') {
        id = 1;
        writeFileSync(this.idFilePath, id.toString(), 'utf-8');
      } else {
        // Handle other errors
        throw error;
      }
    }
    return id;
  }

  setIncrementId(id: number): boolean {
    try {
      // Write latest id in file
      writeFileSync(this.idFilePath, id.toString(), 'utf-8');
    } catch (error: any) {
      // Handle other errors
      throw error;
    }
    return true;
  }

  fake(autoIncrement: number): any {
    const dump = {
      "id": autoIncrement,
      "order_id": faker.string.uuid(),
      "customer_id": +faker.finance.accountNumber(2),
      "product_name": faker.commerce.productName(),
      "product_quantity": +faker.finance.amount({ min: 1, max: 2, dec: 0 }),
      "product_price": +faker.commerce.price(),
      "phone_number": faker.helpers.fromRegExp(/[0-9]{3}-[0-9]{3}-[0-9]{4}/),
      "address": faker.location.streetAddress(),
      "city": faker.location.city(),
      "country": faker.location.country(),
      "order_cost": 0,
      "order_date": faker.date.past({ years: 10 }),
      "generate_date": new Date().toISOString(),
    }
    dump.order_cost = dump.product_price * dump.product_quantity;
    return dump;
  }

  sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async send(times: number, batchSize: number = 100) {
    let id: number = this.readIncrementId();

    for (let i = 0; i < times; i += batchSize) {
      try {
        const recordsBatch: PutRecordsRequestEntry[] = [];

        // Create a batch of records
        for (let j = 0; j < batchSize && i + j < times; j++) {
          const data = this.fake(id);
          id++;
          const record: PutRecordsRequestEntry = {
            Data: Buffer.from(JSON.stringify(data)),
            PartitionKey: data.customer_id.toString()
          };
          recordsBatch.push(record);
        }

        // Put the batch of records to Kinesis
        const params: PutRecordsInput = {
          Records: recordsBatch,
          StreamName: this.stackOutputs.kinesisDataStreamName
        };

        const result: PutRecordsCommandOutput = await this.kinesis.putRecords(params);

        // Process the result if needed
        if (result.FailedRecordCount !== undefined && result.FailedRecordCount > 0) {
          console.error('Some records failed to be put to Kinesis:', result.Records?.filter(record => !!record.ErrorCode));
        } else {
          console.info(`Successfully put batch of ${recordsBatch.length} records (ID: ${id - batchSize} ~ ${id - 1}) to Kinesis`);
        }

        this.setIncrementId(id);
      } catch (error) {
        console.error('Error:', error);
      }

      await this.sleep(10);
    }

  }
}

(async () => {
  const kinesisDataStream = new KinesisDataStream();
  const args = process.argv.slice(2);
  const times = (args.length > 0) ? parseInt(args[0], 10) : 100;

  const start = new Date().getTime();

  await kinesisDataStream.send(times);

  const end = new Date().getTime();
  const executionTimeSeconds = (end - start) / 1000;
  console.info(`${new Date().toISOString()} -- Function execution time: ${executionTimeSeconds} seconds.`);
})();
