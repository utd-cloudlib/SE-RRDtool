package com.ncss.serrdtool;

import java.io.Serializable;

import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;
import javax.xml.bind.annotation.XmlTransient;

@XmlRootElement(name = "meta")
public class Meta implements Serializable{
	private static final long serialVersionUID = 1L;
	
	public String handle;
	public String path;
	public String DSName;
	public String CF;
	public String quantitativeDefinition;
	public String metricName;
	public String unitName;
	public String unit;
	public String entityType;
	public String entity;
	public long startTime;
	public long endTime;
	public int rows;
	public int step;
	
	public Meta() {}
	
	public Meta(String handle, String path, String quantitativeDefinition) {
		this.handle = handle;
		this.path = path;
		this.quantitativeDefinition = quantitativeDefinition;
	}
	
	public Meta(String handle,String path, String DSName, String CF, String quantitativeDefinition,  String metricName, String unitName, String unit, String entityType, String entity, long startTime, long endTime, int rows, int step) {
		this.handle = handle;
		this.path = path;
		this.DSName = DSName;
		this.CF = CF;
		this.quantitativeDefinition = quantitativeDefinition;
		this.metricName = metricName;
		this.unitName = unitName;
		this.unit = unit;
		this.entityType = entityType;
		this.entity = entity;
		this.startTime = startTime;
		this.endTime = endTime;
		this.rows = rows;
		this.step = step;
	}
	
	public void printMeta() {
		System.out.println(" ---------- Printing meta: ---------- ");
		System.out.println("    (handle " + this.handle + ")\n");
		System.out.println("    (path " + this.path + ")\n");
		System.out.println("    (DSName " + this.DSName + ")\n");
		System.out.println("    (CF " + this.CF + ")\n");
		System.out.println("    (quantitativeDefinition " + this.quantitativeDefinition + ")\n");
		System.out.println("    (metricName " + this.metricName + ")\n");
		System.out.println("    (unitName " + this.unitName + ")\n");
		System.out.println("    (unit " + this.unit + ")\n");
		System.out.println("    (entityType " + this.entityType + ")\n");
		System.out.println("    (entity " + this.entity + ")\n");
		System.out.println("    (startTime " + this.startTime + ")\n");
		System.out.println("    (endTime " + this.endTime + ")\n");
		System.out.println("    (rows " + this.rows + ")\n");
		System.out.println("    (step " + this.step + ")\n");
	}
	
	public String getHandle() {
		return this.handle;
	}
	//@XmlElement
	public void setHandle(String h) {
		this.handle = h;
	}
	
	public String getPath() {
		return this.path;
	}
	//@XmlElement
	public void setPath(String p) {
		this.path = p;
	}
	
	public String getDSName() {
		return this.DSName;
	}
	//@XmlElement
	public void setDSName(String d) {
		this.DSName = d;
	}
	
	public String getCF() {
		return this.CF;
	}
	//@XmlElement
	public void setCF(String c) {
		this.CF = c;
	}
	
	public String getQuantitativeDefinition() {
		return this.quantitativeDefinition;
	}
	//@XmlElement
	public void setQuantitativeDefinition(String d) {
		this.quantitativeDefinition = d;
	}
	
	public String getMetricName() {
		return this.metricName;
	}
	//@XmlElement
	public void setMetricname(String metric) {
		this.metricName = metric;
	}
	
	public String getUnitName() {
		return this.unitName;
	}
	//@XmlElement
	public void setUnitName(String unit) {
		this.unitName = unit;
	}
	
	public String getUnit() {
		return this.unit;
	}
	//@XmlElement
	public void setUnit(String u) {
		this.unit = u;
	}
	
	public String getEntityType() {
		return this.entityType;
	}
	//@XmlElement
	public void setEntityType(String entity) {
		this.entityType = entity;
	}
	
	public String getEntity() {
		return this.entity;
	}
	//@XmlElement
	public void setEntity(String e) {
		this.entity = e;
	}
	
	public String getStartTime() {
		return String.valueOf(this.startTime);
	}
	//@XmlElement
	public void setStartTime(long s) {
		this.startTime = s;
	}
	
	public String getEndTime() {
		return String.valueOf(this.endTime);
	}
	//@XmlElement
	public void setEndTime(long e) {
		this.endTime = e;
	}
	
	public String getRows() {
		return String.valueOf(this.rows);
	}
	//@XmlElement
	public void setRows(int r) {
		this.rows = r;
	}
	
	public String getStep() {
		return String.valueOf(this.step);
	}
	//@XmlElement
	public void setStep(int s) {
		this.step = s;
	}
	
	@Override
	   public boolean equals(Object object){
	      if(object == null){
	         return false;
	      }else if(!(object instanceof Meta)){
	         return false;
	      }else {
	         Meta meta = (Meta)object;
	         if(metricName.equals(meta.getMetricName())
	            && unitName.equals(meta.getUnitName())
	            && entityType.equals(meta.getEntityType())
	         ){
	            return true;
	         }			
	      }
	      return false;
	   }
}

