const express = require('express')
const app = express()
const port = process.env.PORT || 3005
const request = require('request-promise-native')

app.get('/', async (req, res) => {
  res.json({
    source: "shipping-svc", 
    time: new Date()
  })
});

app.get('/shipping/:orderid/status', async (req, res) => {
  console.log('in /shipping/:orderid/status')
  console.log(`params : ${JSON.stringify(req.params)} headers: ${JSON.stringify(req.headers)}`);
  res.json({
    status: 'shipped'
  })
});

app.listen(port, () => console.log(`shipping service listening on port ${port}!`))
