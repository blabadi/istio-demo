const express = require('express')
const app = express()
const port = process.env.PORT || 3001
const request = require('request-promise-native')

app.get('/', async (req, res) => {
  return res.json({
    source: "users-svc", 
    time: new Date()
  })
});

app.get('/user/:id', async (req, res) => {
  console.log('in /user/:id')
  console.log(` params : ${req.params} headers: ${JSON.stringify(req.headers)}`);
  
  return res.json({
    name: "bashar"
  })
});

app.listen(port, () => console.log(`user service listening on port ${port}!`))
