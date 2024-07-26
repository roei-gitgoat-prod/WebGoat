import * as cdk from '@aws-cdk/core';
import * as sqs from '@aws-cdk/aws-sqs';
import * as rename_sqs from '@aws-cdk/aws-sqs';
import {Queue, QueueEncryption} from '@aws-cdk/aws-sqs';

export class Stack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ruleid:awscdk-sqs-unencryptedqueue
    const unencryptedQueue1 = new sqs.Queue(this, 'unecryptedQueue1')

    // ruleid:awscdk-sqs-unencryptedqueue
    const unencryptedQueue2 = new sqs.Queue(this, 'unencryptedQueue2', {
        encryption: sqs.QueueEncryption.UNENCRYPTED
    })
  }
}
