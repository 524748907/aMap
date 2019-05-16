package com.apicloud.devlop.uzAMap;

import java.util.ArrayList;
import java.util.List;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.graphics.Bitmap;
import android.graphics.Color;
import android.util.Log;
import android.widget.Toast;

import com.amap.api.maps.AMap;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.PolylineOptions;
import com.amap.api.services.core.LatLonPoint;
import com.amap.api.services.district.DistrictItem;
import com.amap.api.services.district.DistrictResult;
import com.amap.api.services.district.DistrictSearch;
import com.amap.api.services.district.DistrictSearchQuery;
import com.amap.api.services.district.DistrictSearch.OnDistrictSearchListener;
import com.apicloud.devlop.uzAMap.utils.JsParamsUtil;
import com.uzmap.pkg.uzcore.uzmodule.UZModule;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

public class MapDistrictSearch implements OnDistrictSearchListener{

	private AMap mAMap;
	private UZModuleContext mModuleContext;

	public MapDistrictSearch(UZModule uzModule,AMap amap ,UZModuleContext moduleContext) {
		this.mAMap = amap;
		this.mModuleContext = moduleContext;

		if(mAMap != null)
			mAMap.clear();
		DistrictSearch search = new DistrictSearch(moduleContext.getContext());
		DistrictSearchQuery query = new DistrictSearchQuery( );
 		query.setKeywords(moduleContext.optString("keyword",""));//传入关键字
		query.setShowBoundary(true);//是否返回边界值
		query.setKeywordsLevel("country");//设置区域级别
		search.setQuery(query);

		search.setOnDistrictSearchListener(this);//绑定监听器

		search.searchDistrictAsyn();//开始搜索
	}
	
	/**
	 * 返回District（行政区划）异步处理的结果
	 */
	@Override
	public void onDistrictSearched(final DistrictResult districtResult) {
		if (districtResult == null || districtResult.getDistrict()==null) {
			return;
		}
		
		if(districtResult.getDistrict().size() < 1){
			districtSearchCallback(false, "当前无返回信息，请检查keyword字段是否正确。",-1);
		}
		
		//通过ErrorCode判断是否成功
		if(districtResult.getAMapException() != null && 
				districtResult.getAMapException().getErrorCode() == 1000) {//AMapException.CODE_AMAP_SUCCESS = 1000\

			new Thread() {
				public void run() {
					try {
						districtSearchCallback(true, districtResultToJson(districtResult) ,0);
					} catch (JSONException e) {
						districtSearchCallback(false,"区域数据转换错误"+e.getMessage(),-2);
						e.printStackTrace();
					}}
			}.start();
			
			if(mAMap == null)
				return;


			if(mModuleContext.isNull("showInMap")){
				return;
			}
			
			final DistrictItem item = districtResult.getDistrict().get(0);

			if (item == null) 
				return;

			LatLonPoint centerLatLng = item.getCenter();
			if (centerLatLng != null) {
				mAMap.moveCamera(

						CameraUpdateFactory.newLatLngZoom(new LatLng(centerLatLng.getLatitude(), centerLatLng.getLongitude()), 8));
			}

			new Thread() {
				public void run() {

					String[] polyStr = item.districtBoundary();
					if (polyStr == null || polyStr.length == 0) {
						return;
					}
					for (String str : polyStr) {
						String[] lat = str.split(";");
						PolylineOptions polylineOption = new PolylineOptions();
						boolean isFirst = true;
						LatLng firstLatLng = null;
						for (String latstr : lat) {
							String[] lats = latstr.split(",");
							if (isFirst) {
								isFirst = false;
								firstLatLng = new LatLng(Double
										.parseDouble(lats[1]), Double
										.parseDouble(lats[0]));
							}
							polylineOption.add(new LatLng(Double
									.parseDouble(lats[1]), Double
									.parseDouble(lats[0])));
						}
						if (firstLatLng != null) {
							polylineOption.add(firstLatLng);
						}

						JSONObject showInMap = mModuleContext.optJSONObject("showInMap");
						if(showInMap!=null){
							boolean lineDash = showInMap.optBoolean("lineDash", false);
							int borderColor = UZUtility.parseCssColor(showInMap.optString(
									"borderColor", "#000"));
							double borderWidth = showInMap.optDouble("borderWidth", 2);
							String strokeImgPath = showInMap.optString("strokeImg");
							JsParamsUtil jsParamsUtil = JsParamsUtil.getInstance();
							Bitmap strokeImg = jsParamsUtil.getBitmap(mModuleContext
									.makeRealPath(strokeImgPath), -1, -1);
							polylineOption.setCustomTexture(BitmapDescriptorFactory
									.fromBitmap(strokeImg));
							polylineOption.width((float) borderWidth).color(borderColor);
							polylineOption.setDottedLine(lineDash);
						}else{
							polylineOption.width(10).color(Color.BLUE);
						}
						mAMap.addPolyline(polylineOption);
					}
				}
			}.start();
		} else {
			int errCode = -1;
			String errMsg = "";
			if(districtResult.getAMapException() != null){
				errCode = districtResult.getAMapException().getErrorCode();
				errMsg = districtResult.getAMapException().getErrorMessage();
			}
			districtSearchCallback(false, errMsg, errCode);
		}

	}
	
	private JSONObject districtResultToJson(DistrictResult districtResult) throws JSONException{
		JSONObject districtResultObj  = new JSONObject();//最外层
		districtResultObj.put("count", districtResult.getPageCount());//getDistrict().size());
		JSONArray districtsArray = recursiveInvoke(districtResult.getDistrict());
		districtResultObj.put("districts", districtsArray);
		return districtResultObj;
	}

	/**
	 * @param districts
	 * @return
	 * @throws JSONException
	 * @see 递归解析字典内容
	 */
	private JSONArray recursiveInvoke(List<DistrictItem> districts) throws JSONException {
		JSONArray districtsArray = new JSONArray();//区域数组的jsonArray
//		ArrayList<DistrictItem> districts = districtResult.getDistrict();//区域数组
		for(DistrictItem item :districts){
			JSONObject itemObj = new JSONObject();
			itemObj.put("adcode", item.getAdcode());
			itemObj.put("citycode", item.getCitycode());
			itemObj.put("name", item.getName());
			itemObj.put("level", item.getLevel());
			JSONObject centerObj = new JSONObject();
			centerObj.put("latitude", item.getCenter().getLatitude());
			centerObj.put("longitude", item.getCenter().getLongitude());
			itemObj.put("center", centerObj);
			String[] polylines = item.districtBoundary();
			StringBuilder polylineSB = new StringBuilder("");
			for(String polyline:polylines){
				polylineSB.append(polyline);
			}
			itemObj.put("polylines", polylineSB);
			if(item.getSubDistrict().size()>0){
				itemObj.put("districts", recursiveInvoke(item.getSubDistrict()));// 递归
			}else{
				itemObj.put("districts", "[]");
			}
			districtsArray.put(itemObj);
		}
		return districtsArray;
	}

	public void districtSearchCallback(boolean status,Object districtResult,int errCode){
		if(status){
			try {
				JSONObject retObj = new JSONObject();
				retObj.put("status", status);
				retObj.put("districtResult", districtResult);
				mModuleContext.success(retObj, false);
			} catch (Exception e) {
				e.printStackTrace();
			}
		}else{
			try {
				JSONObject successObj = new JSONObject();
				JSONObject errObj = new JSONObject();
				successObj.put("status", status);
				errObj.put("code", errCode);
				errObj.put("msg", districtResult);
				mModuleContext.error(successObj,errObj, false);
			} catch (Exception e) {
				e.printStackTrace();
			}
		}
	}
}
