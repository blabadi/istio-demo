const express = require('express')
const app = express()
const port = process.env.PORT || 3000
const request = require('request-promise-native')
const GATEWAY_URL = process.env.GATEWAY_URL || "http://gateway"

app.get('/', async (req, res) => {
  console.log(`${new Date()} in ui app, request gateway url ${GATEWAY_URL} `);
  let upResp;
  try {
    upResp = await request({
			url: GATEWAY_URL + "/api/user/1/orders"
    });
    userOrder = JSON.parse(upResp);
  } catch (err) {
    console.log(`${new Date()} error in request to gateway ${err} `);
    upResp = err;
    return res.status(500).send(`error in request to gateway: ${upResp}`);
  }

  console.log(`${new Date()} response gateway ${upResp} `);
  const result = `<div>Hello!</div>
      <div>User: ${userOrder.user.name} Orders: </div>
      <div>id : ${userOrder.order.id}</div>
      <div>status : ${userOrder.order.status.status}</div>
  `;
  
  return res.end(result);
});

app.listen(port, () => console.log(`Example app listening on port ${port}!`))
