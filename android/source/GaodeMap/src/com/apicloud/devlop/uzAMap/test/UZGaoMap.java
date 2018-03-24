package com.apicloud.devlop.uzAMap.test;

import com.uzmap.pkg.uzcore.UZWebView;
import com.uzmap.pkg.uzcore.uzmodule.UZModule;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;

public class UZGaoMap extends UZModule{
	private TestMapOpen mMap;
	public UZGaoMap(UZWebView webView) {
		super(webView);
		// TODO Auto-generated constructor stub
	}
	
	public void jsmethod_open(UZModuleContext moduleContext) {
		if (mMap == null) {
			mMap = new TestMapOpen();
		}
		mMap.openMap(this, moduleContext, mContext);
	}
	
	public void jsmethod_addEventListener(UZModuleContext moduleContext) {
		if (mMap != null) {
			TestMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new TestMapSimple().addEventListener(moduleContext,
						mapView.getMap());
			}
		}
	}
}
