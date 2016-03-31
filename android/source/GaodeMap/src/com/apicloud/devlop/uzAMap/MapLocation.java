//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.location.Location;
import android.os.Bundle;
import android.view.Display;
import android.view.Surface;
import android.view.WindowManager;

import com.amap.api.location.AMapLocation;
import com.amap.api.location.AMapLocationListener;
import com.amap.api.location.LocationManagerProxy;
import com.amap.api.location.LocationProviderProxy;
import com.amap.api.maps.AMap;
import com.amap.api.maps.LocationSource;
import com.apicloud.devlop.uzAMap.utils.CallBackUtil;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;

public class MapLocation implements LocationSource, AMapLocationListener,
		SensorEventListener {
	private Context mContext;
	private UZModuleContext mModuleContext;
	private AMap mMap;
	private OnLocationChangedListener mListener;
	private LocationManagerProxy mAMapLocationManager;
	private int mAccuracy;
	private float mMinDistance;
	private boolean mAutoStop;
	private SensorManager mSensorManager;
	private Sensor mSensor;

	public void getLocation(UZModuleContext moduleContext, Context context) {
		mContext = context;
		initSensor();
		UzMapView mMapView = new UzMapView(mContext);
		mMapView.onCreate(null);
		mMap = mMapView.getMap();
		mModuleContext = moduleContext;
		mAccuracy = moduleContext.optInt("accuracy", 10);
		mMinDistance = (float) moduleContext.optDouble("filter", 1.0);
		mAutoStop = moduleContext.optBoolean("autoStop", true);
		init();
	}

	public void stopLocation() {
		if (mMap != null) {
			mMap.setMyLocationEnabled(false);
		}
	}

	@SuppressWarnings("deprecation")
	private void initSensor() {
		mSensorManager = (SensorManager) mContext
				.getSystemService(Context.SENSOR_SERVICE);
		mSensor = mSensorManager.getDefaultSensor(Sensor.TYPE_ORIENTATION);
		mSensorManager.registerListener(this, mSensor,
				SensorManager.SENSOR_DELAY_FASTEST);
	}

	private void init() {
		if (mMap != null) {
			mMap.setLocationSource(this);
			mMap.setMyLocationEnabled(true);
		}
	}

	@Override
	public void onLocationChanged(Location location) {

	}

	@Override
	public void onStatusChanged(String provider, int status, Bundle extras) {

	}

	@Override
	public void onProviderEnabled(String provider) {

	}

	@Override
	public void onProviderDisabled(String provider) {

	}

	@Override
	public void onLocationChanged(AMapLocation aLocation) {
		boolean status = false;
		if (mListener != null && aLocation != null) {
			aLocation.setAccuracy(mAccuracy);
			status = true;
		}
		CallBackUtil
				.locationCallBack(mModuleContext, aLocation, mAngle, status);
		if (mAutoStop) {
			mMap.setMyLocationEnabled(false);
		}
	}

	@SuppressWarnings("deprecation")
	@Override
	public void activate(OnLocationChangedListener listener) {
		mListener = listener;
		if (mAMapLocationManager == null) {
			mAMapLocationManager = LocationManagerProxy.getInstance(mContext);
			mAMapLocationManager
					.requestLocationUpdates(LocationProviderProxy.AMapNetwork,
							2000, mMinDistance, this);
		}
	}

	@SuppressWarnings("deprecation")
	@Override
	public void deactivate() {
		mListener = null;
		if (mAMapLocationManager != null) {
			mAMapLocationManager.removeUpdates(this);
			mAMapLocationManager.destory();
		}
		mAMapLocationManager = null;
		mSensorManager.unregisterListener(this, mSensor);
	}

	@SuppressWarnings("deprecation")
	@Override
	public void onSensorChanged(SensorEvent event) {
		switch (event.sensor.getType()) {
		case Sensor.TYPE_ORIENTATION: {
			float x = event.values[0];
			x += getScreenRotationOnPhone(mContext);
			x %= 360.0F;
			if (x > 180.0F)
				x -= 360.0F;
			else if (x < -180.0F)
				x += 360.0F;
			mAngle = x;
			if (mAngle < 0) {
				mAngle = 360 + mAngle;
			}
		}
		}
	}

	private float mAngle;

	@Override
	public void onAccuracyChanged(Sensor sensor, int accuracy) {

	}

	public static int getScreenRotationOnPhone(Context context) {
		final Display display = ((WindowManager) context
				.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay();

		switch (display.getRotation()) {
		case Surface.ROTATION_0:
			return 0;

		case Surface.ROTATION_90:
			return 90;

		case Surface.ROTATION_180:
			return 180;

		case Surface.ROTATION_270:
			return -90;
		}
		return 0;
	}
}
