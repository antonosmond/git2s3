'use strict';

const AWS = require('aws-sdk');

AWS.config.apiVersions = {
  lambda: '2015-03-31',
  sqs: '2012-11-05'
};

function respond(statusCode, message) {
  return {
    headers: {},
    statusCode: statusCode,
    body: JSON.stringify({
      message
    })
  };
}

function receiveMessages() {
  return new Promise((resolve, reject) => {
    const sqs = new AWS.SQS({ region: process.env.AWS_SQS_REGION });
    const params = {
      QueueUrl: process.env.QUEUE_URL,
      MessageAttributeNames: ['All'],
      MaxNumberOfMessages: 10,
      VisibilityTimeout: 420  // 7 minutes - 1 minute for scheduled consumer, 5 mins max for worker plus a minutes headroom
    };
    sqs.receiveMessage(params, (err, data) => {
      if (err) return reject(err);
      return resolve(data.Messages || []);
    });
  });
}

function invokeWorker(message) {
  return new Promise((resolve, reject) => {
    const lambda = new AWS.Lambda({ region: process.env.AWS_DEFAULT_REGION });
    const params = {
      FunctionName: 'git2s3-worker',
      InvocationType: 'Event',
      Payload: JSON.stringify(message)
    };
    lambda.invoke(params, (err, data) => {
      if (err) return reject(err);
      if (data.StatusCode !== 202) {
        return reject(new Error(`Received ${data.StatusCode} status when invoking ${params.FunctionName}`));
      }
      return resolve();
    });
  });
}

exports.handler = (event, context, callback) => {

  // log the event and context for debugging
  console.log(event);
  console.log(context);

  receiveMessages()
    .then(messages => {
      const promises = [];
      messages.forEach(msg => {
        promises.push(invokeWorker(msg));
      });
      return Promise.all(promises);
    })
    .then(() => callback(null, respond(200, 'OK')))
    .catch(err => {
      console.log(err);
      return callback(null, respond(500, 'Server Error'));
    });

};
