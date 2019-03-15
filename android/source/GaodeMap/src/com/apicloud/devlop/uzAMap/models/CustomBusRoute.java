//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap.models;

import java.io.IOException;
import android.content.Context;
import android.graphics.BitmapFactory;
import com.amap.api.maps.AMap;
import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.services.core.LatLonPoint;
import com.amap.api.services.route.BusPath;
import com.apicloud.devlop.uzAMap.overlay.BusRouteOverlay;
import com.uzmap.pkg.uzkit.UZUtility;

public class CustomBusRoute extends BusRouteOverlay {
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
	
	private boolean walkLineDash;
	public void setWalkLineDash(boolean lineDash) {
		this.walkLineDash = lineDash;
	}
	
	private boolean driveLineDash;
	public void setDriveLineDash(boolean lineDash) {
		this.driveLineDash = lineDash;
	}
	
	private boolean busLineDash;
	public void setBusLineDash(boolean lineDash) {
		this.busLineDash = lineDash;
	}
	
	private boolean rideLineDash;
	public void setRideLineDash(boolean line) {
		this.rideLineDash = line;
	}
	
	@Override
	protected boolean getBusLineDash() {
		return busLineDash;
	}
	
	@Override
	protected boolean getDriveLineDash() {
		return driveLineDash;
	}
	
	@Override
	protected boolean getWalkLineDash() {
		return walkLineDash;
	}
	
	@Override
	protected boolean getRideLineDash() {
		return rideLineDash;
	}
	
	private String busStrokeImg;
	public void setBusStrokeImg(String img) {
		this.busStrokeImg = img;
	}
	@Override
	protected String getBusStrokeImg() {
		return busStrokeImg;
	}
	
	private String driveStrokeImg;
	public void setDriveStrokeImg(String img) {
		this.driveStrokeImg = img;
	}
	@Override
	protected String getDriveStrokeImg() {
		return driveStrokeImg;
	}
	
	private String walkStrokeImg;
	public void setWalkStrokeImg(String img) {
		this.walkStrokeImg = img;
	}
	@Override
	protected String getWalkStrokeImg() {
		return walkStrokeImg;
	}
	
	private String rideStrokeImg;
	public void setRideStrokeImg(String img) {
		this.rideStrokeImg = img;
	}
	@Override
	protected String getRideStrokeImg() {
		return rideStrokeImg;
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