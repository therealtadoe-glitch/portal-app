@tool
class_name BottomNavigation
extends HBoxContainer

var _tabs: Array[Button] = []

@export var tabs_meta: Dictionary = {
	"dash_meta" : {
		"id" : "btn_dash",
		"page" : "Dashboard",
		"icon" : preload("res://assets/icons/interface-dashboard-layout-3--app-application-dashboard-home-layout--Streamline-Core.svg")
		},
	"jobs_meta" : {
		"id" : "btn_jobs",
		"page" : "Jobs",
		"icon" : preload("res://assets/icons/interface-dashboard-layout-3--app-application-dashboard-home-layout--Streamline-Core.svg")
		},
	"clock_meta" : {
		"id" : "btn_clock",
		"page" : "Clock",
		"icon" : preload("res://assets/icons/interface-dashboard-layout-3--app-application-dashboard-home-layout--Streamline-Core.svg")
		},
	"alerts_meta" : {
		"id" : "btn_alerts",
		"page" : "Alerts",
		"icon" : preload("res://assets/icons/interface-dashboard-layout-3--app-application-dashboard-home-layout--Streamline-Core.svg")
		},
	"more_meta" : {
		"id" : "btn_more",
		"page" : "More",
		"icon" : preload("res://assets/icons/interface-dashboard-layout-3--app-application-dashboard-home-layout--Streamline-Core.svg")
		},}

@export var pages: Array[Texture2D] = [preload("res://assets/icons/interface-dashboard-layout-3--app-application-dashboard-home-layout--Streamline-Core.svg"), preload("res://assets/icons/interface-setting-wrench--crescent-tool-construction-tools-wrench-setting-edit-adjust--Streamline-Core.svg"), preload()]
