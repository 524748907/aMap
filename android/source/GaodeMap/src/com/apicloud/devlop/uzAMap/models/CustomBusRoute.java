//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap.models;

import android.content.Context;
import com.amap.api.maps.AMap;
import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.maps.overlay.BusRouteOverlay;
import com.amap.api.services.core.LatLonPoint;
import com.amap.api.services.route.BusPath;

public class CustomBusRoute extends BusRouteOverlay {
	private int busColor;
	private int driveColor;
	private int walkColor;
	private float lineWidth;
	private String startPointImgPath;
	private String endPointImgPath;
	private String busPointImgPath;
	private String walkPointImgPath;
	private String drivePointImgPath;

	public CustomBusRoute(Context context, AMap aMap, BusPath busPath,
			LatLonPoint start, LatLonPoint end) {
		super(context, aMap, busPath, start, end);
	}

	public void setBusColor(int color) {
		this.busColor = color;
	}

	public void setDriveColor(int driveColor) {
		this.driveColor = driveColor;
	}

	public void setWalkColor(int walkColor) {
		this.walkColor = walkColor;
	}

	public void setBusPointImgPath(String busPointImgPath) {
		this.busPointImgPath = busPointImgPath;
	}

	public void setWalkPointImgPath(String walkPointImgPath) {
		this.walkPointImgPath = walkPointImgPath;
	}

	public void setDrivePointImgPath(String drivePointImgPath) {
		this.drivePointImgPath = drivePointImgPath;
	}

	public void setLineWidth(float lineWidth) {
		this.lineWidth = lineWidth;
	}

	@Override
	protected float getRouteWidth() {
		return lineWidth;
	}

	@Override
	protected int getBusColor() {
		return busColor;
	}

	@Override
	protected int getDriveColor() {
		return driveColor;
	}

	@Override
	protected int getWalkColor() {
		return walkColor;
	}

	public void setStartPointImgPath(String startPointImgPath) {
		this.startPointImgPath = startPointImgPath;
	}

	public void setEndPointImgPath(String endPointImgPath) {
		this.endPointImgPath = endPointImgPath;
	}

	@Override
	protected BitmapDescriptor getEndBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory
				.fromPath(endPointImgPath);
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getEndBitmapDescriptor();
	}

	@Override
	protected BitmapDescriptor getStartBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory
				.fromPath(startPointImgPath);
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getStartBitmapDescriptor();
	}

	@Override
	protected BitmapDescriptor getBusBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory
				.fromPath(busPointImgPath);
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getBusBitmapDescriptor();
	}

	@Override
	protected BitmapDescriptor getDriveBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory
				.fromPath(drivePointImgPath);
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getDriveBitmapDescriptor();
	}

	@Override
	protected BitmapDescriptor getWalkBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory
				.fromPath(walkPointImgPath);
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getWalkBitmapDescriptor();
	}
}