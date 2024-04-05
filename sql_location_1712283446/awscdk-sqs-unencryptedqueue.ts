import * as cdk from '@aws-cdk/core';
import * as sqs from '@aws-cdk/aws-sqs';
import * as rename_sqs from '@aws-cdk/aws-sqs';
import {Queue, QueueEncryption} from '@aws-cdk/aws-sqs';

export class Stack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    //ok:awscdk-sqs-unencryptedqueue
    const encryptedQueue1 = new sqs.Queue(this, 'encryptedQueue', {
        encryption: sqs.QueueEncryption.KMS_MANAGED
    })

    //ok:awscdk-sqs-unencryptedqueue
    const encryptedQueue2 = new sqs.Queue(this, 'encryptedQueue', {
        encryption: sqs.QueueEncryption.KMS
    })
  }
}
