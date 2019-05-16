//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.support.v4.app.NotificationCompat;
import android.util.Log;
import android.view.Display;
import android.view.Surface;
import android.view.WindowManager;

import org.json.JSONObject;

import com.amap.api.col.n3.fi;
import com.amap.api.col.n3.mo;
import com.amap.api.location.AMapLocation;
import com.amap.api.location.AMapLocationClient;
import com.amap.api.location.AMapLocationClientOption;
import com.amap.api.location.AMapLocationListener;
import com.amap.api.location.AMapLocationClientOption.AMapLocationMode;
import com.amap.api.maps.MapView;
import com.amap.api.maps.TextureMapView;
import com.apicloud.devlop.uzAMap.utils.CallBackUtil;
import com.uzmap.pkg.uzcore.UZCoreUtil;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

public class MapLocation implements AMapLocationListener, SensorEventListener {
	private Context mContext;
	private UZModuleContext mModuleContext;
	private int mAccuracy;
//	private float mMinDistance;
	private boolean mAutoStop;
//	private SensorManager mSensorManager;
//	private Sensor mSensor;
	private AMapLocationClient mLocationClient;
	private AMapLocationClientOption mLocationOption;

	public void getLocation(UZModuleContext moduleContext, Context context) {
		mContext = context;
		//initSensor();
		TextureMapView mMapView = new UzMapView(mContext);
		mMapView.onCreate(null);
		mModuleContext = moduleContext;
		mAccuracy = moduleContext.optInt("accuracy", 10);
//		mMinDistance = (float) moduleContext.optDouble("filter", 1.0);
		mAutoStop = moduleContext.optBoolean("autoStop", true);
		init();
	}

	public void stopLocation() {
		if (mLocationClient != null) {
			mLocationClient.stopLocation();
			//mLocationClient.onDestroy();
			mLocationClient.disableBackgroundLocation(true);
		}
	}

	@SuppressWarnings("deprecation")
//	private void initSensor() {
//		mSensorManager = (SensorManager) mContext
//				.getSystemService(Context.SENSOR_SERVICE);
//		mSensor = mSensorManager.getDefaultSensor(Sensor.TYPE_ORIENTATION);
//		mSensorManager.registerListener(this, mSensor,
//				SensorManager.SENSOR_DELAY_FASTEST);
//	}

	private void init() {
		mLocationClient = new AMapLocationClient(mContext);
		mLocationOption = new AMapLocationClientOption();
		mLocationOption.setLocationMode(AMapLocationMode.Hight_Accuracy);
		mLocationOption.setLocationCacheEnable(false);
		mLocationOption.setMockEnable(false);
		mLocationOption.setSensorEnable(true);
		mLocationOption.setOnceLocation(mAutoStop);
		mLocationClient.setLocationOption(mLocationOption);
		mLocationClient.setLocationListener(this);
		boolean enableLocInForeground = mModuleContext.optBoolean("enableLocInForeground", false);
		if (enableLocInForeground && !mAutoStop) {
			JSONObject notification = mModuleContext.optJSONObject("notification");
			if (notification == null) {
				notification = new JSONObject();
			}
			buildNotification(notification);
		}
		mLocationClient.startLocation();
	}
	
	private NotificationManager notificationManager = null;
	private static final int NOTYFY_ID = 10915;
	boolean isCreateChannel = false;
	@SuppressLint("NewApi")
	private void buildNotification(JSONObject notificationJson) {
		String title = notificationJson.optString("title", UZCoreUtil.getAppName());
		String contentText = notificationJson.optString("content", "正在后台运行");
		Notification notification = null;
		if (null == notificationManager) {
			notificationManager = (NotificationManager) mContext.getSystemService(Context.NOTIFICATION_SERVICE);
		}
		NotificationCompat.Builder builder = new NotificationCompat.Builder(mContext);;
		builder.setSmallIcon(getIconResId(mContext))
				.setContentTitle(title)
				.setContentText(contentText)
				.setWhen(System.currentTimeMillis())
				.setAutoCancel(false);

		if (android.os.Build.VERSION.SDK_INT >= 16) {
			notification = builder.build();
		} else {
			notification = builder.getNotification();
		}
		notification.flags |= Notification.FLAG_NO_CLEAR;
		notification.flags |= Notification.FLAG_ONGOING_EVENT;
		
		//notificationManager.notify(NOTYFY_ID, notification);
		mLocationClient.enableBackgroundLocation(NOTYFY_ID, notification);
	}
	
	private int getIconResId(Context context) {
		String pkg = context.getPackageName();
		PackageManager pkm = context.getPackageManager();
		try {
			ApplicationInfo appInfo = pkm.getApplicationInfo(pkg, 0);
			return appInfo.icon;
		} catch (Exception e) {
			e.printStackTrace();
		}
		return 0;
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

	@Override
	public void onLocationChanged(AMapLocation aLocation) {
		boolean status = false;
		if (aLocation != null) {
			aLocation.setAccuracy(mAccuracy);
			status = true;
		}
		CallBackUtil
				.locationCallBack(mModuleContext, aLocation, mAngle, status);
//		if (mAutoStop) {
//			stopLocation();
//		}
	}
}
