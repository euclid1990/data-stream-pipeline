#!/usr/bin/env node

/* Translating TypeScript AWS CDK code to other languages https://docs.aws.amazon.com/cdk/v2/guide/multiple_languages.html#multiple_languages_import */

import 'source-map-support/register';
import * as dotenv from 'dotenv';
import * as cdk from 'aws-cdk-lib';
import { CdkStack } from './cdk-stack';

dotenv.config();

const app: cdk.App = new cdk.App();
new CdkStack(app, process.env.CDK_STACK || 'CdkStack', {
  env: { account: process.env.CDK_ACCOUNT, region: process.env.CDK_REGION },
  /* For more information, see https://docs.aws.amazon.com/cdk/latest/guide/environments.html */
});
