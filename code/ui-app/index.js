const express = require('express')
const app = express()
const port = process.env.PORT || 3000
const request = require('request-promise-native')

app.get('/', async (req, res) => {
  // const response = await callUserService();
  res.send('<div>Hello World!</div>')
});


async callUserService() {
  return await request({
			url: "http://users.svc/user/info",
			headers: headers
  });
}

app.listen(port, () => console.log(`Example app listening on port ${port}!`))
