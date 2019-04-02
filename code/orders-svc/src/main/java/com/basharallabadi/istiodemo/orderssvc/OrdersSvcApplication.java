package com.basharallabadi.istiodemo.orderssvc;

import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.reactive.function.client.*;

import reactor.core.publisher.Mono;

@SpringBootApplication
public class OrdersSvcApplication {
	public static void main(String[] args) {
		SpringApplication.run(OrdersSvcApplication.class, args);
	}

	@Bean
	WebClient webClient() {
		return WebClient.builder().build();
	}
}

class ShippingStatus {
	public String status;
	public ShippingStatus() { }
}



@RestController
class OrdersController {

	final static Logger logger = LoggerFactory.getLogger(OrdersController.class);
	@Autowired
	WebClient webClient;

	@Value("${SHIPPING_URL:http://shipping}")
	String baseShippingUrl;
	
	@GetMapping("order")
	public Mono<Order> orders(@RequestParam String userId, ServerHttpRequest serverHttpRequest,
							  @RequestHeader(value = "x-request-id", required = false) String xreq,
							  @RequestHeader(name="x-b3-traceid", required = false) String xtraceid,
							  @RequestHeader(name="x-b3-spanid", required = false) String xspanid,
							  @RequestHeader(name="x-b3-parentspanid", required = false) String xparentspanid,
							  @RequestHeader(name="x-b3-sampled", required = false) String xsampled,
							  @RequestHeader(name="x-b3-flags", required = false) String xflags,
							  @RequestHeader(name="x-ot-span-context", required = false) String xotspan) {

		logger.trace(">>>>>>>>>>>>>>>>>>>>>>>> IN ORDERS <<<<<<<<<<<<<<<<<<<<<<<<<<<<<");
		logger.trace(" userID :{}, headers : {}", userId, serverHttpRequest.getHeaders());
		logger.trace(" requestId:{} ", xreq);

		String id = UUID.randomUUID().toString();
		return webClient
			.get()
			.uri(baseShippingUrl + "/shipping/" + id + "/status")
			.header("x-request-id", xreq)
			.header("x-b3-traceid", xtraceid)
			.header("x-b3-spanid", xspanid)
			.header("x-b3-parentspanid", xparentspanid)
			.header("x-b3-sampled", xsampled)
			.header("x-b3-flags", xflags)
			.header("x-ot-span-context", xotspan)
			.retrieve()
			.bodyToMono(ShippingStatus.class)
			.map((status) -> new Order(id, status));
	}
}

