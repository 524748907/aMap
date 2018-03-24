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
import java.util.Map;

import org.json.JSONException;
import org.json.JSONObject;

import com.amap.api.maps.AMap;
import com.amap.api.maps.AMap.OnIndoorBuildingActiveListener;
import com.amap.api.maps.AMap.OnMapScreenShotListener;
import com.amap.api.maps.MapView;
import com.amap.api.maps.model.IndoorBuildingInfo;
import com.amap.api.maps.model.LatLng;
import com.apicloud.devlop.uzAMap.models.MoveAnnotation;
import com.apicloud.devlop.uzAMap.models.MoveOverlay;
import com.apicloud.devlop.uzAMap.utils.JsParamsUtil;
import com.uzmap.pkg.uzcore.UZWebView;
import com.uzmap.pkg.uzcore.uzmodule.UZModule;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

import android.graphics.Bitmap;
import android.graphics.Bitmap.CompressFormat;
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
		mMap.openMap(this, moduleContext, mContext);
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
		mLocation.getLocation(moduleContext, mContext);
	}

	public void jsmethod_stopLocation(UZModuleContext moduleContext) {
		if (mLocation != null) {
			mLocation.stopLocation();
		}
	}

	public void jsmethod_getCoordsFromName(UZModuleContext moduleContext) {
		new MapCoordsAddress().getLocationFromName(moduleContext, mContext);
	}

	public void jsmethod_getNameFromCoords(UZModuleContext moduleContext) {
		new MapCoordsAddress().getNameFromLocation(moduleContext, mContext);
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
					moduleContext, mContext);
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
				//Toast.makeText(mContext, "当前的缩放级别是" + zoom + "-----要缩放的级别是" + String.valueOf(zoomLevel), Toast.LENGTH_LONG).show();
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
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView.getMap(), mContext);
				}
				mAnnotations.addAnnotations(moduleContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(), mContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(),
							mContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(),
							mContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(),
							mContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(),
							mContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(),
							mContext);
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

	public void jsmethod_popupBubble(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mAnnotations == null) {
					mAnnotations = new MapAnnotations(this, mapView.getMap(),
							mContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(),
							mContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(), mContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(),
							mContext);
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
					mAnnotations = new MapAnnotations(this, mapView.getMap(),
							mContext);
				}
				mAnnotations.removeAnnotations(moduleContext);
			}
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

	public void jsmethod_searchRoute(UZModuleContext moduleContext) {
		if (mSearch == null) {
			mSearch = new MapSearch(mContext);
		}
		mSearch.searchRoute(moduleContext);
	}

	public void jsmethod_drawRoute(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mSearch == null) {
					mSearch = new MapSearch(mContext);
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
					mSearch = new MapSearch(mContext);
				}
				mSearch.removeRoute(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_searchBusRoute(UZModuleContext moduleContext) {
		if (mBusLine == null) {
			mBusLine = new MapBusLine(mContext);
		}
		mBusLine.searchBusLine(moduleContext);
	}

	public void jsmethod_drawBusRoute(UZModuleContext moduleContext) {
		if (mMap != null) {
			UzMapView mapView = mMap.getMapView();
			if (mapView != null) {
				if (mBusLine == null) {
					mBusLine = new MapBusLine(mContext);
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
					mBusLine = new MapBusLine(mContext);
				}
				mBusLine.removeRoute(moduleContext, mapView.getMap());
			}
		}
	}

	public void jsmethod_searchInCity(UZModuleContext moduleContext) {
		new MapPoi(moduleContext, mContext).searchInCity(moduleContext);
	}

	public void jsmethod_searchNearby(UZModuleContext moduleContext) {
		new MapPoi(moduleContext, mContext).searchNearby(moduleContext);
	}

	public void jsmethod_searchInPolygon(UZModuleContext moduleContext) {
		new MapPoi(moduleContext, mContext).searchBounds(moduleContext);
	}

	public void jsmethod_autocomplete(UZModuleContext moduleContext) {
		new MapPoi(moduleContext, mContext).autoComplete(moduleContext);
	}

	public void jsmethod_getProvinces(UZModuleContext moduleContext) {
		new MapOffline().getProvinces(moduleContext, mContext);
	}

	public void jsmethod_getAllCities(UZModuleContext moduleContext) {
		new MapOffline().getAllCities(moduleContext, mContext);
	}

	public void jsmethod_downloadRegion(UZModuleContext moduleContext) {
		if (mMapOffline == null) {
			mMapOffline = new MapOffline();
		}
		mMapOffline.downloadRegion(moduleContext, mContext);
	}

	public void jsmethod_isDownloading(UZModuleContext moduleContext) {
		if (mMapOffline == null) {
			mMapOffline = new MapOffline();
		}
		mMapOffline.isDownloading(moduleContext, mContext);
	}

	public void jsmethod_pauseDownload(UZModuleContext moduleContext) {
		if (mMapOffline == null) {
			mMapOffline = new MapOffline();
		}
		mMapOffline.pauseDownload(moduleContext, mContext);
	}

	public void jsmethod_cancelAllDownload(UZModuleContext moduleContext) {
		if (mMapOffline == null) {
			mMapOffline = new MapOffline();
		}
		mMapOffline.cancelAllDownload(moduleContext, mContext);
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
