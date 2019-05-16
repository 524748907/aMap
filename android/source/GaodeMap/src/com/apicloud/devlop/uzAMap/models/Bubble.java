//
//UZModule
//
//Modified by magic 16/2/23.
//Copyright (c) 2016年 APICloud. All rights reserved.
//
package com.apicloud.devlop.uzAMap.models;

import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import com.uzmap.pkg.uzkit.UZUtility;

import android.R.integer;
import android.graphics.Bitmap;

public class Bubble {
	private String id;
	private Bitmap bgImg;
	private String title;
	private String subTitle;
	private String iconPath;
	private int titleSize;
	private int subTitleSize;
	private String illusAlign;
	private int titleColor;
	private int subTitleColor;
	private UZModuleContext moduleContext;
	
	private String billboard_selected_bgImg;
	private int billboard_selected_titleColor;
	private int billboard_selected_subTitleColor;
	private String billboard_selected_illus;
	private String billboard_bgImg;
	private int width;
	private int height;
	
	private int titleMarginT = UZUtility.dipToPix(10);
	private int titleMarginB = UZUtility.dipToPix(10);
	private int titleMaxLines = 1;
	private int subTitleMaxLines = 1;
	private int titleMarginLeft = UZUtility.dipToPix(10);
	private int titleMarginRight = UZUtility.dipToPix(10);
	private int subMarginLeft = UZUtility.dipToPix(10);
	private int subMarginRight = UZUtility.dipToPix(10);
	
	private int imgX,imgY,imgW,ImgH;
	

	public Bubble() {
	}

	public Bubble(String id, Bitmap bgImg, String title, String subTitle,
			String iconPath, int titleSize, int subTitleSize,
			String illusAlign, int titleColor, int subTitleColor, int w, int h,
			UZModuleContext moduleContext) {
		this.id = id;
		this.bgImg = bgImg;
		this.title = title;
		this.subTitle = subTitle;
		this.iconPath = iconPath;
		this.titleSize = titleSize;
		this.subTitleSize = subTitleSize;
		this.illusAlign = illusAlign;
		this.titleColor = titleColor;
		this.subTitleColor = subTitleColor;
		this.width = w;
		this.height = h;
		this.moduleContext = moduleContext;
	}
	
	

	public int getImgX() {
		return imgX;
	}

	public void setImgX(int imgX) {
		this.imgX = imgX;
	}

	public int getImgY() {
		return imgY;
	}

	public void setImgY(int imgY) {
		this.imgY = imgY;
	}

	public int getImgW() {
		return imgW;
	}

	public void setImgW(int imgW) {
		this.imgW = imgW;
	}

	public int getImgH() {
		return ImgH;
	}

	public void setImgH(int imgH) {
		ImgH = imgH;
	}

	public void setWidth(int width) {
		this.width = width;
	}

	public void setHeight(int height) {
		this.height = height;
	}

	public int getTitleMarginT() {
		return titleMarginT;
	}

	public void setTitleMarginT(int titleMarginT) {
		this.titleMarginT = titleMarginT;
	}

	public int getTitleMarginB() {
		return titleMarginB;
	}

	public void setTitleMarginB(int titleMarginB) {
		this.titleMarginB = titleMarginB;
	}

	public int getTitleMaxLines() {
		return titleMaxLines;
	}

	public void setTitleMaxLines(int titleMaxLines) {
		this.titleMaxLines = titleMaxLines;
	}

	public int getSubTitleMaxLines() {
		return subTitleMaxLines;
	}

	public void setSubTitleMaxLines(int subTitleMaxLines) {
		this.subTitleMaxLines = subTitleMaxLines;
	}

	public int getTitleMarginLeft() {
		return titleMarginLeft;
	}

	public void setTitleMarginLeft(int titleMarginLeft) {
		this.titleMarginLeft = titleMarginLeft;
	}

	public int getTitleMarginRight() {
		return titleMarginRight;
	}

	public void setTitleMarginRight(int titleMarginRight) {
		this.titleMarginRight = titleMarginRight;
	}

	public int getSubMarginLeft() {
		return subMarginLeft;
	}

	public void setSubMarginLeft(int subMarginLeft) {
		this.subMarginLeft = subMarginLeft;
	}

	public int getSubMarginRight() {
		return subMarginRight;
	}

	public void setSubMarginRight(int subMarginRight) {
		this.subMarginRight = subMarginRight;
	}

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public Bitmap getBgImg() {
		return bgImg;
	}

	public void setBgImg(Bitmap bgImg) {
		this.bgImg = bgImg;
	}

	public String getTitle() {
		return title;
	}

	public void setTitle(String title) {
		this.title = title;
	}

	public String getSubTitle() {
		return subTitle;
	}

	public void setSubTitle(String subTitle) {
		this.subTitle = subTitle;
	}

	public String getIconPath() {
		return iconPath;
	}

	public void setIconPath(String iconPath) {
		this.iconPath = iconPath;
	}

	public int getTitleSize() {
		return titleSize;
	}

	public void setTitleSize(int titleSize) {
		this.titleSize = titleSize;
	}

	public int getSubTitleSize() {
		return subTitleSize;
	}

	public void setSubTitleSize(int subTitleSize) {
		this.subTitleSize = subTitleSize;
	}

	public String getIllusAlign() {
		return illusAlign;
	}

	public void setIllusAlign(String illusAlign) {
		this.illusAlign = illusAlign;
	}

	public int getTitleColor() {
		return titleColor;
	}

	public void setTitleColor(int titleColor) {
		this.titleColor = titleColor;
	}

	public int getSubTitleColor() {
		return subTitleColor;
	}

	public void setSubTitleColor(int subTitleColor) {
		this.subTitleColor = subTitleColor;
	}

	public UZModuleContext getModuleContext() {
		return moduleContext;
	}

	public void setModuleContext(UZModuleContext moduleContext) {
		this.moduleContext = moduleContext;
	}

	public String getBillboard_selected_bgImg() {
		return billboard_selected_bgImg;
	}

	public void setBillboard_selected_bgImg(String billboard_selected_bgImg) {
		this.billboard_selected_bgImg = billboard_selected_bgImg;
	}

	public int getBillboard_selected_titleColor() {
		return billboard_selected_titleColor;
	}

	public void setBillboard_selected_titleColor(int billboard_selected_titleColor) {
		this.billboard_selected_titleColor = billboard_selected_titleColor;
	}

	public int getBillboard_selected_subTitleColor() {
		return billboard_selected_subTitleColor;
	}

	public void setBillboard_selected_subTitleColor(int billboard_selected_subTitleColor) {
		this.billboard_selected_subTitleColor = billboard_selected_subTitleColor;
	}

	public String getBillboard_selected_illus() {
		return billboard_selected_illus;
	}

	public void setBillboard_selected_illus(String billboard_selected_illus) {
		this.billboard_selected_illus = billboard_selected_illus;
	}

	public String getBillboard_bgImg() {
		return billboard_bgImg;
	}

	public void setBillboard_bgImg(String billboard_bgImg) {
		this.billboard_bgImg = billboard_bgImg;
	}
	
	public int getWidth() {
		return width;
	}
	
	public int getHeight() {
		return height;
	}
	
	
}
