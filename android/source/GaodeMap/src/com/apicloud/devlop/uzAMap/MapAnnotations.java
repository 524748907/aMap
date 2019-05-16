//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONObject;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.text.Html;
import android.text.TextUtils;
import android.util.Log;
import android.util.Pair;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.View.OnClickListener;
import android.view.View.OnTouchListener;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.amap.api.col.n3.nu;
import com.amap.api.maps.AMap;
import com.amap.api.maps.AMap.InfoWindowAdapter;
import com.amap.api.maps.AMap.OnInfoWindowClickListener;
import com.amap.api.maps.AMap.OnMarkerClickListener;
import com.amap.api.maps.AMap.OnMarkerDragListener;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.LatLngBounds;
import com.amap.api.maps.model.Marker;
import com.amap.api.maps.model.MarkerOptions;
import com.amap.api.maps.utils.SpatialRelationUtil;
import com.amap.api.maps.utils.overlay.SmoothMoveMarker;
import com.amap.api.maps.utils.overlay.SmoothMoveMarker.MoveListener;
import com.apicloud.devlop.uzAMap.models.Annotation;
import com.apicloud.devlop.uzAMap.models.Billboard;
import com.apicloud.devlop.uzAMap.models.Bubble;
import com.apicloud.devlop.uzAMap.models.MoveAnnotation;
import com.apicloud.devlop.uzAMap.models.WebBillBubb;
import com.apicloud.devlop.uzAMap.utils.CallBackUtil;
import com.apicloud.devlop.uzAMap.utils.JsParamsUtil;
import com.lidroid.xutils.BitmapUtils;
import com.lidroid.xutils.bitmap.BitmapDisplayConfig;
import com.lidroid.xutils.bitmap.callback.BitmapLoadCallBack;
import com.lidroid.xutils.bitmap.callback.BitmapLoadFrom;
import com.lidroid.xutils.util.OtherUtils;
import com.uzmap.pkg.uzcore.UZResourcesIDFinder;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

public class MapAnnotations
		implements OnMarkerClickListener, OnMarkerDragListener, OnInfoWindowClickListener, InfoWindowAdapter {
	private UzAMap mUzAMap;
	private AMap mAMap;
	private Context mContext;
	@SuppressLint("UseSparseArrays")
	private Map<String, Marker> mMarkers = new HashMap<String, Marker>();
	@SuppressLint("UseSparseArrays")
	private Map<String, Annotation> mAnnotations = new HashMap<String, Annotation>();
	@SuppressLint("UseSparseArrays")
	private Map<String, Billboard> mBillboards = new HashMap<String, Billboard>();
	private Map<Marker, Annotation> mMarkerAnnoMap = new HashMap<Marker, Annotation>();
	private Map<Marker, Billboard> mBillboardMap = new HashMap<Marker, Billboard>();
	@SuppressLint("UseSparseArrays")
	private Map<String, MoveAnnotation> mMoveMarkerMap = new HashMap<String, MoveAnnotation>();
	private Map<Marker, Object> mMarkerBubbleMap = new HashMap<Marker, Object>();
	private Map<Marker, MoveAnnotation> mMoveAnnoMap = new HashMap<Marker, MoveAnnotation>();
	private UzMapView mapView;
	private GestureDetector mDetector;
	private MyGestureListener mGestureListener;

	public MapAnnotations(UzAMap uzAMap, UzMapView mapView, Context context) {
		this.mUzAMap = uzAMap;
		this.mapView = mapView;
		this.mAMap = mapView.getMap();
		this.mContext = context;
		this.mAMap.setOnMarkerDragListener(this);
		this.mAMap.setOnMarkerClickListener(this);
		this.mAMap.setInfoWindowAdapter(this);
		this.mAMap.setOnInfoWindowClickListener(this);
		mGestureListener = new MyGestureListener();
		mDetector = new GestureDetector(context, mGestureListener);
	}

	public void addAnnotations(UZModuleContext moduleContext) {
		JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
		List<Annotation> annotations = jsParamsUtil.annotations(moduleContext, mUzAMap);
		if (annotations != null && annotations.size() > 0) {
			for (Annotation annotation : annotations) {
				mAnnotations.put(annotation.getId(), annotation);				
				Marker marker = mAMap.addMarker(createMarkerOptions(annotation.getLon(), annotation.getLat(),
						annotation.getIcons(), annotation.getIconsPath(), annotation.isDraggable(),
						(int) (annotation.getTimeInterval() * 50), annotation.getWidth(), annotation.getHeight()));
				boolean locked = annotation.locked();
				if (locked) {
					int lockedX = annotation.getLockedX();
					if (lockedX < 0) {
						lockedX = mapView.getWidth()/2;
					}
					int lockedY = annotation.getLockedY();
					if (lockedY < 0) {
						lockedY = mapView.getHeight()/2;
					}
					marker.setPositionByPixels(lockedX, lockedY);
				}

				Marker oldMarker = mMarkers.get(annotation.getId());
				if (oldMarker != null) {
					// oldMarker.destroy();
					oldMarker.remove();
				}
				mMarkers.put(annotation.getId(), marker);
				mMarkerAnnoMap.put(marker, annotation);
			}
		}
	}

	public void addMoveAnnotations(UZModuleContext moduleContext) {
		JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
		List<MoveAnnotation> annotations = jsParamsUtil.moveAnnotations(moduleContext, mUzAMap);
		if (annotations != null && annotations.size() > 0) {
			for (MoveAnnotation annotation : annotations) {
				mMoveMarkerMap.put(annotation.getId(), annotation);
				Marker marker = mAMap.addMarker(createMarkerOptions(annotation.getLon(), annotation.getLat(),
						annotation.getIcon(), annotation.isDraggable()));
				Marker oldMarker = mMarkers.get(annotation.getId());
				annotation.setMarker(marker);
				if (oldMarker != null) {
					// oldMarker.destroy();
					oldMarker.remove();
				}
				mMarkers.put(annotation.getId(), marker);
				mMoveAnnoMap.put(marker, annotation);
			}
		}
	}
	
	public void showAnnotations(UZModuleContext moduleContext) {
		if (mMarkers.size() > 0) {
			JSONArray ids = moduleContext.optJSONArray("ids");
			JSONObject insets = moduleContext.optJSONObject("insets");
			if (insets == null) {
				insets = new JSONObject();
			}
			int top = insets.optInt("top", 50);
			int left = insets.optInt("left", 50);
			int bottom = insets.optInt("bottom", 50);
			int right = insets.optInt("right", 50);
			boolean animation = moduleContext.optBoolean("animation", true);
			LatLngBounds.Builder b = LatLngBounds.builder();
			if (ids != null && ids.length() > 0) {
				for(int i = 0; i < ids.length(); i++) {
					Marker marker = mMarkers.get(ids.optString(i));
					if (marker != null) {
						LatLng p = new LatLng(marker.getPosition().latitude, marker.getPosition().longitude);
			            b.include(p);
					}
				}
				
			}else {
				for (Map.Entry<String, Marker> entry : mMarkers.entrySet()) {
				    Marker marker = entry.getValue();
				    if (marker != null) {
						LatLng p = new LatLng(marker.getPosition().latitude, marker.getPosition().longitude);
			            b.include(p);
					}
				}
			}
			LatLngBounds bounds = b.build();
			if (bounds != null) {
				if (animation) {
					this.mapView.getMap().animateCamera(CameraUpdateFactory.newLatLngBoundsRect(bounds, left, right, top, bottom));
				}else {
					this.mapView.getMap().moveCamera(CameraUpdateFactory.newLatLngBoundsRect(bounds, left, right, top, bottom));
				}
			}
		}
	}

	public void removeAnnotations(UZModuleContext moduleContext) {
		JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
		List<String> ids = jsParamsUtil.removeOverlayIds(moduleContext);
		if (ids != null && ids.size() > 0) {
			for (int i = 0; i < ids.size(); i++) {
				String id = ids.get(i);

				Marker marker = mMarkers.get(id);

				if (marker != null) {
					marker.setAlpha(0);
					marker.destroy();
					marker.remove();
					mMarkers.remove(id);
					marker = null;
				}
			}
		} else {
			mAMap.clear(true);
			mMarkers.clear();
		}
	}
	
	private Map<String, SmoothMoveMarker> smoothMarkerMap = new HashMap<>();
	private Map<String, Boolean> markFlag = new HashMap<>();
	
	/**
	 * 给地图上的标注添加移动动画
	 * @param moduleContext
	 */
	public void addMoveAnimation(final UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		SmoothMoveMarker sMarker = smoothMarkerMap.get(id);
		Marker marker = mMarkers.get(id);
		if (sMarker != null) {
			marker.setVisible(false);
			sMarker.setVisible(true);
			sMarker.startSmoothMove();
			return;
		}
		int duration = moduleContext.optInt("duration", 3);
		JSONArray coordinates = moduleContext.optJSONArray("coordinates");
		
		if (marker != null) {
			List<LatLng> points = readLatLngs(coordinates);
			LatLngBounds bounds = new LatLngBounds(points.get(0), points.get(points.size() - 1));
			mAMap.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, 50));
			
			SmoothMoveMarker smoothMarker = new SmoothMoveMarker(mAMap);
			smoothMarkerMap.put(id, smoothMarker);
			smoothMarker.setDescriptor(marker.getOptions().getIcon());
			
			LatLng drivePoint = points.get(0);
			Pair<Integer, LatLng> pair = SpatialRelationUtil.calShortestDistancePoint(points, drivePoint);
			points.set(pair.first, drivePoint);
			List<LatLng> subList = points.subList(pair.first, points.size());
			
			// 设置滑动的轨迹左边点
			smoothMarker.setPoints(subList);
			// 设置滑动的总时间
			smoothMarker.setTotalDuration(duration);
			// 开始滑动
			smoothMarker.startSmoothMove();
			marker.setVisible(false);
			MyMoveListener listener = new MyMoveListener(moduleContext, smoothMarker, marker, points, id);
			smoothMarker.setMoveListener(listener);
		}
	}
	
	private class MyMoveListener implements MoveListener{
		private UZModuleContext moduleContext;
		private SmoothMoveMarker smoothMarker;
		private Marker marker;
		private List<LatLng> points;
		private String id;
		public MyMoveListener(UZModuleContext moduleContext, SmoothMoveMarker smoothMarker, Marker marker, List<LatLng> points, String id) {
			this.moduleContext = moduleContext;
			this.smoothMarker = smoothMarker;
			this.marker = marker;
			this.points = points;
			this.id = id;
		}

		@Override
		public void move(double arg0) {
			try {
				Log.e("TAG", "距离的终点的距离:" + arg0);
				JSONObject result = new JSONObject();
				if (arg0 == 0) {
					markFlag.put(id, true);
					smoothMarker.removeMarker();
					marker.setPosition(new LatLng(points.get(points.size() -1).latitude, points.get(points.size() -1).longitude));
					marker.setVisible(true);
					//smoothMarker.destroy();
					smoothMarkerMap.remove(id);
					smoothMarker = null;
					result.put("isFinished", true);
				}else {
					result.put("isFinished", false);
				}
				moduleContext.success(result, false);
			} catch (Exception e) {
			}
		}
		
	}
	
	public void cancelMoveAnimation(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		SmoothMoveMarker smoothMarker = smoothMarkerMap.get(id);
		Marker marker = mMarkers.get(id);
		if (smoothMarker != null) {
			smoothMarker.stopMove();
			smoothMarker.setVisible(false);
			LatLng latLng = smoothMarker.getPosition();
			marker.setPosition(latLng);
			marker.setVisible(true);
//			smoothMarker.removeMarker();
//			smoothMarker.destroy();
//			smoothMarkerMap.remove(id);
//			smoothMarker = null;
		}
	}
	
	public List<LatLng> readLatLngs(JSONArray coordinates) {
		List<LatLng> list = new ArrayList<>();
		for(int i = 0; i < coordinates.length(); i++) {
			JSONObject jsonObject = coordinates.optJSONObject(i);
			double lon = jsonObject.optDouble("lon");
			double lat = jsonObject.optDouble("lat");
			LatLng latLng = new LatLng(lat, lon);
			list.add(latLng);
		}
		return list;
	}

	public void getAnnotationCoords(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		Marker marker = mMarkers.get(id);
		if (marker != null) {
			CallBackUtil.getMarkerCoordsCallBack(moduleContext, marker.getPosition().latitude,
					marker.getPosition().longitude);
		}
	}

	public void setAnnotationCoords(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		Marker marker = mMarkers.get(id);
		if (marker != null) {
			double lat = moduleContext.optDouble("lat");
			double lon = moduleContext.optDouble("lon");
			marker.setPosition(new LatLng(lat, lon));
		}
	}

	public void annotationExist(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		Marker marker = mMarkers.get(id);
		if (marker != null) {
			CallBackUtil.annotationExistCallBack(moduleContext, true);
		} else {
			CallBackUtil.annotationExistCallBack(moduleContext, false);
		}
	}

	public void setBubble(UZModuleContext moduleContext) {
		JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
		Bubble bubble = jsParamsUtil.bubble(moduleContext, mUzAMap);
		Marker marker = mMarkers.get(bubble.getId());
		if (marker != null) {
			// marker.showInfoWindow();
			mMarkerBubbleMap.put(marker, bubble);
			marker.setTitle("");
		}
	}

	/**
	 * @see 用来加载web bubble
	 */
	public void setWebBubble(UZModuleContext moduleContext) {
		Marker marker = mMarkers.get(moduleContext.optString("id"));
		if (marker != null) {
			mMarkerBubbleMap.put(marker, moduleContext);
			marker.setTitle("");
		}
	}

	public void popupBubble(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		Marker marker = mMarkers.get(id);
		if (marker != null) {
			marker.showInfoWindow();
			CallBackUtil.infoWindowClickCallBack(moduleContext, id, "click");
			LatLng centerLatLng = marker.getPosition();
			if (centerLatLng != null) {
				//mAMap.moveCamera(CameraUpdateFactory.newLatLngZoom(centerLatLng, mAMap.getCameraPosition().zoom));
			}
		}
	}

	public void closeBubble(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		Marker marker = mMarkers.get(id);
		if (marker != null) {
			marker.hideInfoWindow();
		}
	}

	String bgImgStr;

	@SuppressWarnings("deprecation")
	public void addBillboard(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		if (!mMarkers.containsKey(id)) {
			bgImgStr = moduleContext.makeRealPath(moduleContext.optString("bgImg"));
			JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
			Bubble bubble = jsParamsUtil.bubble(moduleContext, mUzAMap);
			bubble.setBillboard_bgImg(bgImgStr);
			String iconPath = bubble.getIconPath();
			String illusAlign = bubble.getIllusAlign();
			int layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_left_new");
			if (illusAlign == null || !illusAlign.equals("left")) {
				layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_right_new");
			}
			View infoContent = View.inflate(mContext, layoutId, null);
			int width = UZUtility.dipToPix(160);// 最外层的宽
			int height = UZUtility.dipToPix(75);// 最外层的高
			int imgX = UZUtility.dipToPix(10);// 图片的定点坐标
			int imgY = UZUtility.dipToPix(5);// 图片的定点坐标
			int imgW = UZUtility.dipToPix(35);// 图片宽
			int imgH = UZUtility.dipToPix(50);// 图片高
			int titleMarginT = UZUtility.dipToPix(10);// 标题上边距
			int titleMarginB = UZUtility.dipToPix(10);// 标题下边距
			int titleMaxLines = 1;
			int subTitleMaxLines = 1;
			int titleMarginLeft = UZUtility.dipToPix(10);
			int titleMarginRight = UZUtility.dipToPix(10);
			int subMarginLeft = UZUtility.dipToPix(10);
			int subMarginRight = UZUtility.dipToPix(10);
			String textalignment = "left";// 标题的对齐方式 左中右
			if (!moduleContext.isNull("styles")) {
				JSONObject styles = moduleContext.optJSONObject("styles");
				if (styles != null) {
					if (styles.has("size")) {
						JSONObject size = styles.optJSONObject("size");
						width = UZUtility.dipToPix(size.optInt("width", 160));
						height = UZUtility.dipToPix(size.optInt("height", 75));
					}
					if (styles.has("illusRect")) {
						JSONObject illusRect = styles.optJSONObject("illusRect");
						imgX = UZUtility.dipToPix(illusRect.optInt("x", 10));
						imgY = UZUtility.dipToPix(illusRect.optInt("y", 5));
						imgW = UZUtility.dipToPix(illusRect.optInt("w", 35));
						imgH = UZUtility.dipToPix(illusRect.optInt("h", 50));
					}
					if (styles.has("marginT")) {
						titleMarginT = UZUtility.dipToPix(styles.optInt("marginT", 10));
					}
					titleMarginB = UZUtility.dipToPix(styles.optInt("marginB", 10));
					if (styles.has("alignment")) {
						textalignment = styles.optString("alignment", "left");// 标题的对齐方式 左中右
					}
					titleMaxLines = styles.optInt("titleMaxLines",titleMaxLines);
					subTitleMaxLines = styles.optInt("subTitleMaxLines",subTitleMaxLines);
					titleMarginLeft = UZUtility.dipToPix(styles.optInt("titleMarginLeft",10));
					titleMarginRight = UZUtility.dipToPix(styles.optInt("titleMarginRight",10));
					subMarginLeft = UZUtility.dipToPix(styles.optInt("subTitleMarginLeft",10));
					subMarginRight = UZUtility.dipToPix(styles.optInt("subTitleMarginRight",10));
					
					bubble.setImgH(imgH);
					bubble.setImgW(imgW);
					bubble.setImgX(imgX);
					bubble.setImgY(imgY);
					bubble.setTitleMarginT(titleMarginT);
					bubble.setTitleMarginB(titleMarginB);
					bubble.setTitleMaxLines(titleMaxLines);
					bubble.setSubTitleMaxLines(subTitleMaxLines);
					bubble.setTitleMarginLeft(titleMarginLeft);
					bubble.setTitleMarginRight(titleMarginRight);
					bubble.setSubMarginLeft(subMarginLeft);
					bubble.setSubMarginRight(subMarginRight);
					
				}
			}
			
			JSONObject selectStylesJson = moduleContext.optJSONObject("selectedStyles");
			if (selectStylesJson != null) {
				String bgImg = mUzAMap.makeRealPath(selectStylesJson.optString("bgImg"));
				if (bgImg != null) {
					bubble.setBillboard_selected_bgImg(bgImg);
				}else {
					bubble.setBillboard_selected_bgImg(bgImgStr);
				}
				if (TextUtils.isEmpty(selectStylesJson.optString("titleColor"))) {
					bubble.setBillboard_selected_titleColor(bubble.getTitleColor());
				}else {
					int titleColor = UZUtility.parseCssColor(selectStylesJson.optString("titleColor"));
					bubble.setBillboard_selected_titleColor(titleColor);
				}
				if (TextUtils.isEmpty(selectStylesJson.optString("subTitleColor"))) {
					bubble.setBillboard_selected_subTitleColor(bubble.getSubTitleColor());
				}else {
					int subTitleColor = UZUtility.parseCssColor(selectStylesJson.optString("subTitleColor"));
					bubble.setBillboard_selected_subTitleColor(subTitleColor);
				}
				if (TextUtils.isEmpty(selectStylesJson.optString("illus"))) {
					bubble.setBillboard_selected_illus(moduleContext.makeRealPath(bubble.getIconPath()));
				}else {
					String illus = mUzAMap.makeRealPath(selectStylesJson.optString("illus"));
					bubble.setBillboard_selected_illus(illus);
				}
			}else {
				bubble.setBillboard_selected_bgImg(bgImgStr);
				bubble.setBillboard_selected_titleColor(bubble.getTitleColor());
				bubble.setBillboard_selected_subTitleColor(bubble.getSubTitleColor());
				bubble.setBillboard_selected_illus(moduleContext.makeRealPath(bubble.getIconPath()));
			}
			
			Bitmap bgImg = bubble.getBgImg();
			if (bgImg != null) {
				infoContent.setBackgroundDrawable(new BitmapDrawable(bgImg));
				// infoContent.setBackground(background);
				// infoContent.setBackgroundResource(UZResourcesIDFinder.getResDrawableID("paopao"));
			}
			RelativeLayout rlContent = (RelativeLayout)infoContent.findViewById(UZResourcesIDFinder.getResIdID("ll"));
			RelativeLayout.LayoutParams rlContentP = new RelativeLayout.LayoutParams(-1, -1);
//			rlContentP.leftMargin = UZUtility.dipToPix(10);
//			rlContentP.rightMargin = UZUtility.dipToPix(10);
			rlContent.setLayoutParams(rlContentP);
			
			infoContent.setLayoutParams(new ViewGroup.LayoutParams(width, height));
			TextView titleView = (TextView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("title"));
			titleView.setMaxLines(titleMaxLines);
			RelativeLayout.LayoutParams textViewParaT = new RelativeLayout.LayoutParams(-1, -2);
			textViewParaT.topMargin = titleMarginT;
			textViewParaT.leftMargin = titleMarginLeft;
			textViewParaT.rightMargin = titleMarginRight;
			//textViewParaT.rightMargin = UZUtility.dipToPix(5);
			//textViewParaT.addRule(RelativeLayout.CENTER_HORIZONTAL);
			titleView.setLayoutParams(textViewParaT);
			if (TextUtils.isEmpty(bubble.getTitle())) {
				titleView.setVisibility(View.GONE);// 如果标题是null 就隐藏
			}
			titleView.setText(bubble.getTitle());
			titleView.setTextColor(bubble.getTitleColor());
			titleView.setTextSize(bubble.getTitleSize());
			if (textalignment.equals("right")) {
				titleView.setGravity(Gravity.RIGHT);
			} else if (textalignment.equals("center")) {
				titleView.setGravity(Gravity.CENTER);
			} else {
				titleView.setGravity(Gravity.LEFT);
			}
			TextView subTitleView = (TextView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("subTitle"));
			RelativeLayout.LayoutParams textViewParaB = new RelativeLayout.LayoutParams(-1, -2);
			textViewParaB.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
			textViewParaB.bottomMargin = titleMarginB;
			textViewParaB.leftMargin = subMarginLeft;
			textViewParaB.rightMargin = subMarginRight;
//			textViewParaB.bottomMargin = titleMarginB;
			//textViewParaB.rightMargin = UZUtility.dipToPix(5);
			textViewParaB.addRule(RelativeLayout.BELOW, titleView.getId());
			textViewParaB.addRule(RelativeLayout.CENTER_HORIZONTAL);
			subTitleView.setMaxLines(subTitleMaxLines);
			subTitleView.setLayoutParams(textViewParaB);
			if (TextUtils.isEmpty(bubble.getSubTitle())) {
				subTitleView.setVisibility(View.GONE);// 如果标题是null 就隐藏
				//textViewParaT.addRule(RelativeLayout.CENTER_IN_PARENT);
				//textViewParaT.topMargin = 0;
				//textViewParaT.rightMargin = UZUtility.dipToPix(0);
			}
			
			subTitleView.setText(bubble.getSubTitle());
			subTitleView.setTextColor(bubble.getSubTitleColor());
			subTitleView.setTextSize(bubble.getSubTitleSize());
			if (textalignment.equals("right")) {
				subTitleView.setGravity(Gravity.RIGHT | Gravity.BOTTOM);
			} else if (textalignment.equals("center")) {
				subTitleView.setGravity(Gravity.CENTER | Gravity.BOTTOM);
			} else {
				subTitleView.setGravity(Gravity.LEFT | Gravity.BOTTOM);
			}
			ImageView iconView = (ImageView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("icon"));
			RelativeLayout.LayoutParams imgViewPara = new RelativeLayout.LayoutParams(imgW, imgH);
			imgViewPara.topMargin = imgY;
			imgViewPara.leftMargin = imgX;// +UZUtility.dipToPix(10);
			iconView.setLayoutParams(imgViewPara);
			double lat = jsParamsUtil.lat(moduleContext, "coords");
			double lon = jsParamsUtil.lon(moduleContext, "coords");
			boolean draggable = moduleContext.optBoolean("draggable", false);
			Billboard billboard = new Billboard(bubble.getId(), lat, lon, draggable, null, moduleContext);
			mBillboards.put(bubble.getId(), billboard);
			if (TextUtils.isEmpty(iconPath)) {
				iconView.setVisibility(View.GONE);
				//rlContent.setGravity(Gravity.CENTER);
				
				Marker marker = mAMap.addMarker(createBillboardOptions(lon, lat, infoContent, draggable, id));
				billboard.setMarker(marker);
				billboard.setView(infoContent);
				billboard.setBubble(bubble);
				if (!mMarkers.containsKey(bubble.getId())) {
					mMarkers.put(bubble.getId(), marker);
				}
				mBillboardMap.put(marker, billboard);
			} else {
				if (illusAlign == null || !illusAlign.equals("left")) {//right
					imgViewPara.addRule(RelativeLayout.RIGHT_OF, rlContent.getId());
//					imgViewPara.leftMargin = UZUtility.dipToPix(5);
				}else {
					rlContentP.addRule(RelativeLayout.RIGHT_OF, iconView.getId());
//					rlContentP.leftMargin = UZUtility.dipToPix(5);
				}
				if (iconPath.startsWith("http")) {
					billboard.setView(infoContent);
					getImgShowUtil().display(iconView, bubble.getIconPath(), getLoadCallBack(bubble));
				} else {
					// iconView.setBackgroundDrawable(new
					// BitmapDrawable(jsParamsUtil.getBitmap(mUzAMap.makeRealPath(bubble.getIconPath()))));
					// iconView.setImageBitmap(bm);
					
					//getImgShowUtil().display(iconView, mUzAMap.makeRealPath(bubble.getIconPath()));
					Bitmap bitmap = UZUtility.getLocalImage(mUzAMap.makeRealPath(bubble.getIconPath()));
					iconView.setImageBitmap(bitmap);
					Marker marker = mAMap.addMarker(createBillboardOptions(lon, lat, infoContent, draggable, id));
					billboard.setMarker(marker);
					billboard.setView(infoContent);
					billboard.setBubble(bubble);
					if (!mMarkers.containsKey(bubble.getId())) {
						mMarkers.put(bubble.getId(), marker);
					}
					mBillboardMap.put(marker, billboard);
				}
			}
		}
	}
	
	public void addWebBoard(UZModuleContext moduleContext) {
		String id = moduleContext.optString("id");
		if (!mMarkers.containsKey(id)) {
			
			BitmapDescriptor bitmapDescriptor = webBoardView(moduleContext);
			if (bitmapDescriptor != null) {
				JSONObject coordsJson = moduleContext.optJSONObject("coords");
				MarkerOptions markerOptions = new MarkerOptions();
				markerOptions.anchor(0.5f, 1f).position(new LatLng(coordsJson.optDouble("lat"), coordsJson.optDouble("lon"))).draggable(false).icon(bitmapDescriptor).title(id);
				Marker marker = mAMap.addMarker(markerOptions);
				String url = moduleContext.optString("url");
				String data = moduleContext.optString("data");
				JSONObject sizeJson = moduleContext.optJSONObject("size");
				if (sizeJson == null) {
					sizeJson = new JSONObject();
				}
				int width = sizeJson.optInt("w", 50);
				int height = sizeJson.optInt("h", 50);
				WebBillBubb billBubb = new WebBillBubb(id, url, data, width, height);
				mMarkerBubbleMap.put(marker, billBubb);
			}
			
			
		}
	}
	
	public BitmapDescriptor webBoardView(UZModuleContext moduleContext) {
		
		JSONObject sizeJson = moduleContext.optJSONObject("size");
		if (sizeJson == null) {
			sizeJson = new JSONObject();
		}
		int width = sizeJson.optInt("w", 100);
		int height = sizeJson.optInt("h", 100);
		String bg = moduleContext.optString("bg");
		Bitmap bitmap = UZUtility.getLocalImage(moduleContext.makeRealPath(bg));
		if (bitmap != null) {
			WebView webView = new WebView(mContext);
			RelativeLayout.LayoutParams webParams = new RelativeLayout.LayoutParams(UZUtility.dipToPix(width), UZUtility.dipToPix(height));
			webView.setLayoutParams(webParams);
			webView.setBackgroundDrawable(new BitmapDrawable(bitmap));
			
			String url = moduleContext.optString("url");// 目前url:www.baidu.com
			String data = moduleContext.optString("data");
			
			// 这里需要判断url是否/绝对路径开头，如果是，则加上file://
			if (url != null && url.startsWith("/")) {
				url = "file://" + url;
			}
			if (TextUtils.isEmpty(data)) {// 如果data是空就加载网页
				webView.loadUrl(url);
				webView.setWebViewClient(new WebViewClient() {
					@Override
					public boolean shouldOverrideUrlLoading(WebView view, String url) {
						view.loadUrl(url);
						return true;
					}
				});
			} else {// 否则就加载data数据的片段
				webView.getSettings().setJavaScriptEnabled(true);
				webView.getSettings().setDefaultTextEncodingName("utf-8");

				webView.loadDataWithBaseURL(url, data, "text/html", "utf-8", null);
			}
			
			BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory.fromView(webView);
			return bitmapDescriptor;
		}else {
			return null;
		}
		
	}

	private BitmapLoadCallBack<View> getLoadCallBack(final Bubble bubble) {
		return new BitmapLoadCallBack<View>() {
			@Override
			public void onLoadCompleted(View container, String uri, Bitmap bitmap, BitmapDisplayConfig displayConfig,
					BitmapLoadFrom from) {
				((ImageView) container).setImageBitmap(bitmap);
				Billboard billboard = mBillboards.get(bubble.getId());
				if (billboard != null) {
					Marker marker = mAMap.addMarker(createBillboardOptions(billboard.getLon(), billboard.getLat(),
							billboard.getView(), billboard.isDraggable(), bubble.getId()));
					billboard.setMarker(marker);
					billboard.setBubble(bubble);
					mMarkers.put(bubble.getId(), marker);
					mBillboardMap.put(marker, billboard);
				}
			}

			@Override
			public void onLoading(View container, String uri, BitmapDisplayConfig config, long total, long current) {
			}

			@Override
			public void onLoadFailed(View container, String uri, Drawable failedDrawable) {
			}
		};
	}

	private MarkerOptions createBillboardOptions(double lon, double lat, View view, boolean draggable, String id) {
		MarkerOptions markerOptions = new MarkerOptions();
		BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory.fromView(view);
		// BitmapDescriptor bitmapDescriptor =
		// BitmapDescriptorFactory.fromPath(bgImgStr);
		markerOptions.anchor(0.5f, 1f).position(new LatLng(lat, lon)).draggable(draggable).icon(bitmapDescriptor)
				.title(id);
		return markerOptions;
	}

	@SuppressWarnings("deprecation")
	private MarkerOptions createMarkerOptions(double lon, double lat, List<Bitmap> icons, List<String> iconsPath,
			boolean draggable, int period, int aWidth, int aHeight) {
		MarkerOptions markerOptions = new MarkerOptions();
		if (icons != null && icons.size() > 0) {
			ArrayList<BitmapDescriptor> giflist = new ArrayList<BitmapDescriptor>();
			BitmapDescriptor bitmapDescriptor = null;
			JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
// 			for (String icon : iconsPath) {
//				if (icon != null) {
//					if (aWidth == -1 || aHeight == -1) {
//						bitmapDescriptor = BitmapDescriptorFactory.fromBitmap(jsParamsUtil.getBitmap(icon, -1, -1));
//					}else {
//						Bitmap bgImg = UZUtility.getLocalImage(icon);
//						int width = bgImg.getWidth();
//						int height = bgImg.getHeight();
//						float scaleWidth = ((float) UZUtility.dipToPix(aWidth)) / width;  
//					    float scaleHeight = ((float) UZUtility.dipToPix(aHeight)) / height;  
//
//						Matrix matrix = new Matrix();  
//					    matrix.postScale(scaleWidth, scaleHeight);
//					    Bitmap newBitmap = Bitmap.createBitmap(bgImg, 0, 0, width, height, matrix, true); 
//					    bitmapDescriptor = BitmapDescriptorFactory.fromBitmap(newBitmap);
//					}
//					
//					giflist.add(bitmapDescriptor);
//				}
//			}
 			for(int i = 0; i < icons.size(); i++) {
 				Bitmap bitmap = icons.get(i);
			    bitmapDescriptor = BitmapDescriptorFactory.fromBitmap(bitmap);
 				giflist.add(bitmapDescriptor);
 			}
			markerOptions.icons(giflist);
		} else {
			BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_RED);
			markerOptions.icon(bitmapDescriptor);
		}
		markerOptions.anchor(0.5f, 1f).position(new LatLng(lat, lon)).draggable(draggable).period(period)
				.perspective(true).title(null).snippet(null);
		return markerOptions;
	}

	@SuppressWarnings("deprecation")
	private MarkerOptions createMarkerOptions(double lon, double lat, Bitmap icon, boolean draggable) {
		MarkerOptions markerOptions = new MarkerOptions();
		BitmapDescriptor bitmapDescriptor = null;
		if (icon != null) {
			bitmapDescriptor = BitmapDescriptorFactory.fromBitmap(icon);
			markerOptions.icon(bitmapDescriptor);

		} else {
			bitmapDescriptor = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_RED);
			markerOptions.icon(bitmapDescriptor);
		}
		markerOptions.anchor(0.5f, 0.5f).position(new LatLng(lat, lon)).draggable(draggable).perspective(true)
				.title(null).snippet(null);
		return markerOptions;
	}

	@Override
	public void onMarkerDrag(Marker marker) {
		Annotation annotation = mMarkerAnnoMap.get(marker);
		if (annotation != null) {
			CallBackUtil.markerDragCallBack(annotation.getModuleContext(), annotation.getId(), "dragging");
			return;
		}
		Billboard billboard = mBillboardMap.get(marker);
		if (billboard != null) {
			CallBackUtil.markerDragCallBack(billboard.getModuleContext(), billboard.getId(), "dragging");
		}
	}

	@Override
	public void onMarkerDragEnd(Marker marker) {
		Annotation annotation = mMarkerAnnoMap.get(marker);
		if (annotation != null) {
			CallBackUtil.markerDragCallBack(annotation.getModuleContext(), annotation.getId(), "ending");
			return;
		}
		Billboard billboard = mBillboardMap.get(marker);
		if (billboard != null) {
			CallBackUtil.markerDragCallBack(billboard.getModuleContext(), billboard.getId(), "ending");
		}
	}

	@Override
	public void onMarkerDragStart(Marker marker) {
		Annotation annotation = mMarkerAnnoMap.get(marker);
		if (annotation != null) {
			CallBackUtil.markerDragCallBack(annotation.getModuleContext(), annotation.getId(), "starting");
			return;
		}
		Billboard billboard = mBillboardMap.get(marker);
		if (billboard != null) {
			CallBackUtil.markerDragCallBack(billboard.getModuleContext(), billboard.getId(), "starting");
		}
	}

	//List<Marker> markList = new ArrayList<Marker>();
	Marker[] marks = new Marker[1];
	Billboard[] billboards = new Billboard[1];
	Marker[] bill_marker = new Marker[1];
	@Override
	public boolean onMarkerClick(Marker marker) {
		Object bubble = mMarkerBubbleMap.get(marker);
		if (bubble instanceof Bubble) {
			setWebBubbleUrl = false;
		}else if(bubble instanceof UZModuleContext){
			setWebBubbleUrl = true;
		}else if (bubble instanceof WebBillBubb) {
			//WebBillBubb webBillBubb = (WebBillBubb)bubble;
			//mUzAMap.addWebBoardListener(webBillBubb.getId());
		}
		marker.showInfoWindow();
		
		Annotation annotation = mMarkerAnnoMap.get(marker);
		if (annotation != null) {
			
			List<Bitmap> selectIcon = annotation.getSelectIcons();
			if (selectIcon != null && selectIcon.size() > 0) {
				ArrayList<BitmapDescriptor> gifs = new ArrayList<BitmapDescriptor>();
				for(int i = 0; i < selectIcon.size(); i++) {
					Bitmap bitmap = selectIcon.get(i);
					gifs.add(BitmapDescriptorFactory.fromBitmap(bitmap));
				}
				marker.setIcons(gifs);
			}
			
			if (marks.length > 0) {
				Marker oldMark = marks[0];
				if (oldMark != null) {
					Annotation oldAnnotation = mMarkerAnnoMap.get(oldMark);
					List<Bitmap> oldIcons = oldAnnotation.getIcons();
					if (oldIcons != null && oldIcons.size() > 0) {
						ArrayList<BitmapDescriptor> giflist = new ArrayList<BitmapDescriptor>();					
						for(int i = 0; i < oldIcons.size(); i++) {
							giflist.add(BitmapDescriptorFactory.fromBitmap(oldIcons.get(i)));
						}
						oldMark.setIcons(giflist);
					} else {
						BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_RED);
						oldMark.setIcon(bitmapDescriptor);
					}
				}
				marks[0] = marker;
			}
			
			CallBackUtil.markerClickCallBack(annotation.getModuleContext(), annotation.getId());
			return true;
		}
		Billboard billboard = mBillboardMap.get(marker);
		
		if (billboard != null) {
			Bubble billboard_bubble = billboard.getBubble();
			if (billboard_bubble != null) {
				
				
				Billboard bill = billboards[0];
				Marker marker2 = bill_marker[0];
				
				if (changeView(billboard_bubble, billboard.getModuleContext())) {
					if (bill == null || billboard.getId() != bill.getId()) {
						setBillboardView(billboard, billboard_bubble, marker, false);
					}
				}
				if (bill != null && marker2 != null) {
					if (billboard.getId() != bill.getId()) {
						setBillboardView(bill, bill.getBubble(), marker2, true);
					}
				}
				billboards[0] = billboard;
				bill_marker[0] = marker;
			}
			
			CallBackUtil.markerClickCallBack(billboard.getModuleContext(), billboard.getId());
			return true;
		}
		return true;
	}
	
	private boolean changeView(Bubble bubble, UZModuleContext moduleContext) {
		String billboard_selected_bgImg = bubble.getBillboard_selected_bgImg();
		int billboard_selected_titleColor = bubble.getBillboard_selected_titleColor();
		int billboard_selected_subTitleColor = bubble.getBillboard_selected_subTitleColor();
		String billboard_selected_illus = bubble.getBillboard_selected_illus();
		
		if (!TextUtils.equals(billboard_selected_bgImg, bubble.getBillboard_bgImg()) ||
				billboard_selected_titleColor != bubble.getTitleColor() ||
				billboard_selected_subTitleColor != bubble.getSubTitleColor() ||
				!TextUtils.equals(billboard_selected_illus, moduleContext.makeRealPath(bubble.getIconPath()))) {
			return true;
		}else {
			return false;
		}
	}
	
	private void setBillboardView(Billboard billboard, Bubble billboard_bubble, Marker marker, boolean isOld) {
		String billboard_selected_bgImg = billboard_bubble.getBillboard_selected_bgImg();
		int billboard_selected_titleColor = billboard_bubble.getBillboard_selected_titleColor();
		int billboard_selected_subTitleColor = billboard_bubble.getBillboard_selected_subTitleColor();
		String billboard_selected_illus = billboard_bubble.getBillboard_selected_illus();
		UZModuleContext moduleContext = billboard.getModuleContext();
		
		int layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_left_new");
		String illusAlign = billboard_bubble.getIllusAlign();
		if (illusAlign == null || !illusAlign.equals("left")) {
			layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_right_new");
		}
		View infoContent = View.inflate(mContext, layoutId, null);
		Bitmap bitmap;
		if (isOld) {
			bitmap = UZUtility.getLocalImage(billboard_bubble.getBillboard_bgImg());
		}else {
			if (!TextUtils.equals(billboard_selected_bgImg, billboard_bubble.getBillboard_bgImg())) {
				bitmap = UZUtility.getLocalImage(billboard_selected_bgImg);
			}else {
				bitmap = UZUtility.getLocalImage(billboard_bubble.getBillboard_bgImg());
			}
		}
		infoContent.setBackgroundDrawable(new BitmapDrawable(bitmap));
		RelativeLayout rlContent = (RelativeLayout)infoContent.findViewById(UZResourcesIDFinder.getResIdID("ll"));
		RelativeLayout.LayoutParams rlContentP = new RelativeLayout.LayoutParams(-1, -1);
//		rlContentP.leftMargin = UZUtility.dipToPix(10);
//		rlContentP.rightMargin = UZUtility.dipToPix(10);
		rlContent.setLayoutParams(rlContentP);
		
		int width = UZUtility.dipToPix(160);// 最外层的宽
		int height = UZUtility.dipToPix(75);// 最外层的高
		int imgX = UZUtility.dipToPix(10);// 图片的定点坐标
		int imgY = UZUtility.dipToPix(5);// 图片的定点坐标
		int imgW = UZUtility.dipToPix(35);// 图片宽
		int imgH = UZUtility.dipToPix(50);// 图片高
		int titleMarginT = UZUtility.dipToPix(10);// 标题上边距
		int titleMarginB = UZUtility.dipToPix(10);// 标题下边距
		String textalignment = "left";// 标题的对齐方式 左中右
		if (!moduleContext.isNull("styles")) {
			JSONObject styles = moduleContext.optJSONObject("styles");
			if (styles != null && styles.has("size")) {
				JSONObject size = styles.optJSONObject("size");
				width = UZUtility.dipToPix(size.optInt("width", 160));
				height = UZUtility.dipToPix(size.optInt("height", 75));
			}
			if (styles != null && styles.has("illusRect")) {
				JSONObject illusRect = styles.optJSONObject("illusRect");
				imgX = UZUtility.dipToPix(illusRect.optInt("x", 10));
				imgY = UZUtility.dipToPix(illusRect.optInt("y", 5));
				imgW = UZUtility.dipToPix(illusRect.optInt("w", 35));
				imgH = UZUtility.dipToPix(illusRect.optInt("h", 50));
			}
			if (styles != null && styles.has("marginT")) {
				titleMarginT = UZUtility.dipToPix(styles.optInt("marginT", 10));
				titleMarginB = UZUtility.dipToPix(styles.optInt("marginB", 10));
			}
			if (styles != null && styles.has("alignment")) {
				textalignment = styles.optString("alignment", "left");// 标题的对齐方式 左中右
			}
		}
		infoContent.setLayoutParams(new ViewGroup.LayoutParams(width, height));
		
		TextView titleView = (TextView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("title"));
		RelativeLayout.LayoutParams textViewParaT = new RelativeLayout.LayoutParams(-1, -2);
		textViewParaT.topMargin = titleMarginT;
		textViewParaT.leftMargin = billboard_bubble.getTitleMarginLeft();
		textViewParaT.rightMargin = billboard_bubble.getTitleMarginRight();
		//textViewParaT.rightMargin = UZUtility.dipToPix(5);
		titleView.setLayoutParams(textViewParaT);
		if (TextUtils.isEmpty(billboard_bubble.getTitle())) {
			titleView.setVisibility(View.GONE);// 如果标题是null 就隐藏
		}
		titleView.setMaxLines(billboard_bubble.getTitleMaxLines());
		
		titleView.setText(billboard_bubble.getTitle());
		if (isOld) {
			titleView.setTextColor(billboard_bubble.getTitleColor());
		}else {
			if (billboard_selected_titleColor != billboard_bubble.getTitleColor()) {
				titleView.setTextColor(billboard_selected_titleColor);
			}else {
				titleView.setTextColor(billboard_bubble.getTitleColor());
			}
		}
		
		titleView.setTextSize(billboard_bubble.getTitleSize());
		if (textalignment.equals("right")) {
			titleView.setGravity(Gravity.RIGHT);
		} else if (textalignment.equals("center")) {
			titleView.setGravity(Gravity.CENTER);
		} else {
			titleView.setGravity(Gravity.LEFT);
		}
		TextView subTitleView = (TextView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("subTitle"));
		RelativeLayout.LayoutParams textViewParaB = new RelativeLayout.LayoutParams(-1, -2);
		textViewParaB.leftMargin = billboard_bubble.getSubMarginLeft();
		textViewParaB.rightMargin = billboard_bubble.getSubMarginRight();
		textViewParaB.bottomMargin = titleMarginB;
		//textViewParaB.bottomMargin = titleMarginB;
		//textViewParaB.rightMargin = UZUtility.dipToPix(5);
		textViewParaB.addRule(RelativeLayout.BELOW, titleView.getId());
		subTitleView.setLayoutParams(textViewParaB);
		subTitleView.setMaxLines(billboard_bubble.getSubTitleMaxLines());
		if (TextUtils.isEmpty(billboard_bubble.getSubTitle())) {
			subTitleView.setVisibility(View.GONE);// 如果标题是null 就隐藏
//			textViewParaT.addRule(RelativeLayout.CENTER_IN_PARENT);
//			textViewParaT.topMargin = 0;
//			textViewParaT.rightMargin = UZUtility.dipToPix(0);
		}
		textViewParaB.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
		textViewParaB.addRule(RelativeLayout.CENTER_HORIZONTAL);
		
		subTitleView.setText(billboard_bubble.getSubTitle());
		if (isOld) {
			subTitleView.setTextColor(billboard_bubble.getSubTitleColor());
		}else {
			if (billboard_selected_subTitleColor != billboard_bubble.getSubTitleColor()) {
				subTitleView.setTextColor(billboard_selected_subTitleColor);
			}else {
				subTitleView.setTextColor(billboard_bubble.getSubTitleColor());
			}
		}
		
		subTitleView.setTextSize(billboard_bubble.getSubTitleSize());
		if (textalignment.equals("right")) {
			subTitleView.setGravity(Gravity.RIGHT | Gravity.BOTTOM);
		} else if (textalignment.equals("center")) {
			subTitleView.setGravity(Gravity.CENTER | Gravity.BOTTOM);
		} else {
			subTitleView.setGravity(Gravity.LEFT | Gravity.BOTTOM);
		}
		ImageView iconView = (ImageView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("icon"));
		RelativeLayout.LayoutParams imgViewPara = new RelativeLayout.LayoutParams(imgW, imgH);
		imgViewPara.topMargin = imgY;
		imgViewPara.leftMargin = imgX;// +UZUtility.dipToPix(10);
		iconView.setLayoutParams(imgViewPara);
		if (TextUtils.isEmpty(billboard_selected_illus) || TextUtils.isEmpty(billboard_bubble.getIconPath())) {
			iconView.setVisibility(View.GONE);
			//rlContent.setGravity(Gravity.CENTER);
		}else {
			if (illusAlign == null || !illusAlign.equals("left")) {
				imgViewPara.addRule(RelativeLayout.RIGHT_OF, rlContent.getId());
//				imgViewPara.leftMargin = UZUtility.dipToPix(5);
			}else {
				rlContentP.addRule(RelativeLayout.RIGHT_OF, iconView.getId());
//				rlContentP.leftMargin = UZUtility.dipToPix(5);
			}
			String imagePath = null;
			if (!TextUtils.equals(billboard_selected_illus, billboard_bubble.getIconPath())) {
				imagePath = billboard_selected_illus;
			}else {
				imagePath = billboard_selected_illus;
			}
			if (imagePath.startsWith("http://") || imagePath.startsWith("https://")) {
				getImgShowUtil().display(iconView, imagePath, new BitmapLoadCallBack<View>() {

					@Override
					public void onLoadCompleted(View container, String uri, Bitmap bitmap, BitmapDisplayConfig displayConfig,
							BitmapLoadFrom from) {
						((ImageView) container).setImageBitmap(bitmap);
					}

					@Override
					public void onLoadFailed(View arg0, String arg1, Drawable arg2) {
						// TODO Auto-generated method stub
						
					}
				});
			}else {
				Bitmap bitmap1 = UZUtility.getLocalImage(imagePath);
				iconView.setImageBitmap(bitmap1);
			}
		}
		
		BitmapDescriptor bitmapDescriptor = BitmapDescriptorFactory.fromView(infoContent);
		marker.setIcon(bitmapDescriptor);
		
	}

	@Override
	public void onInfoWindowClick(Marker marker) {
		marker.showInfoWindow();
	}

	@Override
	public View getInfoContents(Marker marker) {
		View infoContent = null;
		
		return infoContent;
	}

	/**
	 * 气泡是否是url加载
	 */
	public boolean setWebBubbleUrl = false;

	@SuppressWarnings("deprecation")
	@Override
	public View getInfoWindow(Marker marker) {
		View infoContent = null;
		Object bubbleObj = mMarkerBubbleMap.get(marker);
		if (bubbleObj instanceof Bubble) {
			setWebBubbleUrl = false;
			final Bubble bubble = (Bubble) bubbleObj;
			
			String illusAlign = bubble.getIllusAlign();
			int layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_left");
			// int layoutId = UZResourcesIDFinder.getResLayoutID("bubble_left");
			if (illusAlign == null || !illusAlign.equals("left")) {
				layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_right");
			}
			infoContent = View.inflate(mContext, layoutId, null);
			RelativeLayout rLayout = (RelativeLayout)infoContent.findViewById(UZResourcesIDFinder.getResIdID("rl_root"));
			LinearLayout linearLayout = (LinearLayout) infoContent.findViewById(UZResourcesIDFinder.getResIdID("ll"));
			linearLayout.setPadding(5, 5, 5, 5);
			Bitmap bgImg = bubble.getBgImg();
			if (bgImg != null) {
				int width = bgImg.getWidth();
				int height = bgImg.getHeight();
				float scaleWidth = ((float) UZUtility.dipToPix(bubble.getWidth())) / width;  
			    float scaleHeight = ((float) UZUtility.dipToPix(bubble.getHeight())) / height;  

				Matrix matrix = new Matrix();  
			    matrix.postScale(scaleWidth, scaleHeight);
			    Bitmap newBitmap = Bitmap.createBitmap(bgImg, 0, 0, width, height, matrix, true); 
				infoContent.setBackgroundDrawable(new BitmapDrawable(newBitmap));

				// int w = bgImg.getWidth();
				// linearLayout.setLayoutParams(new RelativeLayout.LayoutParams(160, height));
				// infoContent.setLayoutParams(new ViewGroup.LayoutParams(bgImg.getWidth(),
				// bgImg.getHeight()));
			} else {
				infoContent.setBackgroundResource(UZResourcesIDFinder.getResDrawableID("mo_amap_custom_info_bubble"));
				// infoContent.setLayoutParams(new LayoutParams(LayoutParams.WRAP_CONTENT,
				// UZUtility.dipToPix(90)));
			}

			ImageView iconView = (ImageView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("icon"));
			RelativeLayout.LayoutParams iconParams = new RelativeLayout.LayoutParams(-1,  -1);
			iconParams.addRule(RelativeLayout.CENTER_VERTICAL);
			//iconView.setLayoutParams(iconParams);
			//iconView.setScaleType(ScaleType.FIT_XY);
			iconView.setOnClickListener(new OnClickListener() {

				@Override
				public void onClick(View v) {
					CallBackUtil.infoWindowClickCallBack(bubble.getModuleContext(), bubble.getId(), "clickIllus");
				}
			});
			if (bubble.getIconPath() != null && bubble.getIconPath().startsWith("http")) {
				getImgShowUtil().display(iconView, bubble.getIconPath(), getLoadCallBack(bubble));
			} else {
				JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
				//iconView.setBackgroundDrawable(new BitmapDrawable(jsParamsUtil.getBitmap(mUzAMap.makeRealPath(bubble.getIconPath()))));
				iconView.setImageBitmap(UZUtility.getLocalImage(mUzAMap.makeRealPath(bubble.getIconPath())));
			}
			if (bubble.getIconPath() == null || bubble.getIconPath().isEmpty()) {
				iconView.setVisibility(View.GONE);
			}

			TextView titleView = (TextView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("title"));
			titleView.setText(bubble.getTitle());
			titleView.setTextColor(bubble.getTitleColor());
			titleView.setTextSize(bubble.getTitleSize());

			titleView.setOnClickListener(new OnClickListener() {

				@Override
				public void onClick(View v) {
					CallBackUtil.infoWindowClickCallBack(bubble.getModuleContext(), bubble.getId(), "clickContent");
				}
			});
			TextView subTitleView = (TextView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("subTitle"));
			subTitleView.setText(bubble.getSubTitle());
			subTitleView.setTextColor(bubble.getSubTitleColor());
			subTitleView.setTextSize(bubble.getSubTitleSize());
			subTitleView.setOnClickListener(new OnClickListener() {

				@Override
				public void onClick(View v) {
					CallBackUtil.infoWindowClickCallBack(bubble.getModuleContext(), bubble.getId(), "clickContent");
				}
			});
			if (TextUtils.isEmpty(bubble.getSubTitle())) {
				subTitleView.setVisibility(View.GONE);
			}
			return infoContent;
		}else if(bubbleObj instanceof UZModuleContext){
			setWebBubbleUrl = true;
			final UZModuleContext moduleContext = (UZModuleContext) mMarkerBubbleMap.get(marker);
			
			int layoutId = UZResourcesIDFinder.getResLayoutID("webview");

			infoContent = View.inflate(mContext, layoutId, null);

			//new 
			RelativeLayout rl = (RelativeLayout) infoContent.findViewById(UZResourcesIDFinder.getResIdID("rl"));
			WebView webView = (WebView) infoContent
					.findViewById(UZResourcesIDFinder.getResIdID("mo_amap_bubble_webview"));
			int width = 50;
			int hight = 50;
			String bg = moduleContext.optString("bg", "rgba(0, 0, 0, 0)");

			if (UZUtility.isHtmlColor(bg)) {
				infoContent.setBackgroundColor(UZUtility.parseCssColor(bg));
				webView.setBackgroundColor(UZUtility.parseCssColor(bg));
			} else {
				Bitmap bitmap = JsParamsUtil.getInstance().getBitmap(mUzAMap.makeRealPath(bg), -1, -1);
				
				infoContent.setBackgroundDrawable(new BitmapDrawable(bitmap));
				
				webView.setBackgroundColor(Color.TRANSPARENT);
			}
			JSONObject size = moduleContext.optJSONObject("size");
			if (size != null && !moduleContext.isNull("size")) {
				width = size.optInt("width", 50);
				hight = size.optInt("height", 50);
			}
						
			rl.setLayoutParams(new RelativeLayout.LayoutParams(UZUtility.dipToPix(width), UZUtility.dipToPix(hight)));
			
			webView.setClickable(true);
			webView.setOnClickListener(new OnClickListener() {
				
				@Override
				public void onClick(View arg0) {
					Log.e("TAG", "lll");
				}
			});
			webView.setOnTouchListener(new OnTouchListener() {
				
				@Override
				public boolean onTouch(View arg0, MotionEvent event) {
					
					if (event.getAction() == MotionEvent.ACTION_DOWN) {
						if (UzAMap.webBubbleModuleContext != null) {
							try {
								String id = moduleContext.optString("id");
								JSONObject result = new JSONObject();
								result.put("id", id);
								UzAMap.webBubbleModuleContext.success(result, false);
							} catch (Exception e) {
								// TODO: handle exception
							}
							
						}
						return false;
					}else {
						return false;
					}
					
				}
			});
			String url = moduleContext.makeRealPath(moduleContext.optString("url"));
			// 这里需要判断url是否/绝对路径开头，如果是，则加上file://
			if (url != null && url.startsWith("/"))
				url = "file://" + url;
			if (moduleContext.isNull("data")) {// 如果data是空就加载网页
				webView.loadUrl(url);
				webView.setWebViewClient(new WebViewClient() {
					@Override
					public boolean shouldOverrideUrlLoading(WebView view, String url) {
						view.loadUrl(url);
						return true;
					}
				});
			} else {// 否则就加载data数据的片段
				String data = moduleContext.optString("data", "data parameter is nothing");
				webView.getSettings().setJavaScriptEnabled(true);
				webView.getSettings().setDefaultTextEncodingName("utf-8");

				webView.loadDataWithBaseURL(url, data, "text/html", "utf-8", null);
			}
			return infoContent;
		}
		return infoContent;
	}
	
	class MyGestureListener extends GestureDetector.SimpleOnGestureListener {
		
        public MyGestureListener() {
            super();
        }
        private String id;
        public void setWebBubbleId(String id) {
        		this.id = id;
        }

        @Override
        public boolean onDoubleTap(MotionEvent e) {
            
            return true;
        }

        @Override
        public boolean onDoubleTapEvent(MotionEvent e) {
            return true;
        }

        @Override
        public boolean onSingleTapConfirmed(MotionEvent e) {
        		mUzAMap.addWebBoardListener(id);
            return true;
        }

        @Override
        public boolean onDown(MotionEvent e) {
            
            return true;
        }

        @Override
        public void onShowPress(MotionEvent e) {

        }

        @Override
        public boolean onSingleTapUp(MotionEvent e) {
            return true;
        }

        @Override
        public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY) {
            
            return super.onScroll(e1, e2, distanceX, distanceY);
        }

        @Override
        public void onLongPress(MotionEvent e) {
        }

        @Override
        public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY) {
            Log.e("TAG", "velocityX ：" + velocityX); // 左--右 负数 右 -- 左 正数
            Log.e("TAG", "velocityY ：" + velocityY);// 从上--下 负值 从下--上 正数
            return true;
        }

    }

	private BitmapUtils getImgShowUtil() {
		BitmapUtils bitmapUtils = new BitmapUtils(mContext, OtherUtils.getDiskCacheDir(mContext, ""));
		bitmapUtils.configDiskCacheEnabled(true);
		bitmapUtils.configMemoryCacheEnabled(true);
		return bitmapUtils;
	}

	public Map<String, MoveAnnotation> getMoveMarkerMap() {
		return mMoveMarkerMap;
	}

	

}
