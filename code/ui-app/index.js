const express = require('express')
const app = express()
const port = process.env.PORT || 3000
const request = require('request-promise-native')
const GATEWAY_URL = process.env.GATEWAY_URL || "http://gateway"

app.get('/', async (req, res) => {
  console.log(`${new Date()} in ui app, request gateway url ${GATEWAY_URL} `);
  let upResp;
  console.log('in /')
  console.log(` params : ${JSON.stringify(req.params)} headers: ${JSON.stringify(req.headers)}`);
  const headers = forwardTraceHeaders(req);
  try {
    upResp = await request({
      url: GATEWAY_URL + "/api/user/1/orders",
      headers
    });
    userOrder = JSON.parse(upResp);
  } catch (err) {
    console.log(`${new Date()} error in request to gateway ${err} `);
    upResp = err;
    return res.status(500).send(`error in request to gateway: ${upResp}`);
  }

  console.log(`${new Date()} response gateway ${upResp} `);
  const result = `
      <h1>Version v2</h1>
      <div>Hello!</div>
      <div>User: ${userOrder.user.name} Orders: </div>
      <div>id : ${userOrder.order.id}</div>
      <div>status : ${userOrder.order.status.status}</div>
  `;
  
  return res.end(result);
});

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

app.listen(port, () => console.log(`Example app listening on port ${port}!`))
