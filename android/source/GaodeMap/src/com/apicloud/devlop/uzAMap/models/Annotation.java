//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap.models;

import java.util.List;

import com.alibaba.idst.nls.internal.VoiceActDetector;
import com.amap.api.maps.model.Marker;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

import android.graphics.Bitmap;

public class Annotation {
	private String id;
	private Marker marker;
	private double lat;
	private double lon;
	private List<Bitmap> icons;
	private List<String> iconsPath;
	private boolean draggable;
	private double timeInterval;
	private UZModuleContext moduleContext;
	private List<Bitmap> selectIcons;
	private List<String> selectIconsPath;

	public Annotation() {
	}

	public Annotation(String id, double lat, double lon, List<Bitmap> icons,
			List<String> iconsPath, boolean draggable, double timeInterval) {
		this.id = id;
		this.lat = lat;
		this.lon = lon;
		this.icons = icons;
		this.iconsPath = iconsPath;
		this.draggable = draggable;
		this.timeInterval = timeInterval;
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

	public List<Bitmap> getIcons() {
		return icons;
	}

	public void setIcons(List<Bitmap> icons) {
		this.icons = icons;
	}

	public boolean isDraggable() {
		return draggable;
	}

	public void setDraggable(boolean draggable) {
		this.draggable = draggable;
	}

	public double getTimeInterval() {
		return timeInterval;
	}

	public void setTimeInterval(double timeInterval) {
		this.timeInterval = timeInterval;
	}

	public Marker getMarker() {
		return marker;
	}

	public void setMarker(Marker marker) {
		this.marker = marker;
	}

	public UZModuleContext getModuleContext() {
		return moduleContext;
	}

	public void setModuleContext(UZModuleContext moduleContext) {
		this.moduleContext = moduleContext;
	}

	public List<String> getIconsPath() {
		return iconsPath;
	}

	public void setIconsPath(List<String> iconsPath) {
		this.iconsPath = iconsPath;
	}

	public List<Bitmap> getSelectIcons() {
		return selectIcons;
	}

	public void setSelectIcons(List<Bitmap> selectIcons) {
		this.selectIcons = selectIcons;
	}

	public List<String> getSelectIconsPath() {
		return selectIconsPath;
	}

	public void setSelectIconsPath(List<String> selectIconsPath) {
		this.selectIconsPath = selectIconsPath;
	}
	
	private int width;
	public void setWidth(int width) {
		this.width = width;
	}
	
	public int getWidth() {
		return width;
	}
	
	private int height;
	public void setHeight(int height) {
		this.height = height;
	}
	
	public int getHeight() {
		return height;
	}
	
	private boolean locked;
	public void setLocked(boolean locked) {
		this.locked = locked;
	}
	
	public boolean locked() {
		return locked;
	}
	
	private int lockedX;
	public void setLockedX(int lockedX) {
		this.lockedX = lockedX;
	}
	
	public int getLockedX() {
		return UZUtility.dipToPix(lockedX);
	}
	
	private int lockedY;
	public void setLockedY(int lockedY) {
		this.lockedY = lockedY;
	}
	
	public int getLockedY() {
		return UZUtility.dipToPix(lockedY);
	}
	
	
}
