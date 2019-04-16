const fs = require('fs');
const dockerode = require('dockerode');
const ssh = require('ssh2');
const AWS = require('aws-sdk');
const async = require('async');
 
let formatStat = function(input)
{
  input = input.toString("UTF-8")
  
  let lines = input.trim().split("\n");
  let results = [];

  for (let line of lines)
  {
    let columns = line.split(/\s+/);

    results.push({
      "mode":
      {
        "number": parseInt(columns[0]),
        "text": columns[1]
      },
      "user":
      {
        "id": parseInt(columns[2]),
        "name": columns[8]
      },
      "group":
      {
        "id": parseInt(columns[3]),
        "name": columns[9]
      },
      "size": parseInt(columns[4]),
      "atime": parseInt(columns[5]),
      "mtime": parseInt(columns[6]),
      "links": parseInt(columns[7]),
      "name": columns.slice(10).join(" ")
    });
  }
  
  return results;
}


let getServiceArn = function(site, callback)
{
  let ecs = new AWS.ECS({region: process.env.REGION});
  ecs.listServices({cluster: process.env.CLUSTER_NAME}, (err, data) =>
  {
    let response = null;
    
    if (!err)
    {
      for (let arn of data.serviceArns)
      {
        if (arn.split("__")[1].replace(new RegExp("_", 'g'), ".") == site)
        {
          response = arn;
          break;
        }
      }
    }

    callback(response);
 });
}

let choiceTask = function(serviceArn, callback)
{
  let ecs = new AWS.ECS({region: process.env.REGION});
  ecs.listTasks({cluster: process.env.CLUSTER_NAME, desiredStatus: "RUNNING", serviceName: serviceArn}, (err, data) =>
  {
    callback(data.taskArns[Math.floor(Math.random() * data.taskArns.length)]);
 });
}

let getIpInstance = function(taskArn, callback)
{
  let ecs = new AWS.ECS({region: process.env.REGION});
  ecs.describeTasks({cluster: process.env.CLUSTER_NAME, tasks: [taskArn]}, (err, data) =>
  {
    ecs.describeContainerInstances({cluster: process.env.CLUSTER_NAME, containerInstances: [data.tasks[0].containerInstanceArn]}, (err, data) =>
    {
      let ec2 = new AWS.EC2({region: process.env.REGION});
      ec2.describeInstances({InstanceIds: [data.containerInstances[0].ec2InstanceId]}, (err, data) =>
      {
        callback(data.Reservations[0].Instances[0].PrivateIpAddress);
      })
    });
 });
}


let getContainerId = function(instanceIp, taskArn, callback)
{
  new dockerode({host: instanceIp, port: 2375}).listContainers((err, data) =>
  {
    let containerId = null;
    for (let container of data)
    {
      if (container.Labels['com.amazonaws.ecs.task-arn'] == taskArn)
      {
        containerId = container.Id
        break;
      }
    }
    
    callback(containerId);
  });
}



let container = null;

new ssh.Server
({
  hostKeys: [fs.readFileSync('./rsa_key')]
}, 
(client) =>
{
  console.log("Client connected!");

  client.on('authentication', (ctx) =>
  {
    console.log(ctx.method);
    if (ctx.method === "none")
      ctx.reject(['publickey']);
    else if (ctx.method === 'publickey')
    {
      let user = ctx.username.split(":");
      
      let iam = new AWS.IAM();
      
      iam.listSSHPublicKeys({UserName: user[0]}, (err, resultPublicKeysIds) =>
      {
        if (err)
          ctx.reject();
        else
        {
          let foundKey = false;
          async.map(resultPublicKeysIds.SSHPublicKeys, (key, callback) =>
          {
            if (key.Status == "Active")
            {
              iam.getSSHPublicKey({UserName: user[0], SSHPublicKeyId: key.SSHPublicKeyId, Encoding: "SSH"}, (err, resultPublicKeys) =>
              {
                if (resultPublicKeys.SSHPublicKey.SSHPublicKeyBody == ("ssh-rsa " + ctx.key.data.toString('base64')))
                  foundKey = true;
                  
                callback();
              });
            }
            else
              callback();
          }, 
          (erro, results) =>
          {
            if (foundKey)
            {
              getServiceArn(user[1], (serviceArn) =>
              {
                if (serviceArn != null)
                {
                  choiceTask(serviceArn, (taskArn) =>
                  {
                    getIpInstance(taskArn, (instanceIp) =>
                    {
                      getContainerId(instanceIp, taskArn, (containerId) =>
                      {
                        container = new dockerode({host: instanceIp, port: 2375}).getContainer(containerId);
          
                        ctx.accept();
                      });
                    })
                  })
                }
                else
                  ctx.reject();
              });
            }
            else
              ctx.reject();
          });
        }
      })
    }
    else
      ctx.reject();
  })
  
  client.on('ready', () =>
  {
    console.log('Client authenticated!');
    client.on('session', (accept, reject) =>
    {
      console.log('Client wants new session');
      let session = accept();
      
      session.on('sftp', function(accept, reject) 
      {
        console.log('Client SFTP session');

        let openFiles = {};
        let openDirs = {};
        let canReadFile = true;
        let canWriteFile = true;
        let canReadDir = true;
        
        let handleCount = 0;
   
        var sftpStream = accept();
        sftpStream.on('OPEN', (reqID, file, flags, attrs) =>
        {
          console.log("debug OPEN")
          
          var handle = new Buffer(4);
          openFiles[handleCount] = file;
          handle.writeUInt32BE(handleCount++, 0, true);
          sftpStream.handle(reqID, handle);
        });
        
        sftpStream.on('READ', function(reqID, handle, offset, length)
        {
          console.log("debug READ -> reqID(" + reqID + "), handle(" + handle.readUInt32BE(0, true) + "), offset(" + offset + "), length(" + length + ")")
          
          if (canReadFile)
          {
            canReadFile = false;
            let file = openFiles[handle.readUInt32BE(0, true)];

            container.exec({Cmd: ['bash', '-c', 'cat ' + file], AttachStdout: true}, (err, exec) =>
            {
              exec.start({Tty: true}, (err, stream) =>
              {
                // Attach output streams to client stream.
                stream.on("data", (result) =>
                {
                  sftpStream.data(reqID, result);
                });
              });
            });
          }
          else
          {
            sftpStream.status(reqID, ssh.SFTP_STATUS_CODE.EOF);
            canReadFile = true;
          }
        });
        
        sftpStream.on('WRITE', (reqid, handle, offset, data) =>
        {
          let file = openFiles[handle.readUInt32BE(0, true)];

          container.exec({Cmd: ['bash', '-c', 'echo -e "' + data + '" > ' + file], AttachStdout: true}, (err, exec) =>
          {
            exec.start({Tty: true}, (err, stream) => 
            {
              // Attach output streams to client stream.
              stream.on("end", () =>
              {
                sftpStream.status(reqid, ssh.SFTP_STATUS_CODE.OK);
              });
            });
          });
        });
        
        sftpStream.on('FSETSTAT', (reqid, handle, attrs) =>
        {
          console.log ("debug FSETSTAT -> ");
        });
        
        sftpStream.on('OPENDIR', (reqID, path) =>
        {
          console.log("debug OPENDIR -> " + reqID + "," + path)
          
          var handle = new Buffer(4);
          openDirs[handleCount] = path;
          handle.writeUInt32BE(handleCount++, 0, true);
          sftpStream.handle(reqID, handle);
        });
        
        sftpStream.on('READDIR', (reqID, handle) =>
        {
          let dir = openDirs[handle.readUInt32BE(0, true)];

          if (canReadDir)
          {
            canReadDir = false;
            console.log("debug READDIR -> " + reqID + "," + dir);

            container.exec({Cmd: ['bash', '-c', 'cd ' + dir + ' && stat -c "%a %A %u %g %s %X %Y %h %U %G %n" *'], AttachStdout: true}, (err, exec) =>
            {
              exec.start({Tty: true}, (err, stream) =>
              {
                // Attach output streams to client stream.
                stream.on("data", (result) =>
                {
                  let files = formatStat(result);

                  let vector = [];
                  
                  for (let file of files)
                  {
                    vector.push({
                      filename: file.name,
                      longname: file.mode.text + " " + file.links + " " + file.user.name + " " + file.group.name + " " + file.mtime + " " + file.name,
                      attrs: 
                      {
                        "mode": file.mode.number,
                        "uid": file.user.id,
                        "gid": file.group.id,
                        "size": file.size,
                        "atime": file.atime,
                        "mtime": file.mtime
                      }
                    });
                  }

                  sftpStream.name(reqID, vector);
                });
              });
            });
          }
          else 
          {
            canReadDir = true;
            sftpStream.status(reqID, ssh.SFTP_STATUS_CODE.EOF);
          }
        });
        
        
        let STAT = function(reqID, path)
        {
          console.log("debug STAT -> " + reqID + "," + path)

          container.exec({Cmd: ['bash', '-c', 'stat -c "%a %A %u %g %s %X %Y %h %U %G %n" ' +  path], AttachStdout: true}, (err, exec) =>
          {
            exec.start({Tty: true}, (err, stream) =>
            {
              let hasError = true;
              
              // Attach output streams to client stream.
              stream.on("end", (err) =>
              {
                if (hasError)
                  sftpStream.status(reqID, ssh.SFTP_STATUS_CODE.NO_SUCH_FILE);
              });
              
              // Attach output streams to client stream.
              stream.on("data", (result) =>
              {
                hasError = false;
                
                let files = formatStat(result);
                
                sftpStream.attrs(reqID, 
                {
                  "mode": files[0].mode.number,
                  "uid": files[0].user.id,
                  "gid": files[0].group.id,
                  "size": files[0].size,
                  "atime": files[0].atime,
                  "mtime": files[0].mtime
                });
              });
            });
          });
        }
        
        sftpStream.on('STAT', STAT);
        sftpStream.on('LSTAT', STAT);
        
        sftpStream.on('REALPATH', (reqID, path) =>
        {
          console.log("debug REALPATH -> " + reqID + "," + path)
          sftpStream.name(reqID, [{
            filename: path,
            attrs: {}
          }]);
        });
        
        
        sftpStream.on('CLOSE', function(reqID, handle) 
        {
          handle = handle.readUInt32BE(0, true);
          
          console.log("debug CLOSE -> " + reqID + "," + handle)
          sftpStream.status(reqID, ssh.SFTP_STATUS_CODE.OK);
        });
      });
       
      session.once('pty', (accept, reject, info) =>
      {
        accept();
      });
      
      session.once('shell', (accept, reject) =>
      {
        console.log('Client wants a shell!');
        
        // Accept the connection and get a bidirectional stream.
        let stream = accept();
        
        container.exec({Cmd: ['/bin/bash'], AttachStdin: true, AttachStdout: true, Tty: true}, (err, exec) =>
        {
          exec.start({hijack: true, stdin: true, Tty: true}, (err, ttyStream) =>
          {
            // Attach output streams to client stream.
            ttyStream.pipe(stream);
  
            // Attach client stream to stdin of container
            stream.pipe(ttyStream);
          });
        });
      });
    });
  })
  
  client.on('abort', () =>
  {
    console.log('Client aborted!');
  })
  
  client.on('error', (err) =>
  {
    console.log('Client error! -> ' + err);
  })
  
  client.on('end', () =>
  {
    console.log('Client disconnected!');
  });
})
.listen(22, '0.0.0.0', function ()
{
  console.log('Listening on port ' + this.address().port);
});