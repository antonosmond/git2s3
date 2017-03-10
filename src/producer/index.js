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

function validateSignature(event) {
  return new Promise((resolve, reject) => {
    const lambda = new AWS.Lambda({ region: process.env.AWS_DEFAULT_REGION });
    const params = {
      FunctionName: process.env.GITHUB_SIGNATURE_VERIFIER_FUNCTION,
      InvocationType: 'RequestResponse',
      Payload: JSON.stringify(event)
    };
    lambda.invoke(params, (err, data) => {
      if (err) return reject(err);
      if (data.StatusCode !== 200) {
        return reject(new Error(`Received ${data.StatusCode} status when invoking ${params.FunctionName}`));
      }
      return resolve(JSON.parse(data.Payload));
    });
  });
}

function sendMessages(body) {
  const release = `${body.repository.name}/${body.release.tag_name}`;
  const promises = [];
  body.release.assets.push({
    name: 'source.zip',
    content_override: 'application/json',
    url: body.release.zipball_url
  });
  body.release.assets.forEach(asset => {
    const p = new Promise((resolve, reject) => {
      const sqs = new AWS.SQS({ region: process.env.AWS_SQS_REGION });
      const params = {
        QueueUrl: process.env.QUEUE_URL,
        MessageAttributes: {
          release: {
            DataType: 'String',
            StringValue: release
          },
          name: {
            DataType: 'String',
            StringValue: asset.name
          },
          contentType:  {
            DataType: 'String',
            StringValue: asset.content_override || 'application/octet-stream'
          },
          url: {
            DataType: 'String',
            StringValue: asset.url
          }
        },
        MessageBody: `Request to upload '${asset.name}' to S3 from '${release}'`,
        MessageGroupId: 'git2s3'
      };
      sqs.sendMessage(params, err => {
        if (err) return reject(err);
        return resolve();
      });
    });
    promises.push(p);
  });
  return Promise.all(promises);
}

exports.handler = (event, context, callback) => {

  // log the event and context for debugging
  console.log(event);
  console.log(context);

  validateSignature(event)
    .then(response => {
      if (response.statusCode !== 200) {
        return callback(null, respond(response.statusCode, JSON.parse(response.body).message));
      }
      return JSON.parse(event.body);
    })
    .then(sendMessages)
    .then(() => callback(null, respond(200, 'OK')))
    .catch(err => {
      console.log(err);
      return callback(null, respond(500, 'Server Error'));
    });

};
