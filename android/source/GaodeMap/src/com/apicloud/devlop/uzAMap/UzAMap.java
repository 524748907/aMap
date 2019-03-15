//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.amap.api.col.n3.ew;
import com.amap.api.col.n3.ne;
import com.amap.api.col.n3.nu;
import com.amap.api.maps.AMap;
import com.amap.api.maps.AMap.OnIndoorBuildingActiveListener;
import com.amap.api.maps.AMap.OnMapScreenShotListener;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.CoordinateConverter;
import com.amap.api.maps.CoordinateConverter.CoordType;
import com.amap.api.maps.MapView;
import com.amap.api.maps.model.IndoorBuildingInfo;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.LatLngBounds;
import com.amap.api.trace.LBSTraceClient;
import com.amap.api.trace.TraceListener;
import com.amap.api.trace.TraceLocation;
import com.apicloud.devlop.uzAMap.models.MoveAnnotation;
import com.apicloud.devlop.uzAMap.models.MoveOverlay;
import com.apicloud.devlop.uzAMap.utils.JsParamsUtil;
import com.uzmap.pkg.uzcore.UZCoreUtil;
import com.uzmap.pkg.uzcore.UZWebView;
import com.uzmap.pkg.uzcore.uzmodule.UZModule;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

import android.graphics.Bitmap;
import android.graphics.Bitmap.CompressFormat;
import android.os.AsyncTask;
import android.text.TextUtils;
import android.util.Log;

public class UzAMap extends UZModule {
	private MapOpen mMap;
	private MapLocation mLocation;
	private MapAnnotations mAnnotations;
	private MapOverlay mOverlays;
	private MapSearch mSearch;
	private MapBusLine mBusLine;
	private MapAnimationOverlay mMapAnimationOverlay;
	private MapOffline mMapOffline;

	public UzAMap(UZWebView webView) {
		super(webView);
	}
	

	public void jsmethod_open(UZModuleContext moduleContext) {
		if (mMap == null) {
			mMap = new MapOpen();
		}
		mMap.openMap(this, moduleContext, context());
	}

	public void jsmethod_close(UZModuleContext moduleContext) {
		if (mMap != null) {
			mMap.closeMap(this);
			mMap = null;
			mLocation = null;
			mAnnotations = null;
			mOverlays = null;
			mSearch = null;
			mBusLine = null;
			mMapAnimationOverlay = null;
			mMapOffline = null;
		}
	}

	public void jsmethod_show(UZModuleContext moduleContext) {
		if (mMap != null) {
			mMap.showMap();
		}
	}

	public void jsmethod_hide(UZModuleContext moduleContext) {
		if (mMap != null) {
			mMap.hideMap();
		}
	}

	public void jsmethod_setRect(UZModuleContext moduleContext) {
		if (mMap != null) {
			mMap.setRect(moduleContext);
		}
	}

	public void jsmethod_getLocation(UZModuleContext moduleContext) {
		if (mLocation == null) {
			mLocation = new MapLocation();
		}
		mLocation.getLocation(moduleContext, context());
	}

	public void jsmethod_stopLocation(UZModuleContext moduleContext) {
		if (mLocation != null) {
			mLocation.stopLocation();
		}
	}

	public void jsmethod_getCoordsFromName(UZModuleContext moduleContext) {
		new MapCoordsAddress().getLocationFromName(moduleContext, context());
	}

	public void jsmethod_getNameFromCoords(UZModuleContext moduleContext) {
		new MapCoordsAddress().getNameFromLocation(moduleContext, context());
	}

	public void jsmethod_getDistance(UZModuleContext moduleContext) {
		new MapSimple().getDistance(moduleContext);
	}

	public void jsmethod_showUserLocation(UZModuleContext moduleContext) {
		if (mMap != null) {
			if (mMap.getShowUser() == null) {
				mMap.setShowUser(new MapShowUser());
			}
			mMap.getShowUser().showUserLocation(mMap.getMapView().getMap(),
					moduleContext, context());
		}
	}

	public void jsmethod_setTrackingMode(UZModuleContext moduleContext) {
		if (mMap != null)
			new MapShowUser().setTrackingMode(mMap.getMapView().getMap(),
					moduleContext);
	}

	public void jsmethod_panBy(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null)
				new MapSimple().panBy(moduleContext, mapView.getMap());
		}
	}

	public void jsmethod_setCenter(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().setCenter(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_getCenter(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().getCenter(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_setZoomLevel(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				String zoom = String.valueOf(mapView.getMap().getCameraPosition().zoom);
				float zoomLevel = (float) moduleContext.optDouble("level", 10);
				//Toast.makeText(context(), "当前的缩放级别是" + zoom + "-----要缩放的级别是" + String.valueOf(zoomLevel), Toast.LENGTH_LONG).show();
				new MapSimple().setZoomLevel(moduleContext, mapView.getMap());
//				float zoomLevel = (float) moduleContext.optDouble("level", 10);
//				boolean isAnimated = moduleContext.optBoolean("animation", true);
//				if (isAnimated) {
//					mapView.getMap().animateCamera(CameraUpdateFactory.zoomTo(zoomLevel), 300, null);
//				} else {
//					mapView.getMap().moveCamera(CameraUpdateFactory.zoomTo(zoomLevel));
//				}
			}
		}
	}

	public void jsmethod_getZoomLevel(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().getZoomLevel(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_setMapAttr(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().setMapAttr(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_setRotation(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().setRotation(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_getRotation(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().getRotation(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_setOverlook(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().setOverlook(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_getOverlook(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().getOverlook(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_setRegion(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().setRegion(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_getRegion(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().getRegion(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_setScaleBar(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().setScaleBar(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_setCompass(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().setCompass(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_setLogo(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().setLogo(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_isPolygonContainsPoint(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().isPolygonContantPoint(moduleContext,
						mapView.getMap());
			}
		}
	}
	
	/**
	 * 判断已知点是否在指定的圆形区域内
	 * @param moduleContext
	 */
	public void jsmethod_isCircleContainsPoint(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().isCircleContainsPoint(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_interconvertCoords(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().interconvertCoords(moduleContext,
						mapView.getMap());
			}
		}
	}

	public void jsmethod_addEventListener(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().addEventListener(moduleContext,
						mapView.getMap());
			}
		}
	}

	public void jsmethod_removeEventListener(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				new MapSimple().removeEventListener(moduleContext,
						mapView.getMap());
			}
		}
	}

	public void jsmethod_addAnnotations(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			int width = mapView.getWidth();
			int height = mapView.getHeight();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.addAnnotations(moduleContext);
			}
		}
	}
	
	/**
	 * 给地图上的标注添加移动动画
	 * @param moduleContext
	 */
	public void jsmethod_addMoveAnimation(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.addMoveAnimation(moduleContext);
			}
		}
	}
	
	/**
	 * 取消地图上的标注移动动画
	 * @param moduleContext
	 */
	public void jsmethod_cancelMoveAnimation(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.cancelMoveAnimation(moduleContext);
			}
		}
	}
	
	/**
	 * TODO
	 * 显示mark和气泡
	 * @param moduleContext
	 */
	public void jsmethod_showAnnotations(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.addAnnotations(moduleContext);
			}
		}
	}

	public void jsmethod_getAnnotationCoords(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.getAnnotationCoords(moduleContext);
			}
		}
	}

	public void jsmethod_setAnnotationCoords(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.setAnnotationCoords(moduleContext);
			}
		}
	}

	public void jsmethod_annotationExist(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.annotationExist(moduleContext);
			}
		}
	}

	public void jsmethod_setBubble(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.setWebBubbleUrl = false;
				mAnnotations.setBubble(moduleContext);
			}
		}
	}
	
	/**
	 * @see 新增接口，同上，只是将布局交给开发者自定义
	 */
	public void jsmethod_setWebBubble(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.setWebBubbleUrl = true;
				mAnnotations.setWebBubble(moduleContext);
			}
		}
	}
	
	public static UZModuleContext webBubbleModuleContext;
	/**
	 * 添加网页气泡点击监听
	 * @param moduleContext
	 */
	public void jsmethod_addWebBubbleListener(UZModuleContext moduleContext) {
		if (webBubbleModuleContext == null) {
			webBubbleModuleContext = moduleContext;
		}
	}
	
	/**
	 * 移除网页气泡点击监听
	 * @param moduleContext
	 */
	public void jsmethod_removeWebBubbleListener(UZModuleContext moduleContext) {
		if (webBubbleModuleContext != null) {
			webBubbleModuleContext = null;
		}
	}
	
	/**
	 * 缩放地图，包含所有的Mark标注
	 * @param moduleContext
	 */
	public void jsmethod_zoomToSpan(UZModuleContext moduleContext) {
		if (mMap != null) {
			JSONArray points = moduleContext.optJSONArray("points");
			JSONObject center = moduleContext.optJSONObject("center");
			if (center != null) {
				zoomToSpanWithCenter(center, points);
			}else {
				zoomToSpan(points);
			}
		}
		
	}
	
	private void zoomToSpan(JSONArray points) {
		LatLngBounds bounds = getLatLngBounds(points);
		mMap.getMapView().getMap().moveCamera(CameraUpdateFactory.newLatLngBounds(bounds, 50));
	}
	
	private void zoomToSpanWithCenter(JSONObject center, JSONArray points) {
		LatLngBounds bounds = getLatLngBounds(center, points);
		mMap.getMapView().getMap().moveCamera(CameraUpdateFactory.newLatLngBounds(bounds, 50));
	}
	
	//根据中心点和自定义内容获取缩放bounds
    private LatLngBounds getLatLngBounds(JSONObject centerpoint, JSONArray pointList) {
        LatLngBounds.Builder b = LatLngBounds.builder();
        if (centerpoint != null){
            for (int i = 0; i < pointList.length(); i++) {
            		JSONObject pJson = pointList.optJSONObject(i);
                LatLng p = new LatLng(pJson.optDouble("lat"), pJson.optDouble("lon"));
                LatLng p1 = new LatLng((centerpoint.optDouble("lat") * 2) - p.latitude, (centerpoint.optDouble("lon") * 2) - p.longitude);
                b.include(p);
                b.include(p1);
            }
        }
        return b.build();
    }
	
	/**
     * 根据自定义内容获取缩放bounds
     */
    private LatLngBounds getLatLngBounds(JSONArray points) {
        LatLngBounds.Builder b = LatLngBounds.builder();
        for (int i = 0; i < points.length(); i++) {
             JSONObject pJson = points.optJSONObject(i);
             LatLng p = new LatLng(pJson.optDouble("lat"), pJson.optDouble("lon"));
             b.include(p);
         }
        return b.build();
    }

	public void jsmethod_popupBubble(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.popupBubble(moduleContext);
			}
		}
	}

	public void jsmethod_closeBubble(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.closeBubble(moduleContext);
			}
		}
	}

	public void jsmethod_addBillboard(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.addBillboard(moduleContext);
			}
		}
	}

	public void jsmethod_addMobileAnnotations(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.addMoveAnnotations(moduleContext);
			}
		}
	}

	public void jsmethod_moveAnnotation(UZModuleContext moduleContext) {
		if (mAnnotations != null) {
			Map<String, MoveAnnotation> markerMap = mAnnotations.getMoveMarkerMap();
			String id = moduleContext.optString("id");
			MoveAnnotation anno = markerMap.get(id);
			if (anno != null) {
				JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
				float lat = jsParamsUtil.lat(moduleContext, "end");
				float lon = jsParamsUtil.lon(moduleContext, "end");
				double duration = moduleContext.optDouble("duration");
				if (mMapAnimationOverlay == null) {
					mMapAnimationOverlay = new MapAnimationOverlay();
				}
				mMapAnimationOverlay.addMoveOverlay(new MoveOverlay(
						moduleContext, id, anno.getMarker(), duration,
						new LatLng(lat, lon)));
				mMapAnimationOverlay.startMove();
			}
		}
	}

	public void jsmethod_removeAnnotations(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView, context());
				}
				mAnnotations.removeAnnotations(moduleContext);
			}
		}
	}
	
	
	/**
	 * 开始纠偏轨迹
	 * @param moduleContext
	 */
	public void jsmethod_processedTrace(UZModuleContext moduleContext) {
		String type = moduleContext.optString("type");
		String path = moduleContext.optString("path");
		String savePath = moduleContext.optString("savePath", "fs://" + System.currentTimeMillis() + ".txt");	
		
		new MyAsyncTask(moduleContext, type, makeRealPath(savePath)).execute(makeRealPath(path));
	}
	
	private  LBSTraceClient client;
	class MyAsyncTask extends AsyncTask<String, Void, Void>{
		private String type;
		private UZModuleContext moduleContext;
		private String savePath;
		public MyAsyncTask(UZModuleContext moduleContext, String type, String savePath) {
			this.type = type;
			this.moduleContext = moduleContext;
			this.savePath = savePath;
		}
		@Override
		protected Void doInBackground(String... arg0) {
			String path = arg0[0];
			List<TraceLocation> list = readTraceConfig(path);
			if (client == null) {
				client = LBSTraceClient.getInstance(context());
			}
			int zType;
			if (TextUtils.equals(type, "aMap")) {
				zType = LBSTraceClient.TYPE_AMAP;
			}else if (TextUtils.equals(type, "baidu")) {
				zType = LBSTraceClient.TYPE_BAIDU;
			}else if (TextUtils.equals(type, "GPS")) {
				zType = LBSTraceClient.TYPE_GPS;
			}else {
				zType = LBSTraceClient.TYPE_AMAP;
			}
			client.queryProcessedTrace(0, list, zType, new TraceListener() {
				
				@Override
				public void onTraceProcessing(int arg0, int arg1, List<LatLng> arg2) {
					
				}
				
				@Override
				public void onRequestFailed(int arg0, String arg1) {
					try {
						JSONObject result = new JSONObject();
						JSONObject error = new JSONObject();
						result.put("status", false);
						result.put("path", null);
						error.put("code", arg0);
						error.put("msg", arg1);
						moduleContext.error(result, error, false);
					} catch (JSONException e) {
						e.printStackTrace();
					}
				}
				
				@Override
				public void onFinished(int lineID, List<LatLng> linepoints, int distance, int waitingtime) {
					try {
						JSONArray array = new JSONArray();
						if (linepoints != null) {
							for(int i = 0; i < linepoints.size(); i++) {
								LatLng latLng = linepoints.get(i);
								JSONObject json = new JSONObject();
								json.put("longitude", latLng.longitude);
								json.put("latitude", latLng.latitude);
								array.put(json);
							}
						}
						FileOutputStream fos = new FileOutputStream(savePath);
						fos.write(array.toString().getBytes());
						fos.close();
						JSONObject result = new JSONObject();
						JSONObject error = new JSONObject();
						result.put("status", true);
						result.put("path", savePath);
						moduleContext.error(result, error, false);
					} catch (Exception e) {
					}
					
				}
			});
			return null;
		}
		
	}
	
	/**
	 * 取消轨迹纠偏
	 * @param moduleContext
	 */
	public void jsmethod_cancelProcessedTrace(UZModuleContext moduleContext) {
		if (client != null) {
			client.stopTrace();
			client.destroy();
			client = null;
		}
	}
	
	private List<TraceLocation> readTraceConfig(String path) {
		List<TraceLocation> list = new ArrayList<>(); 
		try {
			InputStream inputStream = UZUtility.guessInputStream(path);
			if (inputStream != null) {
				String data = UZCoreUtil.readString(inputStream);
				if (!TextUtils.isEmpty(data)) {
					JSONArray arrayData = new JSONArray(data);
					for(int i = 0; i < arrayData.length(); i++) {
						JSONObject dataJson = arrayData.optJSONObject(i);
						if (dataJson != null) {
							long loctime = dataJson.optLong("dataJson");
							double longitude = dataJson.optDouble("longitude");
							double latitude = dataJson.optDouble("latitude");
							double speed = dataJson.optDouble("speed");
							double bearing = dataJson.optDouble("bearing");
							TraceLocation location = new TraceLocation();
							location.setTime(loctime);
							location.setLongitude(longitude);
							location.setLatitude(latitude);
							location.setSpeed((float)speed);
							location.setBearing((float)bearing);
							list.add(location);
						}
					}
				}
			}
		} catch (IOException e) {
			e.printStackTrace();
		} catch (JSONException e) {
			e.printStackTrace();
		}
		return list;
	}
	
	/**
	 * 其它坐标系经纬度转换为高德地图经纬度
	 * @param moduleContext
	 */
	public void jsmethod_convertCoordinate(UZModuleContext moduleContext) {
		try {
			String type = moduleContext.optString("type");
			CoordinateConverter converter = new CoordinateConverter(context());
			switch (type) {
			case "GPS":
				converter.from(CoordType.GPS);
				break;
			case "baidu":
				converter.from(CoordType.BAIDU);
				break;
			case "mapBar":
				converter.from(CoordType.MAPBAR);
				break;
			case "mapABC":
				converter.from(CoordType.MAPABC);
				break;
			case "sosoMap":
				converter.from(CoordType.SOSOMAP);
				break;
			case "aliYun":
				converter.from(CoordType.ALIYUN);
				break;
			case "google":
				converter.from(CoordType.GOOGLE);
				break;
			default:
				break;
			}
			JSONObject location = moduleContext.optJSONObject("location");
			double lat = 0;
			double lon = 0;
			if (location != null) {
				lat = location.optDouble("lat");
				lon = location.optDouble("lon");
				
			}
			LatLng latLng = new LatLng(lat, lon);
			converter.coord(latLng);
			LatLng resultLatLng = converter.convert();
			if (resultLatLng != null) {
				JSONObject result = new JSONObject();
				result.put("lat", resultLatLng.latitude);
				result.put("lon", resultLatLng.longitude);
				moduleContext.success(result, false);
			}
		} catch (Exception e) {
		}
		
	}

	public void jsmethod_addLine(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mOverlays == null) {
					mOverlays = new MapOverlay(this, mapView.getMap());
				}
				mOverlays.addLine(moduleContext);
			}
		}
	}

	public void jsmethod_addLocus(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mOverlays == null) {
					mOverlays = new MapOverlay(this, mapView.getMap());
				}
				mOverlays.addLocus(moduleContext);
			}
		}
	}

	public void jsmethod_addCircle(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mOverlays == null) {
					mOverlays = new MapOverlay(this, mapView.getMap());
				}
				mOverlays.addCircle(moduleContext);
			}
		}
	}

	public void jsmethod_addPolygon(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mOverlays == null) {
					mOverlays = new MapOverlay(this, mapView.getMap());
				}
				mOverlays.addPolygon(moduleContext);
			}
		}
	}

	public void jsmethod_addImg(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mOverlays == null) {
					mOverlays = new MapOverlay(this, mapView.getMap());
				}
				mOverlays.addImg(moduleContext);
			}
		}
	}

	public void jsmethod_removeOverlay(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mOverlays == null) {
					mOverlays = new MapOverlay(this, mapView.getMap());
				}
				mOverlays.removeOverlay(moduleContext);
			}
		}
	}
	
	/**
	 * 在地图上添加热力点图层
	 * @param moduleContext
	 */
	public void jsmethod_addHeatMap(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mOverlays == null) {
					mOverlays = new MapOverlay(this, mapView.getMap());
				}
				mOverlays.addHeatMap(moduleContext);
			}
		}
	}
	
	/**
	 * 刷新在地图上添加热力点图层
	 * @param moduleContext
	 */
	public void jsmethod_refreshHeatMap(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mOverlays == null) {
					mOverlays = new MapOverlay(this, mapView.getMap());
				}
				mOverlays.refreshHeatMap(moduleContext);
			}
		}
	}
	
	/**
	 * 在地图上添加点聚合图层
	 * @param moduleContext
	 */
	public void jsmethod_addMultiPoint(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mOverlays == null) {
					mOverlays = new MapOverlay(this, mapView.getMap());
				}
				mOverlays.addMultiPoint(moduleContext);
			}
		}
	}

	public void jsmethod_searchRoute(UZModuleContext moduleContext) {
		if (mSearch == null) {
			mSearch = new MapSearch(context());
		}
		mSearch.searchRoute(moduleContext);
	}

	public void jsmethod_drawRoute(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mSearch == null) {
					mSearch = new MapSearch(context());
				}
				mSearch.drawRoute(moduleContext, mapView.getMap(), this);
			}
		}
	}

	public void jsmethod_removeRoute(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mSearch == null) {
					mSearch = new MapSearch(context());
				}
				mSearch.removeRoute(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_searchBusRoute(UZModuleContext moduleContext) {
		if (mBusLine == null) {
			mBusLine = new MapBusLine(context());
		}
		mBusLine.searchBusLine(moduleContext);
	}

	public void jsmethod_drawBusRoute(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mBusLine == null) {
					mBusLine = new MapBusLine(context());
				}
				mBusLine.drawBusLine(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_removeBusRoute(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mBusLine == null) {
					mBusLine = new MapBusLine(context());
				}
				mBusLine.removeRoute(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_searchInCity(UZModuleContext moduleContext) {
		new MapPoi(moduleContext, context()).searchInCity(moduleContext);
	}

	public void jsmethod_searchNearby(UZModuleContext moduleContext) {
		new MapPoi(moduleContext, context()).searchNearby(moduleContext);
	}

	public void jsmethod_searchInPolygon(UZModuleContext moduleContext) {
		new MapPoi(moduleContext, context()).searchBounds(moduleContext);
	}

	public void jsmethod_autocomplete(UZModuleContext moduleContext) {
		new MapPoi(moduleContext, context()).autoComplete(moduleContext);
	}

	public void jsmethod_getProvinces(UZModuleContext moduleContext) {
		new MapOffline().getProvinces(moduleContext, context());
	}
	
	public void jsmethod_getCitiesByProvince(UZModuleContext moduleContext) {
		new MapOffline().getCitiesByProvince(moduleContext, context());
	}

	public void jsmethod_getAllCities(UZModuleContext moduleContext) {
		new MapOffline().getAllCities(moduleContext, context());
	}

	public void jsmethod_downloadRegion(UZModuleContext moduleContext) {
		if (mMapOffline == null) {
			mMapOffline = new MapOffline();
		}
		mMapOffline.downloadRegion(moduleContext, context());
	}

	public void jsmethod_isDownloading(UZModuleContext moduleContext) {
		if (mMapOffline == null) {
			mMapOffline = new MapOffline();
		}
		mMapOffline.isDownloading(moduleContext, context());
	}

	public void jsmethod_pauseDownload(UZModuleContext moduleContext) {
		if (mMapOffline == null) {
			mMapOffline = new MapOffline();
		}
		mMapOffline.pauseDownload(moduleContext, context());
	}

	public void jsmethod_cancelAllDownload(UZModuleContext moduleContext) {
		if (mMapOffline == null) {
			mMapOffline = new MapOffline();
		}
		mMapOffline.cancelAllDownload(moduleContext, context());
	}

	public void jsmethod_clearDisk(UZModuleContext moduleContext) {
		if (mMapOffline == null) {
			mMapOffline = new MapOffline();
		}
		mMapOffline.clearDisk();
	}

	/**
	 * @param moduleContext
	 * TODO  行政区划边界查询
	 */
	public void jsmethod_districtSearch(UZModuleContext moduleContext) {
		if (mMap != null) {
			MapView mapView = mMap.getMapView();
			AMap amap = mapView.getMap();
			new MapDistrictSearch(this,amap, moduleContext);
		}else{
			new MapDistrictSearch(this,null, moduleContext);
		}
	}
	
	/**
	 * 在指定区域内截图(默认会包含该区域内的标注)
	 * @param moduleContext
	 */
	public void jsmethod_takeSnapshotInRect(final UZModuleContext moduleContext) {
		if (mMap != null) {
			MapView mapView = mMap.getMapView();
			AMap aMap = mapView.getMap();
			
			JSONObject rectJson = moduleContext.optJSONObject("rect");
			final int x = rectJson.optInt("x", 0);
			final int y = rectJson.optInt("y", 0);
			final int width = rectJson.optInt("w", mapView.getWidth());
			final int height = rectJson.optInt("h", mapView.getHeight());
			final String path = makeRealPath(moduleContext.optString("path"));
			File file = new File(path);
			File fileDir = file.getParentFile();
			if (!fileDir.exists()) {
				fileDir.mkdirs();
			}
			if (!file.exists()) {
				try {
					file.createNewFile();
				} catch (IOException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
			}
			final JSONObject ret = new JSONObject();
			aMap.getMapScreenShot(new OnMapScreenShotListener() {
				
				@Override
				public void onMapScreenShot(Bitmap bitmap, int status) {
					if (bitmap == null) {
						return;
					}
					try {
						Bitmap newBitmap = Bitmap.createBitmap(bitmap, x, y, width, height);
						FileOutputStream fos = new FileOutputStream(path);
						boolean b = newBitmap.compress(CompressFormat.PNG, 100, fos);
						try {
				              fos.flush();
				            } catch (IOException e) {
				              e.printStackTrace();
				            }
				            try {
				              fos.close();
				            } catch (IOException e) {
				              e.printStackTrace();
				            }
				            if (b) {
								ret.put("status", true);
								ret.put("realPath", path);
								moduleContext.success(ret, true);
							}else {
								ret.put("status", false);
								ret.put("realPath", "");
								moduleContext.success(ret, true);
							}
					} catch (Exception e) {
						// TODO Auto-generated catch block
						e.printStackTrace();
						try {
							ret.put("status", false);
							ret.put("realPath", "");
							moduleContext.success(ret, true);
						} catch (JSONException e1) {
							e1.printStackTrace();
						}
						
					}
					
				}
				
				@Override
				public void onMapScreenShot(Bitmap arg0) {
					
					
				}
			});
		}
	}
	
	/**
	 * 是否为显示室内地图状态
	 * @param moduleContext
	 */
	public void jsmethod_isShowsIndoorMap(UZModuleContext moduleContext) {
		try {
			JSONObject result = new JSONObject();
			result.put("status", isShows);
			moduleContext.success(result, false);
		} catch (Exception e) {
			// TODO: handle exception
		}
	}
	
	private boolean isShows = false;
	/**
	 * 设置是否显示室内地图
	 * @param moduleContext
	 */
	public void jsmethod_showsIndoorMap(UZModuleContext moduleContext) {
		isShows = moduleContext.optBoolean("isShows", false);
		if (mMap != null) {
			AMap aMap = mMap.getMapView().getMap();
			aMap.showIndoorMap(isShows);
		}
	}
	
	/**
	 * 设置当前室内地图楼层数
	 * @param moduleContext
	 */
	public void jsmethod_setCurrentIndoorMapFloorIndex(UZModuleContext moduleContext) {
		int floorIndex = moduleContext.optInt("floorIndex", 0);
		String activeFloorName = "F2";
		int[] floor_indexs = {-1, 1, 2, 3, 4, 5, 6, 7};
		String[] floor_names = {"B1", "F1", "F2", "F3", "F4", "F5", "F6", "F7"};
		String poiid = "B000A6534B";
		
		IndoorBuildingInfo info = new IndoorBuildingInfo();
		
		
		info.activeFloorIndex = floorIndex;
		info.activeFloorName = activeFloorName;
		info.floor_indexs = floor_indexs;
		info.floor_names = floor_names;
		info.poiid = poiid;
		if (mMap != null) {
			mMap.getMapView().getMap().setIndoorBuildingInfo(info);
			mMap.getMapView().getMap().setOnIndoorBuildingActiveListener(new OnIndoorBuildingActiveListener() {
				
				@Override
				public void OnIndoorBuilding(IndoorBuildingInfo arg0) {
					Log.e("TAG", arg0.toString());
					
				}
			});
		}
	}
}
