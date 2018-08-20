package com.apicloud.devlop.uzAMap.models;

import java.util.List;

import com.amap.api.maps.model.TileOverlay;
import com.amap.api.maps.model.WeightedLatLng;

public class TileOverlayData {
	public TileOverlay tileOverlay;
	public List<WeightedLatLng> latLngs;
	public TileOverlayData(TileOverlay tileOverlay, List<WeightedLatLng> latLngs) {
		this.tileOverlay = tileOverlay;
		this.latLngs = latLngs;
	}
}
