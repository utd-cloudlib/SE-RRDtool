package com.ncss.serrdtool;

import javax.ws.rs.GET;
import javax.ws.rs.OPTIONS;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.MediaType;

@Path("/WebService")
public class WebService {
	MetaAccess metaAccess = new MetaAccess();
	private static final String SUCCESS_RESULT="<result>success</result>";
	private static final String FAILURE_RESULT="<result>failure</result>";
	
	// functions for: create, update, graph, dump, restore, fetch, tune, xport, updatev, graphv, last, lastupdate, first, info, resize, flushcached
	
	@GET
	@Path("/metas/{handle}")
	@Produces(MediaType.APPLICATION_XML)
	public String getPath(@PathParam("handle") String handle) {
		return metaAccess.getPath(handle);
	}
	
	@GET
	@Path("/metas")
	@Produces(MediaType.APPLICATION_JSON)
	//@Produces("application/json")
	public Meta getQuery(@QueryParam("metricName") String metricName,@QueryParam("DSName") String DSName, @QueryParam("CF") String CF,
			@QueryParam("unitName") String unitName, @QueryParam("unit") String unit,
			@QueryParam("entityType") String entityType, @QueryParam("entity") String entity,
			@QueryParam("startTime") String startTime, @QueryParam("endTime") String endTime,
			@QueryParam("rows") String rows, @QueryParam("step") String step) {
		return metaAccess.getQuery(metricName, DSName,CF, unitName, unit, entityType, entity, startTime, endTime, rows, step);
	}
	
	/*
	@GET
	@Path("/metas")
	@Produces(MediaType.APPLICATION_JSON)
	//@Produces("application/json")
	public Meta getQuery(@QueryParam("metricName") String metricName, @QueryParam("unitName") String unitName) {
		//System.out.println("Query by String.");
		Meta m = metaAccess.getQuery(metricName, unitName);
		
		if(m != null) {
			//System.out.println(m.getHandle());
		}
		
		return m;
	}
	*/
	
	@OPTIONS
	@Path("/metas")
	@Produces(MediaType.APPLICATION_XML)
	public String getSupportedOperations(){
	   return "<operations>GET, PUT, POST, DELETE</operations>";
	}
	
}
