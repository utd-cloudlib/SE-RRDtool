package com.ncss.serrdtool;
/*
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectOutputStream;
*/

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import jess.JessException;
import jess.Rete;

public class MetaAccess {
	private class Query {
		public String metricName;
		public String DSName;
		public String unitName;
		public String unit;
		public String entityType;
		public String entity;
		public long startTime;
		public long endTime;
		public int rows;
		public int step;
		
		public Query(String metric, String DSName, String unitName, String unit, String entityType, String entity, long start, long end) {
			metricName = metric;
			this.DSName = DSName;
			this.unitName = unitName;
			this.unit = unit;
			this.entityType = entityType;
			this.entity = entity;
			startTime = start;
			endTime = end;
			//rows = r;
			//step = s;
		}
	}
	
	static String path = System.getProperty("catalina.home") + "/webapps/SERRDtool/WEB-INF/";
	private Connection conn;
	private Statement stmt;
	
	// ****** method for access *****
	public Meta getQuery(String metricName, String DSName, String unitName, String unit, String entityType, String entity, String startTime, String endTime, String rows, String step) {
		// query processing for create function in rredtool
		Query query = new Query(metricName, DSName,  unitName, unit, entityType, entity, Long.valueOf(startTime), Long.valueOf(endTime));
		Meta m = selectMeta(query);
		if(m != null) {
			return m;
		}
		else {
			runReasoner(query);
		}
			
		return parseQuery();
	}
	
	public Meta getQuery(String metricName, String unitName) {
		Meta m = selectMeta(metricName, unitName);
		//System.out.println(m.getHandle());
		return m;
	}
	
	public String getPath(String handle) {
		// return the path by handle
		String result = "";
		
		result += selectPath(handle);
		return result;
	}
	
	
	// *********** helper functions ************
	
	// ----- helper functions for getQuery ----
	private Meta selectMeta(String m, String u) {
		String handle = "";
		String address = "";
		//System.out.println("metric: " + m +  " - unit: " + u);
		String sql = "SELECT * FROM META WHERE metricName = '" + m + "'" + 
				" AND unitName = '" + u + "'";
		try {
			//System.out.println("Query: " + sql);
			conn = initSQL("jdbc:mysql://","SEMANTICS");
			stmt = conn.createStatement();
			ResultSet rs = stmt.executeQuery(sql);
			if(rs.next()) {
				handle = rs.getString("handle"); 
				System.out.println("Handle: " + handle);
			}
			else {
				return null;
			}
		} catch(SQLException e) {
			e.printStackTrace();
		} finally {
			try {
				if(stmt!=null) {
		            stmt.close();
				}
				if (null != conn) {
					closeSQL(conn);
				}
			} catch(SQLException  e) {
				e.printStackTrace();
			}
		}
						
		//System.out.println("Database created.");
		return new Meta(handle, address,"definition");
	}
	
	private Meta selectMeta(Query q){
		//String handle = "";
		//String address = "";
		//String quantitativeDefinition = "abc";
		Meta m = new Meta();
		
		String sql = "SELECT * FROM META WHERE metricName = \'" + q.metricName + "\'" +
				" AND DSName = \'" + q.DSName + "\'" +
				" AND unitName = \'" + q.unitName + "\'" +
				//" AND unit = \'" + q.unit + "\'" +
				" AND entityType = \'" + q.entityType + "\'" +
				" AND entity = \'" + q.entity + "\'";
		try {
			//System.out.println("Query: " + sql);
			conn = initSQL("jdbc:mysql://","SEMANTICS");
			stmt = conn.createStatement();
			ResultSet rs = stmt.executeQuery(sql);
			if(rs.next()) { // just pick the first queried result
				m.setHandle(rs.getString("handle"));
				//handle = rs.getString("handle"); 
				m.setPath(rs.getString("path"));
				m.setDSName(rs.getString("DSName"));
				m.setCF(rs.getString("CF"));
				m.setQuantitativeDefinition(rs.getString("quantitativeDefinition"));
				//quantitativeDefinition = rs.getString("quantitativeDefinition");
				m.setMetricname(rs.getString("metricName"));
				m.setUnitName(rs.getString("unitName"));
				m.setUnit(rs.getString("unit"));
				m.setEntityType(rs.getString("entityType"));
				m.setEntity(rs.getString("entity"));
				m.setStartTime(Long.valueOf(rs.getString("startTime")));
				m.setEndTime(Long.valueOf(rs.getString("endTime")));
				m.setRows(Integer.valueOf(rs.getString("rows")));
				m.setStep(Integer.valueOf(rs.getString("step")));
				//System.out.println("Handle: " + handle);
			}
			else {
				//System.out.println("No matching.");
				return null;
			}
		} catch(SQLException e) {
			e.printStackTrace();
		} finally {
			try {
				if(stmt!=null) {
		            stmt.close();
				}
				if (null != conn) {
					closeSQL(conn);
				}
			} catch(SQLException  e) {
				e.printStackTrace();
			}
			
			//System.out.println("Database created.");
		}
		m.printMeta();
		return m;
	}
	
	private void generateQuery(Query query) {
		String file = path + "reasoning/input/query2.clp";
		
		try {
			BufferedWriter w = new BufferedWriter(new FileWriter(file));
			
			w.write("(assert\n");
			w.write("  (query\n");
			
			w.write("    (metricName " + query.metricName + ")\n");
			w.write("    (unitName " + query.unitName + ")\n");
			w.write("    (unit " + query.unit + ")\n");
			w.write("    (entityType " + query.entityType + ")\n");
			w.write("    (entity " + query.entity + ")\n");
			w.write("    (startTime " + query.startTime + ")\n");
			w.write("    (endTime " + query.endTime + ")\n");
			w.write("    (rows " + query.rows + ")\n");
			w.write("    (step " + query.step + ")\n");
			
			w.write("  )\n");
			w.write(")\n\n");
			
			w.close();
	      } catch (FileNotFoundException e) {
	         e.printStackTrace();
	      } catch (IOException e) {
	         e.printStackTrace();
	      }
	}

	private void runReasoner(Query query) {
		//Run a Jess program
		Rete engine = new Rete();
			
		String file = path + "reasoner.clp"; 
		try {
			generateQuery(query);
			
			File e = new File(file);
			
			if(e.exists()) {
				engine.batch(file);
			}			
		} catch (JessException e) {
			e.printStackTrace();
		}
		
	}
	
	private Meta parseQuery() {
		// parse the reasoning result for query
		String file = path + "out/out2.txt";
		
		return new Meta();
	}
	
	// ------ helper functions for getpath -----
	private Connection initSQL(String dbURL, String dbName)
	{// init sql connection
		try {
			Class.forName("com.mysql.jdbc.Driver").newInstance();
			if(dbName.equals("")) {
				conn = DriverManager.getConnection(dbURL + Config.db_host, Config.db_user, Config.db_password);
			}
			else {
				conn = DriverManager.getConnection(dbURL + Config.db_host+"/" + dbName, Config.db_user, Config.db_password);
			}
		} catch (InstantiationException | IllegalAccessException e1) {
			e1.printStackTrace();
		} catch (ClassNotFoundException e2) {
			e2.printStackTrace();
		} catch (SQLException e3) {
			e3.printStackTrace();
		}
		
		//System.out.println("Initializing.");
		return conn;
	}
	
	private String selectPath(String handle) {
		String sql = "SELECT * FROM PATH WHERE handle = \'" + handle + "\'";
		String result = "";
		try {
			conn = initSQL("jdbc:mysql://","SEMANTICS");
			stmt = conn.createStatement();
			ResultSet rs = stmt.executeQuery(sql);
			if(rs.next()) {
				result = rs.getString("path"); 
			}
		} catch(SQLException e) {
			e.printStackTrace();
		} finally {
			try {
				if(stmt!=null) {
		            stmt.close();
				}
				if (null != conn) {
					closeSQL(conn);
				}
			} catch(SQLException e) {
				e.printStackTrace();
			}
			
			//System.out.println("Database created.");
		}
		return result;
	}
	
	private void closeSQL(Connection connection)
	{// close sql connection
		try {
			if (!connection.isClosed()) {
				connection.close();
			}
		} catch (SQLException e) {
			e.printStackTrace();
		}
	}
}
