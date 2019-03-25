package com.basharallabadi.istiodemo.orderssvc;

import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.reactive.function.client.WebClient;

import reactor.core.publisher.Mono;

@SpringBootApplication
public class OrdersSvcApplication {
	public static void main(String[] args) {
		SpringApplication.run(OrdersSvcApplication.class, args);
	}
}

class ShippingStatus {
	public String status;
	public ShippingStatus() {

	}
}



@RestController
class OrdersController {

	@Value("${SHIPPING_URL:http://shipping}")
	String baseShippingUrl;
	
	@GetMapping("order")
	public Mono<Order> orders(@RequestParam String userId) {
		String id = UUID.randomUUID().toString();
		return WebClient.create(baseShippingUrl)
			.get()
			.uri("/shipping/" + id + "/status")
			.retrieve()
			.bodyToMono(ShippingStatus.class)
			.map((status) -> new Order(id, status));
	}
}

