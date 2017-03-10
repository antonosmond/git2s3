'use strict';

const AWS = require('aws-sdk');
const request = require('request');

AWS.config.apiVersions = {
  s3: '2006-03-01',
  ssm: '2014-11-06'
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

function getPersonalAccessToken() {
  return new Promise((resolve, reject) => {
    const ssm = new AWS.SSM({ region: process.env.AWS_DEFAULT_REGION });
    const params = {
      Names: ['GitHubWebhookAccessToken'],
      WithDecryption: true
    };
    ssm.getParameters(params, (err, data) => {
      if (err) return reject(err);
      if (!data.Parameters.length) {
        return reject(new Error('GitHubWebhookAccessToken not found'));
      }
      return resolve(data.Parameters[0].Value);
    });
  });
}

function getReadStream(message, token) {
  return new Promise((resolve, reject) => {
    const options = {
      url: message.MessageAttributes.url.StringValue,
      encoding: null,
      followRedirect: true,
      headers: {
        'Authorization': `token ${token}`,
        'Accept': message.MessageAttributes.contentType.StringValue,
        'User-Agent': 'git2s3'
      }
    };
    request.get(options, (err, res, body) => {
      if (err) return reject(err);
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP GET ${options.url} returned ${res.statusCode} status code`));
      }
      return resolve(body);
    });
  });
}

function upload(message, stream) {
  return new Promise((resolve, reject) => {
    const s3 = new AWS.S3({ region: process.env.AWS_DEFAULT_REGION });
    const params = {
      Bucket: 'ctm-releases',
      Key: `${message.MessageAttributes.release.StringValue}/${message.MessageAttributes.name.StringValue}`,
      Body: stream
    };
    s3.upload(params, err => {
      if (err) return reject(err);
      return resolve();
    });
  });
}

function acknowledge(message) {
  return new Promise((resolve, reject) => {
    const sqs = new AWS.SQS({ region: process.env.AWS_SQS_REGION });
    const params = {
      QueueUrl: process.env.QUEUE_URL,
      ReceiptHandle: message.ReceiptHandle
    };
    sqs.deleteMessage(params, err => {
      if (err) return reject(err);
      return resolve();
    });
  });
}

exports.handler = (event, context, callback) => {

  // log the event and context for debugging
  console.log(event);
  console.log(context);

  getPersonalAccessToken()
    .then(token => getReadStream(event, token))
    .then(stream => upload(event, stream))
    .then(() => acknowledge(event))
    .then(() => callback(null, respond(200, 'OK')))
    .catch(err => {
      console.log(err);
      return callback(null, respond(500, 'Server Error'));
    });

};
