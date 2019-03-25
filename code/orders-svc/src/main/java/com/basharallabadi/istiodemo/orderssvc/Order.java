package com.basharallabadi.istiodemo.orderssvc;

public class Order {
	public String id;
	public ShippingStatus status;

	public Order(){

	}

	public Order(String id, ShippingStatus shippingStatus) {
		this.id = id;
		this.status = shippingStatus;
	}
}