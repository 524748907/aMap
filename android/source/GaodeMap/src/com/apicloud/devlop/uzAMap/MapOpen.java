//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap;

import org.json.JSONObject;
import android.annotation.SuppressLint;
import android.content.Context;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.View.OnAttachStateChangeListener;
import android.view.ViewGroup.MarginLayoutParams;
import android.widget.AbsoluteLayout;
import android.widget.FrameLayout;
import android.widget.RelativeLayout;
import android.widget.RelativeLayout.LayoutParams;

import com.amap.api.col.n3.in;
import com.amap.api.location.AMapLocationClient;
import com.amap.api.maps.AMap;
import com.amap.api.maps.UiSettings;
import com.apicloud.devlop.uzAMap.utils.CallBackUtil;
import com.apicloud.devlop.uzAMap.utils.JsParamsUtil;
import com.uzmap.pkg.uzcore.UZCoreUtil;
import com.uzmap.pkg.uzcore.UZResourcesIDFinder;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

@SuppressWarnings("deprecation")
public class MapOpen {

	private UzMapView mMapView;
	private MapShowUser mShowUser;
	private int mX;
	private int mY;
	private int mW;
	private int mH;

	@SuppressLint("NewApi")
	public void openMap(UzAMap uzAMap, final UZModuleContext moduleContext,
			final Context context) {
		if (mMapView == null) {
//			int mapId = UZResourcesIDFinder.getResLayoutID("basicmap");
//			View parView = LayoutInflater.from(context).inflate(mapId, null);
//			int mapViewId = UZResourcesIDFinder.getResIdID("map");
//			mMapView = (UzMapView) parView.findViewById(mapViewId);
			
			mMapView = new UzMapView(context);
			//mMapView.setLayerType(View.LAYER_TYPE_HARDWARE, null);
			
			mMapView.onCreate(null);
			mMapView.onResume();
			
			final MapOpen map = this;
			mMapView.addOnAttachStateChangeListener(new OnAttachStateChangeListener() {
				@Override
				public void onViewDetachedFromWindow(View v) {
				}

				@Override
				public void onViewAttachedToWindow(View v) {
					MapSimple mapSimple = new MapSimple();
					if (mMapView.getMap() != null) {
						UiSettings uiSettings = mMapView.getMap().getUiSettings();
						if (uiSettings != null) {
							uiSettings.setZoomControlsEnabled(false);
							boolean isGestureScaleByMapCenter = moduleContext.optBoolean("isGestureScaleByMapCenter", false);
							uiSettings.setGestureScaleByMapCenter(isGestureScaleByMapCenter);
						}
					}
					
					mapSimple.setCenterOpen(moduleContext, mMapView.getMap());
					boolean isShowUserLoc = moduleContext.optBoolean("showUserLocation", true);
					if (isShowUserLoc) {
						if (mShowUser == null) {
							mShowUser = new MapShowUser();
						}
						mShowUser.showUserLocationOpen(map, context, moduleContext);
					}
				}
			});
			
			insertView(uzAMap, moduleContext, context, mMapView);
		} else {
			showMap();
		}
		CallBackUtil.openCallBack(moduleContext);
	}
	
	public void onPause(){
		if (mMapView != null) {
			mMapView.onPause();
		}
	}
	
	public void onResume(){
		if (mMapView != null) {
			mMapView.onResume();
		}
	}
	
	public void onDestroy(){
		if (mMapView != null) {
			mMapView.onDestroy();
		}
	}
	
	public void onSaveInstance(){
		if (mMapView != null) {
			mMapView.onSaveInstanceState(null);
		}
	}

	public void closeMap(UzAMap uzAMap) {
		uzAMap.removeViewFromCurWindow(mMapView);
		AMapLocationClient client = mShowUser.getAMapLocationClient();
		if (client != null) {
			client.stopLocation();
		}
		
		mMapView.onPause();
		mMapView.onDestroy();
		mMapView = null;
	}

	public void showMap() {
		mMapView.setVisibility(View.VISIBLE);
	}

	public void hideMap() {
		mMapView.setVisibility(View.GONE);
	}

	public void setRect(UZModuleContext moduleContext) {
		JSONObject rect = moduleContext.optJSONObject("rect");
		int x = UZCoreUtil.pixToDip(mX);
		int y = UZCoreUtil.pixToDip(mY);
		int w = UZCoreUtil.pixToDip(mW);
		int h = UZCoreUtil.pixToDip(mH);
		if (rect != null) {
			x = UZUtility.dipToPix(rect.optInt("x", x));
			y = UZUtility.dipToPix(rect.optInt("y", y));
			w = UZUtility.dipToPix(rect.optInt("w", w));
			h = UZUtility.dipToPix(rect.optInt("h", h));
			mX = x;
			mY = y;
			mW = w;
			mH = h;
		}
		if (mMapView.getLayoutParams() instanceof FrameLayout.LayoutParams) {
			FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(w, h);
			p.setMargins(x, y, 0, 0);
			mMapView.setLayoutParams(p);
		} else if (mMapView.getLayoutParams() instanceof MarginLayoutParams) {
			LayoutParams p = new LayoutParams(w, h);
			p.setMargins(x, y, 0, 0);
			mMapView.setLayoutParams(p);
		} else {
			AbsoluteLayout.LayoutParams p = new AbsoluteLayout.LayoutParams(w,
					h, x, y);
			mMapView.setLayoutParams(p);
		}
	}

	private void insertView(UzAMap uzAMap, UZModuleContext moduleContext,
			Context context, View mapView) {
		RelativeLayout.LayoutParams layoutParams = layoutParams(moduleContext, context);
		String fixedOn = moduleContext.optString("fixedOn");
		boolean fixed = moduleContext.optBoolean("fixed", true);
		uzAMap.insertViewToCurWindow(mapView, layoutParams, fixedOn, fixed);
	}

	private RelativeLayout.LayoutParams layoutParams(UZModuleContext moduleContext,
			Context context) {
		JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
		int x = jsParamsUtil.x(moduleContext);
		int y = jsParamsUtil.y(moduleContext);
		int w = jsParamsUtil.w(moduleContext, context);
		int h = jsParamsUtil.h(moduleContext, context);
		mX = UZUtility.dipToPix(x);
		mY = UZUtility.dipToPix(y);
		mW = UZUtility.dipToPix(w);
		mH = UZUtility.dipToPix(h);
		LayoutParams layoutParams = new LayoutParams(w, h);
		layoutParams.setMargins(x, y, 0, 0);
		return layoutParams;
	}

	public UzMapView getMapView() {
		return mMapView;
	}

	public MapShowUser getShowUser() {
		return mShowUser;
	}

	public void setShowUser(MapShowUser showUser) {
		this.mShowUser = showUser;
	}
}
