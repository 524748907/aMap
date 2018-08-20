//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap.models;

import android.view.View;

import com.amap.api.maps.model.Marker;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;

public class Billboard {
	private String id;
	private double lat;
	private double lon;
	private boolean draggable;
	private Marker marker;
	private View view;
	private UZModuleContext moduleContext;
	private Bubble bubble;

	public Billboard(String id, double lat, double lon, boolean draggable,
			Marker marker, UZModuleContext moduleContext) {
		this.id = id;
		this.lat = lat;
		this.lon = lon;
		this.draggable = draggable;
		this.marker = marker;
		this.moduleContext = moduleContext;
	}

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public double getLat() {
		return lat;
	}

	public void setLat(double lat) {
		this.lat = lat;
	}

	public double getLon() {
		return lon;
	}

	public void setLon(double lon) {
		this.lon = lon;
	}

	public boolean isDraggable() {
		return draggable;
	}

	public void setDraggable(boolean draggable) {
		this.draggable = draggable;
	}

	public Marker getMarker() {
		return marker;
	}

	public void setMarker(Marker marker) {
		this.marker = marker;
	}

	public View getView() {
		return view;
	}

	public void setView(View view) {
		this.view = view;
	}

	public UZModuleContext getModuleContext() {
		return moduleContext;
	}

	public void setModuleContext(UZModuleContext moduleContext) {
		this.moduleContext = moduleContext;
	}

	public Bubble getBubble() {
		return bubble;
	}

	public void setBubble(Bubble bubble) {
		this.bubble = bubble;
	}
	
}
