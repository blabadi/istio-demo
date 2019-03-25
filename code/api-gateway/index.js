const express = require('express')
const app = express()
const port = process.env.PORT || 3003
const request = require('request-promise-native')
const USER_UPSTREAM = process.env.USER_URL || "http://users"
const ORDER_UPSTREAM = process.env.ORDER_URL || "http://orders"

app.get('/', async (req, res) => {
  res.json({
    source: "api-gateway", 
    time: new Date()
  })
});

app.get('/api/user/:id/orders', async (req, res) => {
  let user;
  let order;
  try {
    user = await callUserService();
    order = await callOrderSvc();
    console.log(` user: ${user}, order ${order}`)
  } catch (err) {
    console.log(`error : ${err}`)
    return res.status(500).send(`error ${err}`)
  }

  const result = {
    user: JSON.parse(user), 
    order: JSON.parse(order)
  };

  console.log(`result : ${JSON.stringify(result)}`)
  return res.json(result);
});

const callUserService = async () => {
  return await request({
			url: `${USER_UPSTREAM}/user/1`,
  });
}

const callOrderSvc = async () => {
  return await request({
			url: `${ORDER_UPSTREAM}/order?userId=1`,
  });
}

app.listen(port, () => console.log(`api gateway listening on port ${port}!`))
