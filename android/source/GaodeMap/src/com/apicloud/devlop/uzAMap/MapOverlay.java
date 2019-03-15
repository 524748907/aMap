//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.os.AsyncTask;
import android.text.TextUtils;

import com.alibaba.idst.nls.internal.connector.FrameDataPosterFactory.PosterType;
import com.amap.api.maps.AMap;
import com.amap.api.maps.AMap.OnMultiPointClickListener;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.maps.model.Circle;
import com.amap.api.maps.model.CircleOptions;
import com.amap.api.maps.model.Gradient;
import com.amap.api.maps.model.GroundOverlay;
import com.amap.api.maps.model.GroundOverlayOptions;
import com.amap.api.maps.model.HeatmapTileProvider;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.LatLngBounds;
import com.amap.api.maps.model.MultiPointItem;
import com.amap.api.maps.model.MultiPointOverlay;
import com.amap.api.maps.model.MultiPointOverlayOptions;
import com.amap.api.maps.model.Polygon;
import com.amap.api.maps.model.PolygonOptions;
import com.amap.api.maps.model.Polyline;
import com.amap.api.maps.model.PolylineOptions;
import com.amap.api.maps.model.TileOverlay;
import com.amap.api.maps.model.TileOverlayOptions;
import com.amap.api.maps.model.WeightedLatLng;
import com.apicloud.devlop.uzAMap.models.LocusData;
import com.apicloud.devlop.uzAMap.models.TileOverlayData;
import com.apicloud.devlop.uzAMap.utils.JsParamsUtil;
import com.uzmap.pkg.uzcore.UZCoreUtil;
import com.uzmap.pkg.uzcore.UZResourcesIDFinder;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

@SuppressLint("UseSparseArrays")
public class MapOverlay {
	private UzAMap mUzAMap;
	private AMap mAMap;
	private Map<String, Polyline> mLineMap = new HashMap<String, Polyline>();
	private Map<String, Polygon> mGonMap = new HashMap<String, Polygon>();
	private Map<String, Circle> mCircleMap = new HashMap<String, Circle>();
	private Map<String, GroundOverlay> mGroundMap = new HashMap<String, GroundOverlay>();

	public MapOverlay(UzAMap uzAMap, AMap aMap) {
		this.mUzAMap = uzAMap;
		this.mAMap = aMap;
	}

	public void addLine(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		PolylineOptions polylineOptions = new PolylineOptions();
		JSONObject styles = moduleContext.optJSONObject("styles");
		boolean lineDash = false;
		int borderColor = UZUtility.parseCssColor("#000");
		double borderWidth = 2;
		if (styles != null) {
			String type = styles.optString("type", "round");
			lineDash = styles.optBoolean("lineDash", false);
			borderColor = UZUtility.parseCssColor(styles.optString(
					"borderColor", "#000"));
			borderWidth = styles.optDouble("borderWidth", 2);
			String strokeImgPath = styles.optString("strokeImg");
			JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
			Bitmap strokeImg = jsParamsUtil.getBitmap(mUzAMap
					.makeRealPath(strokeImgPath));
			polylineOptions.setCustomTexture(BitmapDescriptorFactory
					.fromBitmap(strokeImg));
			if (!TextUtils.isEmpty(strokeImgPath)) {
				if (TextUtils.equals(type, "round")) {
					polylineOptions.lineCapType(PolylineOptions.LineCapType.LineCapRound);
				}else if (TextUtils.equals(type, "square")) {
					polylineOptions.lineCapType(PolylineOptions.LineCapType.LineCapSquare);
				}else if (TextUtils.equals(type, "arrow")) {
					polylineOptions.lineCapType(PolylineOptions.LineCapType.LineCapArrow);
				}
			}
			
		}
		polylineOptions.width((float) borderWidth).color(borderColor);
		polylineOptions.setDottedLine(lineDash);
		if (!moduleContext.isNull("points")) {
			JSONArray pointArray = moduleContext.optJSONArray("points");
			if (pointArray.length() > 0) {
				double lon = 0;
				double lat = 0;
				JSONObject tmp = null;
				LatLng latLng = null;
				for (int i = 0; i < pointArray.length(); i++) {
					tmp = pointArray.optJSONObject(i);
					lon = tmp.optDouble("lon");
					lat = tmp.optDouble("lat");
					latLng = new LatLng(lat, lon);
					polylineOptions.add(latLng);
				}
			}
			if (mAMap != null) {
				Polyline polyline = mAMap.addPolyline(polylineOptions);
				mLineMap.put(id, polyline);
			}
		}
	}

	public void addLocus(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		PolylineOptions polylineOptions = new PolylineOptions();
		double borderWidth = moduleContext.optDouble("borderWidth", 5);
		polylineOptions.width((float) borderWidth);
		JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
		List<LocusData> locusDatas = jsParamsUtil.locusDatas(mUzAMap,
				moduleContext);
		List<Integer> colorList = new ArrayList<Integer>();
		if (locusDatas != null) {
			double lbLon = 0;
			double lbLat = 0;
			double rtLon = 0;
			double rtLat = 0;
			for (int i = 0; i < locusDatas.size(); i++) {
				LocusData ld = locusDatas.get(i);
				double lat = ld.getLatitude();
				double lon = ld.getLongtitude();
				if (i == 0) {
					lbLat = lat;
					lbLon = lon;
				}
				if (lat > lbLat) {
					rtLat = lat;
				} else {
					lbLat = lat;
				}
				if (lon > lbLon) {
					rtLon = lon;
				} else {
					lbLon = lon;
				}
				colorList.add(ld.getRgba());
				polylineOptions.add(new LatLng(ld.getLatitude(), ld
						.getLongtitude()));
			}
			LatLng lbLatLng = new LatLng(lbLat, lbLon);
			LatLng rtLatLng = new LatLng(rtLat, rtLon);
			polylineOptions.colorValues(colorList);
			if (mAMap != null) {
				Polyline polyline = mAMap.addPolyline(polylineOptions);
				mLineMap.put(id, polyline);
				if (moduleContext.optBoolean("autoresizing", true)) {
					mAMap.animateCamera(CameraUpdateFactory.newLatLngBounds(
							new LatLngBounds(lbLatLng, rtLatLng), 0));
				}
			}
		}
	}

	public void addCircle(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		JSONObject styles = moduleContext.optJSONObject("styles");
		CircleOptions circleOptions = new CircleOptions();
		int borderColor = UZUtility.parseCssColor("#000");
		int fillColor = UZUtility.parseCssColor("rgba(125,125,125,0.8)");
		double borderWidth = 2;
		if (styles != null) {
			borderColor = UZUtility.parseCssColor(styles.optString(
					"borderColor", "#000"));
			fillColor = UZUtility.parseCssColor(styles.optString("fillColor",
					"rgba(125,125,125,0.8)"));
			borderWidth = styles.optDouble("borderWidth", 2);
			double radius = moduleContext.optDouble("radius");
			circleOptions.fillColor(fillColor).strokeColor(borderColor)
					.strokeWidth((float) borderWidth).radius(radius);
		}
		JSONObject center = moduleContext.optJSONObject("center");
		if (center != null) {
			double lat = center.optDouble("lat");
			double lon = center.optDouble("lon");
			circleOptions.center(new LatLng(lat, lon));
			if (mAMap != null) {
				Circle circle = mAMap.addCircle(circleOptions);
				mCircleMap.put(id, circle);
			}
		}

	}

	public void addPolygon(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		PolygonOptions polygonOptions = new PolygonOptions();
		JSONObject styles = moduleContext.optJSONObject("styles");
		int borderColor = UZUtility.parseCssColor("#000");
		int fillColor = UZUtility.parseCssColor("rgba(125,125,125,0.8)");
		double borderWidth = 2;
		if (styles != null) {
			borderColor = UZUtility.parseCssColor(styles.optString(
					"borderColor", "#000"));
			borderWidth = styles.optDouble("borderWidth", 2);
			fillColor = UZUtility.parseCssColor(styles.optString("fillColor",
					"rgba(125,125,125,0.8)"));
		}
		polygonOptions.strokeWidth((float) borderWidth)
				.strokeColor(borderColor).fillColor(fillColor);
		if (!moduleContext.isNull("points")) {
			JSONArray pointArray = moduleContext.optJSONArray("points");
			if (pointArray.length() > 0) {
				double lon = 0;
				double lat = 0;
				JSONObject tmp = null;
				LatLng latLng = null;
				for (int i = 0; i < pointArray.length(); i++) {
					tmp = pointArray.optJSONObject(i);
					lon = tmp.optDouble("lon");
					lat = tmp.optDouble("lat");
					latLng = new LatLng(lat, lon);
					polygonOptions.add(latLng);
				}
			}
			if (mAMap != null) {
				Polygon polygon = mAMap.addPolygon(polygonOptions);
				mGonMap.put(id, polygon);
			}
		}
	}

	public void addImg(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		if (!moduleContext.isNull("imgPath")) {
			String imgPath = moduleContext.optString("imgPath");
			JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
			Bitmap bitmap = jsParamsUtil.getBitmap(mUzAMap
					.makeRealPath(imgPath));
			if (bitmap != null) {
				double lbLon = moduleContext.optDouble("lbLon");
				double lbLat = moduleContext.optDouble("lbLat");
				LatLng lLatLng = new LatLng(lbLat, lbLon);
				double rtLon = moduleContext.optDouble("rtLon");
				double rtLat = moduleContext.optDouble("rtLat");
				LatLng rLatLng = new LatLng(rtLat, rtLon);
				LatLngBounds bounds = new LatLngBounds.Builder()
						.include(lLatLng).include(rLatLng).build();
				GroundOverlay groundoverlay = mAMap
						.addGroundOverlay(new GroundOverlayOptions()
								.anchor(0.5f, 0.5f)
								.transparency(0.1f)
								.image(BitmapDescriptorFactory
										.fromBitmap(bitmap))
								.positionFromBounds(bounds));
				mGroundMap.put(id, groundoverlay);
			}
		}
	}

	public void removeOverlay(UZModuleContext moduleContext) {
		JSONArray ids = moduleContext.optJSONArray("ids");
		if (ids != null) {
			for (int i = 0; i < ids.length(); i++) {
				String id = ids.optString(i);
				Polyline polyline = mLineMap.get(id);
				if (polyline != null) {
					polyline.remove();
				}
				mLineMap.remove(id);
				
				Polygon polygon = mGonMap.get(id);
				if (polygon != null) {
					polygon.remove();
				}
				mGonMap.remove(id);
				
				Circle circle = mCircleMap.get(id);
				if (circle != null) {
					circle.remove();
				}
				mCircleMap.remove(id);
				
				GroundOverlay groundOverlay = mGroundMap.get(id);
				if (groundOverlay != null) {
					groundOverlay.remove();
				}
				mGroundMap.remove(id);
				
				TileOverlayData tileOverlayData = tileOverlayMap.get(id);
				if (tileOverlayData != null) {
					tileOverlayData.tileOverlay.remove();
				}
				tileOverlayMap.remove(id);
				
				MultiPointOverlay overlay = multiPointOverlayMap.get(id);
				if(overlay != null) {
					overlay.remove();
				}
				multiPointOverlayMap.remove(id);
			}
		}
	}
	
	public List<WeightedLatLng> readLatLng(String path) {
		List<WeightedLatLng> latLngs = new ArrayList<WeightedLatLng>();
		try {
			InputStream inputStream = UZUtility.guessInputStream(path);
			if (inputStream != null) {
				String data = UZCoreUtil.readString(inputStream);
				//Log.e("TAG", data + "");
				if (!TextUtils.isEmpty(data)) {
					JSONArray dataArray = new JSONArray(data);
					for(int i = 0; i < dataArray.length(); i++) {
						JSONObject lalngJson = dataArray.optJSONObject(i);
						if (lalngJson != null) {
							double longitude = lalngJson.optDouble("longitude");
							double latitude = lalngJson.optDouble("latitude");
							double intensity = lalngJson.optDouble("intensity");
							LatLng latLng = new LatLng(latitude, longitude, true);
							WeightedLatLng weightedLatLng = new WeightedLatLng(latLng, intensity);
							latLngs.add(weightedLatLng);
						}
					}
				}
			}
		} catch (IOException e) {
			e.printStackTrace();
		} catch (JSONException e) {
			e.printStackTrace();
		}
		return latLngs;
	}
	
	private Map<String, TileOverlayData> tileOverlayMap = new HashMap<String, TileOverlayData>();
	/**
	 * 添加热力图层
	 * @param moduleContext
	 */
	public void addHeatMap(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		TileOverlayData tileOverlayData = tileOverlayMap.get(id);
		if (tileOverlayData != null) {
			tileOverlayData.tileOverlay.remove();
			tileOverlayMap.remove(id);
			tileOverlayData = null;
		}
		Object data = moduleContext.optObject("data");
		JSONObject stylesJson = moduleContext.optJSONObject("styles");
		if (data instanceof String) {
			String dataPath = (String) data;
			new MyAsyncTask(id, stylesJson).execute(moduleContext.makeRealPath(dataPath));
		}else if(data instanceof JSONArray){
			JSONArray dataArray = (JSONArray)data;
			List<WeightedLatLng> latLngs = new ArrayList<WeightedLatLng>();
			for(int i = 0; i < dataArray.length(); i++) {
				JSONObject lalngJson = dataArray.optJSONObject(i);
				if (lalngJson != null) {
					double longitude = lalngJson.optDouble("longitude");
					double latitude = lalngJson.optDouble("latitude");
					double intensity = lalngJson.optDouble("intensity");
					LatLng latLng = new LatLng(latitude, longitude, true);
					WeightedLatLng weightedLatLng = new WeightedLatLng(latLng, intensity);
					latLngs.add(weightedLatLng);
				}
			}
			addTilelay(id, latLngs, stylesJson);
		}
	}
	
	private void addTilelay(String id, List<WeightedLatLng> latLngs, JSONObject stylesJson) {
		int radius = 12;
		double opacity = 0.6;
		boolean allowRetinaAdapting = false;//android不支持
		JSONArray colorsArray = null;
		JSONArray pointsArray = null;
		if (stylesJson != null) {
			radius = stylesJson.optInt("radius");
			opacity = stylesJson.optDouble("opacity");
			JSONObject gradientJson = stylesJson.optJSONObject("gradient");
			if (gradientJson != null) {
				colorsArray = gradientJson.optJSONArray("colors");
				pointsArray = gradientJson.optJSONArray("points");
			}
		}
		
		HeatmapTileProvider.Builder builder = new HeatmapTileProvider.Builder();
		builder.weightedData(latLngs);
		builder.radius(radius);
		builder.transparency(opacity);
		if (colorsArray != null && pointsArray != null) {
			int[] colors = new int[colorsArray.length()];
			for(int i = 0; i < colorsArray.length(); i++) {
				colors[i] = UZUtility.parseCssColor(colorsArray.optString(i));
			}
			float[] points = new float[pointsArray.length()];
			for(int i = 0; i < pointsArray.length(); i++) {
				points[i] = (float)pointsArray.optDouble(i);
			}
			builder.gradient(new Gradient(colors, points));
		}
		HeatmapTileProvider heatmapTileProvider = builder.build();
		
		TileOverlayOptions tileOverlayOptions = new TileOverlayOptions();
		tileOverlayOptions.tileProvider(heatmapTileProvider);
		if (mAMap != null) {
			TileOverlay tileOverlay = mAMap.addTileOverlay(tileOverlayOptions);
			tileOverlayMap.put(id, new TileOverlayData(tileOverlay, latLngs));
		}
		
	}
	
	class MyAsyncTask extends AsyncTask<String, Void, List<WeightedLatLng>>{
		
		private JSONObject stylesJson;
		private String id;
		public MyAsyncTask(String id, JSONObject stylesJson) {
			this.stylesJson = stylesJson;
			this.id = id;
		}

		@Override
		protected List<WeightedLatLng> doInBackground(String... path) {
			List<WeightedLatLng> list = readLatLng(path[0]);
			return list;
		}
		
		@Override
		protected void onPostExecute(List<WeightedLatLng> result) {
			super.onPostExecute(result);
			
			addTilelay(id, result, stylesJson);
			
		}
	}
	
	/**
	 * 刷新在地图上添加热力点图层
	 * @param moduleContext
	 */
	public void refreshHeatMap(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		TileOverlayData tileOverlayData = tileOverlayMap.get(id);
		if (tileOverlayData != null) {
			List<WeightedLatLng> list = tileOverlayData.latLngs;
			tileOverlayData.tileOverlay.remove();
			tileOverlayMap.remove(id);
			JSONObject stylesJson = moduleContext.optJSONObject("styles");
			int radius = 12;
			double opacity = 0.6;
			boolean allowRetinaAdapting = false;//android不支持
			JSONArray colorsArray = null;
			JSONArray pointsArray = null;
			if (stylesJson != null) {
				radius = stylesJson.optInt("radius");
				opacity = stylesJson.optDouble("opacity");
				JSONObject gradientJson = stylesJson.optJSONObject("gradient");
				if (gradientJson != null) {
					colorsArray = gradientJson.optJSONArray("colors");
					pointsArray = gradientJson.optJSONArray("points");
				}
			}
			HeatmapTileProvider.Builder builder = new HeatmapTileProvider.Builder();
			builder.weightedData(list);
			builder.radius(radius);
			builder.transparency(opacity);
			if (colorsArray != null && pointsArray != null) {
				int[] colors = new int[colorsArray.length()];
				for(int i = 0; i < colorsArray.length(); i++) {
					colors[i] = UZUtility.parseCssColor(colorsArray.optString(i));
				}
				float[] points = new float[pointsArray.length()];
				for(int i = 0; i < pointsArray.length(); i++) {
					points[i] = (float)pointsArray.optDouble(i);
				}
				builder.gradient(new Gradient(colors, points));
			}
			HeatmapTileProvider heatmapTileProvider = builder.build();
			
			TileOverlayOptions tileOverlayOptions = new TileOverlayOptions();
			tileOverlayOptions.tileProvider(heatmapTileProvider);
			if (mAMap != null) {
				TileOverlay tileOverlay = mAMap.addTileOverlay(tileOverlayOptions);
				tileOverlayMap.put(id, new TileOverlayData(tileOverlay, list));
			}
		}
	}
	
	private Map<String, MultiPointOverlay> multiPointOverlayMap = new HashMap<>();
	/**
	 * 在地图上添加点聚合图层
	 * @param moduleContext
	 */
	public void addMultiPoint(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		MultiPointOverlay overlay = multiPointOverlayMap.get(id);
		if (overlay != null) {
			overlay.remove();
			multiPointOverlayMap.remove(id);
		}
		String path = moduleContext.optString("path");
		JSONObject styles = moduleContext.optJSONObject("styles");
		
		new MyMultiAsync(moduleContext, id, styles).execute(moduleContext.makeRealPath(path));
	}
	
	class MyMultiAsync extends AsyncTask<String, Void, List<MultiPointItem>>{

		private String id;
		private JSONObject styles;
		private UZModuleContext moduleContext;
		public MyMultiAsync(UZModuleContext moduleContext, String id, JSONObject styles) {
			this.id = id;
			this.styles = styles;
			this.moduleContext = moduleContext;
		}
		
		@Override
		protected List<MultiPointItem> doInBackground(String... arg0) {
			String path = arg0[0];
			List<MultiPointItem> list = readMultiPoints(path);
			return list;
		}
		
		@Override
		protected void onPostExecute(List<MultiPointItem> result) {
			super.onPostExecute(result);
			String icon = "";
			double u = 0.5;
			double v = 0.5;
			if (styles != null) {
				icon = styles.optString("icon", icon);
				JSONObject anchor = styles.optJSONObject("anchor");
				if (anchor != null) {
					u = anchor.optDouble("x", 0.5);
					v = anchor.optDouble("y", 0.5);
				}
			}
			BitmapDescriptor descriptor = null;
			if (TextUtils.isEmpty(icon)) {
				descriptor = BitmapDescriptorFactory.fromResource(UZResourcesIDFinder.getResDrawableID("mo_amap_point6"));
			}else {
				icon = moduleContext.makeRealPath(icon);
				Bitmap bitmap = UZUtility.getLocalImage(icon);
				if (bitmap != null) {
					descriptor = BitmapDescriptorFactory.fromBitmap(bitmap);
				}
			}
			MultiPointOverlayOptions overlayOptions = new MultiPointOverlayOptions();
			overlayOptions.icon(descriptor);
			overlayOptions.anchor((float)u, (float)v);
			
			if (mAMap != null) {
				MultiPointOverlay multiPointOverlay = mAMap.addMultiPointOverlay(overlayOptions);
				multiPointOverlayMap.put(id, multiPointOverlay);
				multiPointOverlay.setItems(result);
				mAMap.setOnMultiPointClickListener(new OnMultiPointClickListener() {
					
					@Override
					public boolean onPointClick(MultiPointItem item) {
						try {
							JSONObject result = new JSONObject();
							result.put("eventType", "click");
							JSONObject point = new JSONObject();
							point.put("longitude", item.getLatLng().longitude);
							point.put("latitude", item.getLatLng().latitude);
							point.put("title", item.getTitle());
							point.put("subtitle", (String)item.getObject());
							point.put("customID", item.getCustomerId());
							result.put("point", point);
							moduleContext.success(result, false);
						} catch (Exception e) {
							// TODO: handle exception
						}
						return true;
					}
				});
			}
		}
	}
	
	private List<MultiPointItem> readMultiPoints(String path) {
		List<MultiPointItem> list = new ArrayList<>();
		try {
			InputStream inputStream = UZUtility.guessInputStream(path);
			if (inputStream != null) {
				String data = UZCoreUtil.readString(inputStream);
				if (!TextUtils.isEmpty(data)) {
					JSONArray arrayData = new JSONArray(data);
					for(int i = 0; i < arrayData.length(); i++) {
						JSONObject ponit = arrayData.optJSONObject(i);
						if (ponit != null) {
							double longitude = ponit.optDouble("longitude");
							double latitude = ponit.optDouble("latitude");
							String title = ponit.optString("title");
							String subtitle = ponit.optString("subtitle");
							String customID = ponit.optString("customID");
							MultiPointItem item = new MultiPointItem(new LatLng(latitude, longitude));
							item.setCustomerId(customID);
							item.setTitle(title);
							item.setObject(subtitle);
							list.add(item);
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
}
