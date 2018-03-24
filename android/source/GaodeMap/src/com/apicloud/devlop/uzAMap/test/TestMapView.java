package com.apicloud.devlop.uzAMap.test;

import com.amap.api.maps.MapView;

import android.content.Context;
import android.view.MotionEvent;
import android.view.ViewParent;

public class TestMapView extends MapView{
	public TestMapView(Context context) {
		super(context);
	}

	@Override
	public boolean onTouchEvent(MotionEvent ev) {
		try {
			return super.onTouchEvent(ev);
		} catch (IllegalArgumentException ex) {
			ex.printStackTrace();
		}
		return false;
	}

	@Override
	public boolean onInterceptTouchEvent(MotionEvent ev) {
		try {
			requestParentDisallowInterceptTouchEvent(true);
			return super.onInterceptTouchEvent(ev);
		} catch (IllegalArgumentException ex) {
			ex.printStackTrace();
		}
		return false;
	}

	private void requestParentDisallowInterceptTouchEvent(
			boolean disallowIntercept) {
		final ViewParent parent = getParent();
		if (parent != null) {
			parent.requestDisallowInterceptTouchEvent(disallowIntercept);
		}
	}
}
