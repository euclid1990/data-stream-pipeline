import { join } from 'path';
import { randomBytes } from 'crypto';
import * as dotenv from 'dotenv';
import { Stack, StackProps, Duration, Size, RemovalPolicy, CfnOutput } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Function, Runtime, Code } from 'aws-cdk-lib/aws-lambda';
import { Bucket, BucketEncryption } from 'aws-cdk-lib/aws-s3';
import { Stream } from 'aws-cdk-lib/aws-kinesis';
import { LambdaFunctionProcessor, DeliveryStream } from '@aws-cdk/aws-kinesisfirehose-alpha'
import * as destinations from '@aws-cdk/aws-kinesisfirehose-destinations-alpha';
import { readFileSync, writeFileSync } from 'fs';

export class CdkStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // Provide a Lambda function that will transform records before delivery, with custom buffering and retry configuration
    const tranformationLambdaFunction = new Function(this, 'Tranformer Function', {
      runtime: Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: Code.fromAsset(join(__dirname, './../assets/lambda')),
      timeout: Duration.seconds(60),
      description: 'Transform and convert records in Kinesis Data Firehose',
    });

    // Create S3 bucket to store stream data
    const bucket = new Bucket(this, 'Destination Bucket', {
      encryption: BucketEncryption.S3_MANAGED,
      removalPolicy: RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // Transformed before being delivered to destinations
    const processor = new LambdaFunctionProcessor(tranformationLambdaFunction, {
      bufferInterval: Duration.seconds(120),
      bufferSize: Size.mebibytes(1),
      retries: 0,
    });

    // Kinesis data source stream
    const sourceStream = new Stream(this, 'Firehose Data Stream', {
      shardCount: 1,
      retentionPeriod: Duration.hours(24),
    });

    // Defining a delivery stream with an S3 bucket destination
    const s3Destination = new destinations.S3Bucket(bucket, {
      processor: processor,
      bufferingInterval: Duration.seconds(60),
      bufferingSize: Size.mebibytes(1),
    });

    // Defining a delivery stream with source and destination
    const firehose = new DeliveryStream(this, 'Firehose Delivery Stream', {
      sourceStream: sourceStream,
      destinations: [s3Destination],
    });

    // Print the output
    new CfnOutput(this, 'lambdaFunctionName', { value: tranformationLambdaFunction.functionName });
    new CfnOutput(this, 's3BucketName', { value: bucket.bucketName });
    new CfnOutput(this, 'kinesisDataStreamName', { value: sourceStream.streamName });
    new CfnOutput(this, 'kinesisFirehoseDeliveryStreamName', { value: firehose.deliveryStreamName });
  }

  randomString(n?: number) {
    if (typeof n == 'undefined') {
      n = 32;
    }
    return randomBytes(n).toString('hex');
  }

  camelToSnakeUpperCase(input: string): string {
    return input.replace(/([A-Z])/g, "_$1").toUpperCase();
  }

  overwriteEnvFile(
    data: {
      lambdaFunctionName: string,
      s3BucketName: string,
      kinesisFirehoseDeliveryStreamName: string
    }) {
    const path: string = join(__dirname, './../.env');
    const parsed: dotenv.DotenvParseOutput | undefined = dotenv.config({ path }).parsed;
    if (parsed?.error || parsed == undefined) {
      throw parsed?.error
    }
    for (const key in data) {
      if (data.hasOwnProperty(key)) {
        const envKey = this.camelToSnakeUpperCase(key);
        // Specify that the 'expression of type string' is a key of the type of that object
        parsed[envKey] = data[key as keyof typeof data];
      }
    }
    const content = Object.entries(parsed)
      .map(([key, value]) => `${key}=${value}`)
      .join('\n');
    console.info(content);
    writeFileSync(path, content);
  }
}
