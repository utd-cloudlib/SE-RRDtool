package com.ncss.serrdtool;

public class Config {
	public static String db_host = "localhost";
	public static String db_user = "root";
	public static String db_password = "cloud123";
	
	public static String path = System.getProperty("catalina.home") + "/webapps/SERRDtool/WEB-INF/";
	
	public String getPath() {
		return this.path;
	}
}
