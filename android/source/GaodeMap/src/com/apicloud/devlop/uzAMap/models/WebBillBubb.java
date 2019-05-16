package com.apicloud.devlop.uzAMap.models;

public class WebBillBubb {
	private String id;
	private String url;
	private String data;
	private int width;
	private int height;
	public WebBillBubb(String id, String url, String data, int width, int height) {
		this.id = id;
		this.url = url;
		this.data = data;
		this.width = width;
		this.height = height;
	}
	
	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public String getUrl() {
		return url;
	}
	public void setUrl(String url) {
		this.url = url;
	}
	public String getData() {
		return data;
	}
	public void setData(String data) {
		this.data = data;
	}
	public int getWidth() {
		return width;
	}
	public void setWidth(int width) {
		this.width = width;
	}
	public int getHeight() {
		return height;
	}
	public void setHeight(int height) {
		this.height = height;
	}
	
	
	
}
