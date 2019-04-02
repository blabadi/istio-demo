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
	public Mono<Order> orders(@RequestParam String userId, ServerHttpRequest serverHttpRequest) {
		logger.trace(">>>>>>>>>>>>>>>>>>>>>>>> IN ORDERS <<<<<<<<<<<<<<<<<<<<<<<<<<<<<");
		logger.trace(" userID :{}, headers : {}", userId, serverHttpRequest.getHeaders());
		
		String id = UUID.randomUUID().toString();
		return webClient
			.get()
			.uri(baseShippingUrl + "/shipping/" + id + "/status")
			.retrieve()
			.bodyToMono(ShippingStatus.class)
			.map((status) -> new Order(id, status));
	}
}

