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

import org.json.JSONException;
import org.json.JSONObject;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.text.TextUtils;
import android.text.style.BulletSpan;
import android.util.Log;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.MeasureSpec;
import android.view.ViewGroup;
import android.view.View.OnClickListener;
import android.view.View.OnTouchListener;
import android.webkit.WebSettings;
import android.webkit.WebSettings.LayoutAlgorithm;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout.LayoutParams;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.amap.api.maps.AMap;
import com.amap.api.maps.AMap.InfoWindowAdapter;
import com.amap.api.maps.AMap.OnInfoWindowClickListener;
import com.amap.api.maps.AMap.OnMarkerClickListener;
import com.amap.api.maps.AMap.OnMarkerDragListener;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.Marker;
import com.amap.api.maps.model.MarkerOptions;
import com.apicloud.amap.R;
import com.apicloud.devlop.uzAMap.models.Annotation;
import com.apicloud.devlop.uzAMap.models.Billboard;
import com.apicloud.devlop.uzAMap.models.Bubble;
import com.apicloud.devlop.uzAMap.models.MoveAnnotation;
import com.apicloud.devlop.uzAMap.utils.CallBackUtil;
import com.apicloud.devlop.uzAMap.utils.JsParamsUtil;
import com.lidroid.xutils.BitmapUtils;
import com.lidroid.xutils.bitmap.BitmapDisplayConfig;
import com.lidroid.xutils.bitmap.callback.BitmapLoadCallBack;
import com.lidroid.xutils.bitmap.callback.BitmapLoadFrom;
import com.lidroid.xutils.util.OtherUtils;
import com.uzmap.pkg.uzcore.UZCoreUtil;
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

	public MapAnnotations(UzAMap uzAMap, AMap aMap, Context context) {
		this.mUzAMap = uzAMap;
		this.mAMap = aMap;
		this.mContext = context;
		this.mAMap.setOnMarkerDragListener(this);
		this.mAMap.setOnMarkerClickListener(this);
		this.mAMap.setInfoWindowAdapter(this);
		this.mAMap.setOnInfoWindowClickListener(this);
	}

	public void addAnnotations(UZModuleContext moduleContext) {
		JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
		List<Annotation> annotations = jsParamsUtil.annotations(moduleContext, mUzAMap);
		if (annotations != null && annotations.size() > 0) {
			for (Annotation annotation : annotations) {
				mAnnotations.put(annotation.getId(), annotation);
				Marker marker = mAMap.addMarker(createMarkerOptions(annotation.getLon(), annotation.getLat(),
						annotation.getIcons(), annotation.getIconsPath(), annotation.isDraggable(),
						(int) (annotation.getTimeInterval() * 50)));

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

	public void removeAnnotations(UZModuleContext moduleContext) {
		JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
		List<String> ids = jsParamsUtil.removeOverlayIds(moduleContext);
		if (ids != null && ids.size() > 0) {
			// for (String id : ids) {
			// Marker marker = mMarkers.get(id);
			// if (marker != null) {
			// marker.destroy();
			// marker.remove();
			// marker.setVisible(false);
			// Toast.makeText(moduleContext.getContext(), "id:" + id + "- isVisible:" +
			// marker.isVisible(), Toast.LENGTH_SHORT).show();
			// mMarkers.remove(id);
			// }
			// }
			for (int i = 0; i < ids.size(); i++) {
				String id = ids.get(i);

				Marker marker = mMarkers.get(id);

				if (marker != null) {
					// Toast.makeText(moduleContext.getContext(), "removeAnnotations-----id:" + id +
					// "- title:" + marker.getTitle(), Toast.LENGTH_LONG).show();
					marker.setAlpha(0);
					marker.destroy();
					marker.remove();
					// marker.setVisible(false);
					// Log.e("TAG", "=========removeAnnotations==================");
					// Log.e("TAG", "removeAnnotations-----id:" + id + "- title:" +
					// marker.getTitle());
					// Log.e("TAG", "=========removeAnnotations==================");
					mMarkers.remove(id);
					marker = null;
				}
			}
		} else {
			mAMap.clear();
		}

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
				mAMap.moveCamera(CameraUpdateFactory.newLatLngZoom(centerLatLng, mAMap.getCameraPosition().zoom));
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
			// Log.e("TAG", "===========addBillboard======================");
			// Log.e("TAG", "addBillboard --- id:" + bubble.getId() + "- title:" +
			// bubble.getTitle());
			// Toast.makeText(moduleContext.getContext(), "addBillboard --- id:" +
			// bubble.getId() + "- title:" + bubble.getTitle(), Toast.LENGTH_LONG).show();;
			// Log.e("TAG", "===========addBillboard======================");
			String iconPath = bubble.getIconPath();
			String illusAlign = bubble.getIllusAlign();
			int layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_left");
			if (illusAlign == null || !illusAlign.equals("left")) {
				layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_right");
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
			Bitmap bgImg = bubble.getBgImg();
			if (bgImg != null) {
				infoContent.setBackgroundDrawable(new BitmapDrawable(bgImg));
				// infoContent.setBackground(background);
				// infoContent.setBackgroundResource(UZResourcesIDFinder.getResDrawableID("paopao"));
			}
			infoContent.setLayoutParams(new ViewGroup.LayoutParams(width, height));
			TextView titleView = (TextView) infoContent.findViewById(UZResourcesIDFinder.getResIdID("title"));
			LinearLayout.LayoutParams textViewParaT = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
					ViewGroup.LayoutParams.WRAP_CONTENT);
			textViewParaT.topMargin = titleMarginT;
			textViewParaT.rightMargin = UZUtility.dipToPix(5);
			titleView.setLayoutParams(textViewParaT);
			if (bubble.getTitle() == null)
				titleView.setVisibility(View.GONE);// 如果标题是null 就隐藏
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
			LinearLayout.LayoutParams textViewParaB = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
					ViewGroup.LayoutParams.MATCH_PARENT);
			textViewParaB.bottomMargin = titleMarginB;
			textViewParaB.rightMargin = UZUtility.dipToPix(5);
			subTitleView.setLayoutParams(textViewParaB);
			if (bubble.getSubTitle() == null)
				subTitleView.setVisibility(View.GONE);// 如果标题是null 就隐藏
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
			if (iconPath == null) {
				iconView.setVisibility(View.GONE);
			} else {
				if (iconPath.startsWith("http")) {
					billboard.setView(infoContent);
					getImgShowUtil().display(iconView, bubble.getIconPath(), getLoadCallBack(bubble.getId()));
				} else {
					// iconView.setBackgroundDrawable(new
					// BitmapDrawable(jsParamsUtil.getBitmap(mUzAMap.makeRealPath(bubble.getIconPath()))));
					// iconView.setImageBitmap(bm);
					getImgShowUtil().display(iconView, bubble.getIconPath());
					Marker marker = mAMap.addMarker(createBillboardOptions(lon, lat, infoContent, draggable, id));
					billboard.setMarker(marker);
					if (!mMarkers.containsKey(bubble.getId())) {
						mMarkers.put(bubble.getId(), marker);
					}
					mBillboardMap.put(marker, billboard);
				}
			}
		}

	}

	private BitmapLoadCallBack<View> getLoadCallBack(final String id) {
		return new BitmapLoadCallBack<View>() {
			@Override
			public void onLoadCompleted(View container, String uri, Bitmap bitmap, BitmapDisplayConfig displayConfig,
					BitmapLoadFrom from) {
				((ImageView) container).setImageBitmap(bitmap);
				Billboard billboard = mBillboards.get(id);
				if (billboard != null) {
					Marker marker = mAMap.addMarker(createBillboardOptions(billboard.getLon(), billboard.getLat(),
							billboard.getView(), billboard.isDraggable(), id));
					billboard.setMarker(marker);
					mMarkers.put(id, marker);
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
			boolean draggable, int period) {
		MarkerOptions markerOptions = new MarkerOptions();
		if (icons != null && icons.size() > 0) {
			ArrayList<BitmapDescriptor> giflist = new ArrayList<BitmapDescriptor>();
			BitmapDescriptor bitmapDescriptor = null;
			JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
			for (String icon : iconsPath) {
				if (icon != null) {
					bitmapDescriptor = BitmapDescriptorFactory.fromBitmap(jsParamsUtil.getBitmap(icon));
					giflist.add(bitmapDescriptor);
				}
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

	@Override
	public boolean onMarkerClick(Marker marker) {
		Object bubble = mMarkerBubbleMap.get(marker);
		if (bubble instanceof Bubble) {
			setWebBubbleUrl = false;
		}else {
			setWebBubbleUrl = true;
		}
		marker.showInfoWindow();
		Annotation annotation = mMarkerAnnoMap.get(marker);
		if (annotation != null) {
			CallBackUtil.markerClickCallBack(annotation.getModuleContext(), annotation.getId());
			return true;
		}
		Billboard billboard = mBillboardMap.get(marker);
		if (billboard != null) {
			CallBackUtil.markerClickCallBack(billboard.getModuleContext(), billboard.getId());
			return true;
		}
		return true;
	}

	@Override
	public void onInfoWindowClick(Marker marker) {
		marker.showInfoWindow();
	}

	@Override
	public View getInfoContents(Marker marker) {
		View infoContent = null;
		// if(setWebBubbleUrl){
		// final UZModuleContext moduleContext = (UZModuleContext)
		// mMarkerBubbleMap.get(marker);
		// int layoutId = UZResourcesIDFinder
		// .getResLayoutID("mo_amap_bubble_webview");
		// infoContent = View.inflate(mContext, layoutId, null);
		// int width = 50;
		// int hight = 50;
		// String bg = moduleContext.optString("bg","#FFFFFF");
		// if(UZUtility.isHtmlColor(bg)){
		// infoContent.setBackgroundColor(UZUtility.parseCssColor(bg));
		// }else{
		// Bitmap bitmap =
		// JsParamsUtil.getInstance().getBitmap(mUzAMap.makeRealPath(bg));
		// infoContent.setBackgroundDrawable(new BitmapDrawable(bitmap));
		// }
		// JSONObject size = moduleContext.optJSONObject("size");
		// if(size != null && !moduleContext.isNull("size")){
		// width = size.optInt("width",50);
		// hight = size.optInt("height",50);
		// }
		// infoContent.setLayoutParams(new LayoutParams(
		// UZUtility.dipToPix(width), UZUtility.dipToPix(hight)));
		// WebView webView = (WebView) infoContent
		// .findViewById(UZResourcesIDFinder.getResIdID("mo_amap_bubble_webview"));
		// webView.setBackgroundColor(0x00000000);
		// String url = moduleContext.makeRealPath(moduleContext.optString("url"));
		// //这里需要判断url是否/绝对路径开头，如果是，则加上file://
		// if(url!=null && url.startsWith("/"))
		// url = "file://"+url;
		// if(moduleContext.isNull("data")){//如果data是空就加载网页
		// webView.loadUrl(url);
		// webView.setWebViewClient(new WebViewClient(){
		// @Override
		// public boolean shouldOverrideUrlLoading(WebView view, String url) {
		// return false;}});
		// }else{//否则就加载data数据的片段
		// String data = moduleContext.optString("data","data parameter is nothing");
		// webView.getSettings().setJavaScriptEnabled(true);
		// webView.getSettings().setDefaultTextEncodingName("utf-8");
		// webView.loadDataWithBaseURL(url, data, "text/html", "utf-8", null);//TODO
		// }
		//
		// }else{
		// final Bubble bubble = (Bubble)mMarkerBubbleMap.get(marker);
		// if (bubble == null)
		// return null;
		// Log.e("TAG", "=============getInfoWindow======================");
		// Log.e("TAG", bubble.getId());
		// Log.e("TAG", "=============getInfoWindow======================");
		// String illusAlign = bubble.getIllusAlign();
		// int layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_left");
		// //int layoutId = UZResourcesIDFinder.getResLayoutID("bubble_left");
		// if (illusAlign == null || !illusAlign.equals("left")) {
		// layoutId = UZResourcesIDFinder
		// .getResLayoutID("mo_amap_bubble_right");
		// }
		// infoContent = View.inflate(mContext, layoutId, null);
		// LinearLayout linearLayout =
		// (LinearLayout)infoContent.findViewById(UZResourcesIDFinder.getResIdID("ll"));
		// Bitmap bgImg = bubble.getBgImg();
		// if (bgImg != null) {
		// //infoContent.setLayoutParams(new
		// LayoutParams(UZCoreUtil.dipToPix(bgImg.getWidth()),
		// UZCoreUtil.dipToPix(bgImg.getHeight())));
		// infoContent.setBackgroundDrawable(new BitmapDrawable(bgImg));
		//
		// int height = bgImg.getHeight();
		//// int w = bgImg.getWidth();
		// linearLayout.setLayoutParams(new
		// RelativeLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, height));
		// } else {
		// infoContent.setBackgroundResource(UZResourcesIDFinder.getResDrawableID("mo_amap_custom_info_bubble"));
		// //infoContent.setLayoutParams(new LayoutParams(LayoutParams.WRAP_CONTENT,
		// UZUtility.dipToPix(90)));
		// }
		// ImageView iconView = (ImageView) infoContent
		// .findViewById(UZResourcesIDFinder.getResIdID("icon"));
		// iconView.setOnClickListener(new OnClickListener() {
		//
		// @Override
		// public void onClick(View v) {
		// CallBackUtil.infoWindowClickCallBack(bubble.getModuleContext(),
		// bubble.getId(), "clickIllus");
		// }
		// });
		// if (bubble.getIconPath() != null
		// && bubble.getIconPath().startsWith("http")) {
		// getImgShowUtil().display(iconView, bubble.getIconPath(),
		// getLoadCallBack(bubble.getId()));
		// } else {
		// JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
		// iconView.setBackgroundDrawable(new BitmapDrawable(jsParamsUtil
		// .getBitmap(mUzAMap.makeRealPath(bubble.getIconPath()))));
		// }
		// if (bubble.getIconPath() == null || bubble.getIconPath().isEmpty()) {
		// iconView.setVisibility(View.GONE);
		// }
		//
		// TextView titleView = (TextView) infoContent
		// .findViewById(UZResourcesIDFinder.getResIdID("title"));
		// titleView.setText(bubble.getTitle());
		// titleView.setTextColor(bubble.getTitleColor());
		// titleView.setTextSize(bubble.getTitleSize());
		//
		// titleView.setOnClickListener(new OnClickListener() {
		//
		// @Override
		// public void onClick(View v) {
		// CallBackUtil.infoWindowClickCallBack(bubble.getModuleContext(),
		// bubble.getId(), "clickContent");
		// }
		// });
		// TextView subTitleView = (TextView) infoContent
		// .findViewById(UZResourcesIDFinder.getResIdID("subTitle"));
		// subTitleView.setText(bubble.getSubTitle());
		// subTitleView.setTextColor(bubble.getSubTitleColor());
		// subTitleView.setTextSize(bubble.getSubTitleSize());
		// subTitleView.setOnClickListener(new OnClickListener() {
		//
		// @Override
		// public void onClick(View v) {
		// CallBackUtil.infoWindowClickCallBack(bubble.getModuleContext(),
		// bubble.getId(), "clickContent");
		// }
		// });
		// if (TextUtils.isEmpty(bubble.getSubTitle())) {
		// subTitleView.setVisibility(View.GONE);
		// }
		// if (bgImg != null) {
		// infoContent.setLayoutParams(new
		// LayoutParams(UZCoreUtil.dipToPix(bgImg.getWidth()),
		// UZCoreUtil.dipToPix(bgImg.getHeight())));
		// }
		// }
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
		if (setWebBubbleUrl) {
			final UZModuleContext moduleContext = (UZModuleContext) mMarkerBubbleMap.get(marker);
			// int layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_webview");
			int layoutId = UZResourcesIDFinder.getResLayoutID("webview");

			infoContent = View.inflate(mContext, layoutId, null);

			RelativeLayout rl = (RelativeLayout) infoContent.findViewById(UZResourcesIDFinder.getResIdID("rl"));
			// rl.setOnClickListener(new OnClickListener() {
			//
			// @Override
			// public void onClick(View view) {
			// try {
			// String id = moduleContext.optString("id");
			// if (UzAMap.webBubbleModuleContext != null) {
			// JSONObject result = new JSONObject();
			// result.put("id", id);
			// UzAMap.webBubbleModuleContext.success(result, false);
			// }
			// } catch (JSONException e) {
			// // TODO: handle exception
			// }
			//
			// }
			// });
			int width = 50;
			int hight = 50;
			String bg = moduleContext.optString("bg", "#FFFFFF");

			if (UZUtility.isHtmlColor(bg)) {
				// infoContent.setBackgroundColor(UZUtility.parseCssColor(bg));
				rl.setBackgroundColor(UZUtility.parseCssColor(bg));
			} else {
				Bitmap bitmap = JsParamsUtil.getInstance().getBitmap(mUzAMap.makeRealPath(bg));
				infoContent.setBackgroundDrawable(new BitmapDrawable(bitmap));
			}
			JSONObject size = moduleContext.optJSONObject("size");
			if (size != null && !moduleContext.isNull("size")) {
				width = size.optInt("width", 50);
				hight = size.optInt("height", 50);
			}
			// infoContent.setLayoutParams(new LayoutParams(UZUtility.dipToPix(width),
			// UZUtility.dipToPix(hight)));
			rl.setLayoutParams(new RelativeLayout.LayoutParams(UZUtility.dipToPix(width), UZUtility.dipToPix(hight)));

			WebView webView = (WebView) infoContent
					.findViewById(UZResourcesIDFinder.getResIdID("mo_amap_bubble_webview"));
			
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
//					switch (event.getAction()) {
//					case MotionEvent.ACTION_DOWN:
//						
//						break;
//
//					default:
//						break;
//					}
					
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

				// String body="<img
				// src=\"http://img03.3dmgame.com/uploads/allimg/141115/271_141115025804_1_lit.jpg\"/>";
				// String html="<html><body>"+body+"</body></html>";
				// webView.loadDataWithBaseURL("http://www.3dmgame.com/", html,
				// "text/html","UTF-8", null);

				webView.loadDataWithBaseURL(url, data, "text/html", "utf-8", null);// TODO
				// webView.loadUrl(url);
				// webView.setWebViewClient(new WebViewClient() {
				// @Override
				// public boolean shouldOverrideUrlLoading(WebView view, String url) {
				// Log.e("TAG", url);
				// return super.shouldOverrideUrlLoading(view, url);
				// }
				// });
			}

		} else {
			final Bubble bubble = (Bubble) mMarkerBubbleMap.get(marker);
			if (bubble == null)
				return null;
			// Log.e("TAG", "=============getInfoWindow======================");
			// Log.e("TAG", bubble.getId());
			// Log.e("TAG", "=============getInfoWindow======================");
			String illusAlign = bubble.getIllusAlign();
			int layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_left");
			// int layoutId = UZResourcesIDFinder.getResLayoutID("bubble_left");
			if (illusAlign == null || !illusAlign.equals("left")) {
				layoutId = UZResourcesIDFinder.getResLayoutID("mo_amap_bubble_right");
			}
			infoContent = View.inflate(mContext, layoutId, null);
			// RelativeLayout rLayout = (RelativeLayout)
			// infoContent.findViewById(UZResourcesIDFinder.getResIdID("rl"));
			LinearLayout linearLayout = (LinearLayout) infoContent.findViewById(UZResourcesIDFinder.getResIdID("ll"));
			linearLayout.setPadding(5, 5, 5, 5);
			Bitmap bgImg = bubble.getBgImg();
			if (bgImg != null) {
				infoContent.setBackgroundDrawable(new BitmapDrawable(bgImg));

				int height = bgImg.getHeight();
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
			iconView.setOnClickListener(new OnClickListener() {

				@Override
				public void onClick(View v) {
					CallBackUtil.infoWindowClickCallBack(bubble.getModuleContext(), bubble.getId(), "clickIllus");
				}
			});
			if (bubble.getIconPath() != null && bubble.getIconPath().startsWith("http")) {
				getImgShowUtil().display(iconView, bubble.getIconPath(), getLoadCallBack(bubble.getId()));
			} else {
				JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
				iconView.setBackgroundDrawable(
						new BitmapDrawable(jsParamsUtil.getBitmap(mUzAMap.makeRealPath(bubble.getIconPath()))));
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
		}
		return infoContent;
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

	// public BitmapDrawable (String path) throws IOException {
	// //打开文件
	// File file = new File(path);
	// if(!file.exists())
	// {
	// return null;
	// }
	//
	// ByteArrayOutputStream outStream = new ByteArrayOutputStream();
	// byte[] bt = new byte[BUFFER_SIZE];
	//
	// //得到文件的输入流
	// InputStream in = new FileInputStream(file);
	//
	// //将文件读出到输出流中
	// int readLength = in.read(bt);
	// while (readLength != -1) {
	// outStream.write(bt, 0, readLength);
	// readLength = in.read(bt);
	// }
	//
	// //转换成byte 后 再格式化成位图
	// byte[] data = outStream.toByteArray();
	// Bitmap bitmap = BitmapFactory.decodeByteArray(data, 0, data.length);// 生成位图
	// BitmapDrawable bd = new BitmapDrawable(bitmap);
	//
	// return bd;
	// }

}
