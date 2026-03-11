const http = require('http');

const req = http.request({
  hostname: '47.129.247.210',
  port: 5000,
  path: '/api/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  }
}, (res) => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => console.log('Login Body:', body));
});

// Since we don't know the password, let's see if we can just get permits 
// wait we need token. Let's create a user
req.write(JSON.stringify({email: 'test@test.com', password: 'password'}));
req.end();
