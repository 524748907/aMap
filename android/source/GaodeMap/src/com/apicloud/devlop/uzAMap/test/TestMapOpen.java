package com.apicloud.devlop.uzAMap.test;

import com.apicloud.devlop.uzAMap.MapOpen;
import com.apicloud.devlop.uzAMap.MapShowUser;
import com.apicloud.devlop.uzAMap.MapSimple;
import com.apicloud.devlop.uzAMap.UzAMap;
import com.apicloud.devlop.uzAMap.UzMapView;
import com.apicloud.devlop.uzAMap.utils.CallBackUtil;
import com.apicloud.devlop.uzAMap.utils.JsParamsUtil;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

import android.annotation.SuppressLint;
import android.content.Context;
import android.view.View;
import android.view.View.OnAttachStateChangeListener;
import android.widget.RelativeLayout;
import android.widget.RelativeLayout.LayoutParams;

public class TestMapOpen {
	private TestMapView mMapView;
	private TestMapShowUser mShowUser;
	private int mX;
	private int mY;
	private int mW;
	private int mH;
	@SuppressLint("NewApi")
	public void openMap(UZGaoMap uzAMap, final UZModuleContext moduleContext,
			final Context context) {
		if (mMapView == null) {
			mMapView = new TestMapView(context);
			mMapView.onCreate(null);
			mMapView.onResume();
			final TestMapOpen map = this;
			mMapView.addOnAttachStateChangeListener(new OnAttachStateChangeListener() {
				@Override
				public void onViewDetachedFromWindow(View v) {
				}

				@Override
				public void onViewAttachedToWindow(View v) {
					MapSimple mapSimple = new MapSimple();
					mMapView.getMap().getUiSettings()
							.setZoomControlsEnabled(false);
					mapSimple.setCenterOpen(moduleContext, mMapView.getMap());
					boolean isShowUserLoc = moduleContext.optBoolean(
							"showUserLocation", true);
					if (isShowUserLoc) {
						if (mShowUser == null) {
							mShowUser = new TestMapShowUser();
						}
						mShowUser.showUserLocationOpen(map, context);
					}
				}
			});
			insertView(uzAMap, moduleContext, context, mMapView);
		} else {
			showMap();
		}
		CallBackUtil.openCallBack(moduleContext);
	}
	
	private void insertView(UZGaoMap uzAMap, UZModuleContext moduleContext,
			Context context, TestMapView mapView) {
		RelativeLayout.LayoutParams layoutParams = layoutParams(moduleContext, context);
		String fixedOn = moduleContext.optString("fixedOn");
		boolean fixed = moduleContext.optBoolean("fixed", true);
		uzAMap.insertViewToCurWindow(mapView, layoutParams, fixedOn, fixed);
	}
	
	public void showMap() {
		mMapView.setVisibility(View.VISIBLE);
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
	
	public TestMapView getMapView() {
		return mMapView;
	}
}
