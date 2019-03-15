//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap.models;

import java.io.IOException;
import java.util.List;

import android.content.Context;
import android.graphics.BitmapFactory;

import com.amap.api.maps.AMap;
import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.services.core.LatLonPoint;
import com.amap.api.services.route.DrivePath;
import com.apicloud.devlop.uzAMap.overlay.DrivingRouteOverlay;
import com.uzmap.pkg.uzkit.UZUtility;

public class CustomDriveRoute extends DrivingRouteOverlay {
	private int busColor;
	private int driveColor;
	private int walkColor;
	private int rideColor;
	private float lineWidth;
	private String startPointImgPath;
	private String endPointImgPath;
	private String busPointImgPath;
	private String walkPointImgPath;
	private String drivePointImgPath;
	private String ridePointImgPath;
	
	private boolean lineDash;
	private String strokeImg;

	public CustomDriveRoute(Context context, AMap aMap, DrivePath drivePath,
			LatLonPoint start, LatLonPoint end, List<LatLonPoint> throughPointList) {
		super(context, aMap, drivePath, start, end, throughPointList);
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
	
	public void setRideColor(int rideColor) {
		this.rideColor = rideColor;
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
	
	public void setRidePointImgPath(String ridePointImgPath) {
		this.ridePointImgPath = ridePointImgPath;
	}

	public void setLineWidth(float lineWidth) {
		this.lineWidth = lineWidth;
	}
	
	public void setLineDash(boolean lineDash) {
		this.lineDash = lineDash;
	}
	
	public void setStrokeImg(String path) {
		this.strokeImg = path;
	}
	
	@Override
	protected String getStrokeImg() {
		return strokeImg;
	}
	
	@Override
	protected boolean getDriveLineDash() {
		return lineDash;
	}
	
	@Override
	protected String getBusStrokeImg() {
		return strokeImg;
	}

	@Override
	public float getRouteWidth() {
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
	
	@Override
	protected int getRideColor() {
		return rideColor;
	}

	public void setStartPointImgPath(String startPointImgPath) {
		this.startPointImgPath = startPointImgPath;
	}

	public void setEndPointImgPath(String endPointImgPath) {
		this.endPointImgPath = endPointImgPath;
	}

	@Override
	protected BitmapDescriptor getEndBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = null;
		try {
			bitmapDescriptor = BitmapDescriptorFactory
					.fromBitmap(BitmapFactory.decodeStream(UZUtility
							.guessInputStream(endPointImgPath)));
		} catch (IOException e) {
			e.printStackTrace();
		}
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getEndBitmapDescriptor();
	}

	@Override
	protected BitmapDescriptor getStartBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = null;
		try {
			bitmapDescriptor = BitmapDescriptorFactory
					.fromBitmap(BitmapFactory.decodeStream(UZUtility
							.guessInputStream(startPointImgPath)));
		} catch (IOException e) {
			e.printStackTrace();
		}
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getStartBitmapDescriptor();
	}

	@Override
	protected BitmapDescriptor getBusBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = null;
		try {
			bitmapDescriptor = BitmapDescriptorFactory
					.fromBitmap(BitmapFactory.decodeStream(UZUtility
							.guessInputStream(busPointImgPath)));
		} catch (IOException e) {
			e.printStackTrace();
		}
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getBusBitmapDescriptor();
	}

	@Override
	protected BitmapDescriptor getDriveBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = null;
		try {
			bitmapDescriptor = BitmapDescriptorFactory
					.fromBitmap(BitmapFactory.decodeStream(UZUtility
							.guessInputStream(drivePointImgPath)));
		} catch (IOException e) {
			e.printStackTrace();
		}
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getDriveBitmapDescriptor();
	}

	@Override
	protected BitmapDescriptor getWalkBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = null;
		try {
			bitmapDescriptor = BitmapDescriptorFactory
					.fromBitmap(BitmapFactory.decodeStream(UZUtility
							.guessInputStream(walkPointImgPath)));
		} catch (IOException e) {
			e.printStackTrace();
		}
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getWalkBitmapDescriptor();
	}
	
	@Override
	protected BitmapDescriptor getRideBitmapDescriptor() {
		BitmapDescriptor bitmapDescriptor = null;
		try {
			bitmapDescriptor = BitmapDescriptorFactory
					.fromBitmap(BitmapFactory.decodeStream(UZUtility
							.guessInputStream(ridePointImgPath)));
		} catch (IOException e) {
			e.printStackTrace();
		}
		if (bitmapDescriptor != null) {
			return bitmapDescriptor;
		}
		return super.getWalkBitmapDescriptor();
	}
}