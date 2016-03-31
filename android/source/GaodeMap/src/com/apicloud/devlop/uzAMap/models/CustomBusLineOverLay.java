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
import com.amap.api.maps.overlay.BusLineOverlay;
import com.amap.api.services.busline.BusLineItem;

public class CustomBusLineOverLay extends BusLineOverlay {
	private int color;
	private float lineWidth;
	private String startPointImgPath;
	private String endPointImgPath;
	private String busPointImgPath;

	public CustomBusLineOverLay(Context context, AMap aMap,
			BusLineItem busLineItem) {
		super(context, aMap, busLineItem);
	}

	@Override
	protected int getBusColor() {
		return color;
	}

	@Override
	protected float getBuslineWidth() {
		return lineWidth;
	}

	public void setColor(int color) {
		this.color = color;
	}

	public void setLineWidth(float lineWidth) {
		this.lineWidth = lineWidth;
	}

	public void setStartPointImgPath(String startPointImgPath) {
		this.startPointImgPath = startPointImgPath;
	}

	public void setEndPointImgPath(String endPointImgPath) {
		this.endPointImgPath = endPointImgPath;
	}

	public void setBusPointImgPath(String busPointImgPath) {
		this.busPointImgPath = busPointImgPath;
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

}