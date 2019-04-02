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
  console.log('in /api/user/:id/orders')
  console.log(` params : ${req.params} headers: ${JSON.stringify(req.headers)}`);
  const headers = forwardTraceHeaders(req)
  try {
    user = await callUserService(headers);
    order = await callOrderSvc(headers);
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

const callUserService = async (headers) => {
  return await request({
      url: `${USER_UPSTREAM}/user/1`,
      headers
  });
}

const callOrderSvc = async (headers) => {
  return await request({
      url: `${ORDER_UPSTREAM}/order?userId=1`,
      headers
  });
}


function forwardTraceHeaders(req) {
	incoming_headers = [
		'x-request-id',
		'x-b3-traceid',
		'x-b3-spanid',
		'x-b3-parentspanid',
		'x-b3-sampled',
		'x-b3-flags',
		'x-ot-span-context',
		'x-end-user',
	]
	const headers = {}
	for (let h of incoming_headers) {
		if (req.header(h))
			headers[h] = req.header(h)
	}
	return headers
}

app.listen(port, () => console.log(`api gateway listening on port ${port}!`))
