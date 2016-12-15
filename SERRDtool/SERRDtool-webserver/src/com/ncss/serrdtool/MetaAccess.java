package com.ncss.serrdtool;
/*
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectOutputStream;
*/

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.concurrent.ThreadLocalRandom;

import jess.JessException;
import jess.Rete;

public class MetaAccess {
	//private static final int handleLength = 15;
	private static final int DSLength = 8;
	
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
		public String CF;
		
		public Query(String metric, String DSName, String CF, String unitName, String unit, String entityType, String entity, long start, long end, int rows, int step) {
			metricName = metric;
			this.DSName = DSName;
			this.CF = CF;
			this.unitName = unitName;
			this.unit = unit;
			this.entityType = entityType;
			this.entity = entity;
			this.startTime = start;
			this.endTime = end;
			this.rows = rows;
			this.step = step;
		}
	}
	
	static String path = System.getProperty("catalina.home") + "/webapps/SERRDtool/WEB-INF/";
	static String outFile = path + "reasoning/out/output.txt";
	private Connection conn;
	private Statement stmt;
	
	// ****** method for access *****
	public Meta getQuery(String metricName, String DSName, String CF, String unitName, String unit, String entityType, String entity, String startTime, String endTime, String rows, String step) {
		// query processing for create function in rredtool
		long a_st, a_et;
		int a_rows, a_step;
		if(!startTime.equals("nil")) {
			a_st = Long.valueOf(startTime);
		}
		else {
			a_st = 0;
		}
		if(!endTime.equals("nil")) {
			a_et = Long.valueOf(endTime);
		}
		else {
			a_et = 0;
		}
		if(!rows.equals("nil")) {
			a_rows = Integer.valueOf(rows);
		}
		else {
			a_rows = 0;
		}
		if(!step.equals("nil")) {
			a_step = Integer.valueOf(step);
		}
		else {
			a_step = 0;
		}
		
		Query query = new Query(metricName, DSName, CF, unitName, unit, entityType, entity, a_st, a_et, a_rows, a_step);
		Meta m = selectMeta(query);
		if(m != null) {
			//runReasoner(query);
			System.out.println("Meta found!");
			return m;
		}
		else {
			System.out.println("Meta to be generated!");
			runReasoner(query);
			m = parseQuery(query);
			add2DB(m);
			m.printMeta();
		}
		
		
		
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
				m.setHandle(rs.getInt("handle"));
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
		String file = path + "reasoning/input/query.clp";
		
		try {
			BufferedWriter w = new BufferedWriter(new FileWriter(file));
			
			w.write("(assert\n");
			w.write("  (query\n");
			
			if(!query.metricName.equals("nil")) w.write("    (metricName " + query.metricName + ")\n");
			if(!query.unitName.equals("nil"))w.write("    (unitName " + query.unitName + ")\n");
			if(!query.unit.equals("nil"))w.write("    (unit " + query.unit + ")\n");
			if(!query.entityType.equals("nil"))w.write("    (entityType " + query.entityType + ")\n");
			if(!query.entity.equals("nil"))w.write("    (entity " + query.entity + ")\n");
			if(query.startTime != 0)w.write("    (startTime " + query.startTime + ")\n");
			if(query.endTime != 0)w.write("    (endTime " + query.endTime + ")\n");
			if(query.rows != 0)w.write("    (rows " + query.rows + ")\n");
			if(query.step != 0)w.write("    (step " + query.step + ")\n");
			
			if(!query.DSName.equals("nil"))w.write("    (DSName " + query.DSName + ")\n");
			if(!query.CF.equals("nil"))w.write("    (CF " + query.CF + ")\n");
			
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
	
	private void add2DB(Meta m) {
		String sql = "INSERT INTO META (handle,path,metricName,DSName,CF,quantitativeDefinition,unitName,unit,entityType,entity,startTime,endTime,rows,step) " +
                "VALUES ("
                + m.handle + ","
                + " '" + m.path + "',"
                + " '" + m.metricName + "',"
                + " '" + m.DSName + "',"
                + " '" + m.CF + "',"
                + " '" + m.quantitativeDefinition + "',"
                + " '" + m.unitName + "',"
                + " '" + m.unit + "',"
                + " '" + m.entityType + "',"
                + " '" + m.entity + "',"
                + m.startTime + ","
                + m.endTime + ","
                + m.rows + ","
                + m.step
                + ") ON DUPLICATE KEY UPDATE metricName="
                + "'" + m.metricName + "'";
		try {
			//System.out.println(sql);
			conn = initSQL("jdbc:mysql://","SEMANTICS") ;
			stmt = conn.createStatement();
			int count = stmt.executeUpdate(sql);
			if(count == 0) {
				System.out.println("Meta not incerted!");
			}
					
		} catch (SQLException e){
			e.printStackTrace();
		} finally {
			try{
				if(stmt != null) {
		            stmt.close();
				}
				if (conn != null) {
					closeSQL(conn);
				}
			} catch (SQLException e1) {
				e1.printStackTrace();
			}
			
			//System.out.println("Instances inserted.");
		}
	}
	
	private Meta parseQuery(Query query) {
		// parse the reasoning result for query
		String file = outFile;
		String line, metricName = "", unitName = "", unit = "", entityType = "", entity = "", quantitativeDefinition = "", DSName = "", CF = "", startTime = "", endTime = "", step = "", rows = "";
		
		try {
			BufferedReader read = new BufferedReader(new FileReader(file));
			
			while((line = read.readLine()) != null) {
				int ind = line.indexOf(':');
				if(ind >= 0) {
					String mark = line.substring(0, ind).trim();
					//System.out.println(mark);
					switch(mark) {
					case "metricName": 
						metricName = line.substring(ind + 1, line.length()).trim();
						break;
					case "unitName":
						unitName = line.substring(ind + 1, line.length()).trim();
						break;
					case "unit":
						unit = line.substring(ind + 1, line.length()).trim();
						break;
					case "entityType":
						entityType = line.substring(ind + 1, line.length()).trim();
						break;
					case "entity":
						entity = line.substring(ind + 1, line.length()).trim();
						break;
					case "quantitativeDefinition":
						quantitativeDefinition = line.substring(ind + 1, line.length()).trim();
						break;
					case "DSName":
						DSName = line.substring(ind + 1, line.length()).trim();
						break;
					case "CF":
						CF = line.substring(ind + 1, line.length()).trim();
						break;
					case "startTime":
						startTime = line.substring(ind + 1, line.length()).trim();
						break;
					case "endTime":
						endTime = line.substring(ind + 1, line.length()).trim();
						break;
					case "step":
						step = line.substring(ind + 1, line.length()).trim();
						break;
					case "rows":
						rows = line.substring(ind + 1, line.length()).trim();
						break;
					default:
						break;
					}
				}
				else {
					// should be a new metric
					metricName = query.metricName;
					DSName = query.DSName;
					CF = query.CF;
					unitName = query.unitName;
					unit = query.unit;
					entityType = query.entityType;
					entity = query.entity;
					startTime = String.valueOf(query.startTime);
					endTime = String.valueOf(query.endTime);
					rows = String.valueOf(query.rows);
					step = String.valueOf(query.step);
					break;
				}
			}
			
			read.close();
		} catch(IOException e) {
			e.printStackTrace();
		}
		
		long a_st, a_et;
		int a_rows, a_step;
		if(!startTime.equals("nil")) {
			a_st = Long.valueOf(startTime);
		}
		else {
			a_st = 0;
		}
		if(!endTime.equals("nil")) {
			a_et = Long.valueOf(endTime);
		}
		else {
			a_et = 0;
		}
		if(!rows.equals("nil")) {
			a_rows = Integer.valueOf(rows);
		}
		else {
			a_rows = 0;
		}
		if(!step.equals("nil")) {
			a_step = Integer.valueOf(step);
		}
		else {
			a_step = 0;
		}
		
		return new Meta(generateHandle(), "", DSName, CF, quantitativeDefinition, metricName, unitName, unit, entityType, entity, a_st, a_et, a_rows, a_step);
	}
	
	private int generateHandle() {
		int res;
		while(true) {
			
			res =  ThreadLocalRandom.current().nextInt(0, Integer.MAX_VALUE);
			
			
			String sql = "SELECT * FROM META WHERE handle = \'" + String.valueOf(res) + "\'";

			try {
				conn = initSQL("jdbc:mysql://","SEMANTICS");
				stmt = conn.createStatement();
				ResultSet rs = stmt.executeQuery(sql);
				if(rs.next()) {
					continue;
				}
				else {
					break;
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
		}
		
		
		return res;
		
	}
/*	
	private String generateHandle() {
		char[] seq = new char[handleLength];
		
		String res;
		
		while(true) {
			
			for(int i = 0; i < seq.length; ++i) {
				seq[i] = (char) ('a' + ThreadLocalRandom.current().nextInt(0, 26));
			}
			
			res = new String(seq);
			
			String sql = "SELECT * FROM META WHERE handle = \'" + res + "\'";

			try {
				conn = initSQL("jdbc:mysql://","SEMANTICS");
				stmt = conn.createStatement();
				ResultSet rs = stmt.executeQuery(sql);
				if(rs.next()) {
					continue;
				}
				else {
					break;
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
		}
		
		
		return res;
	}
*/	
	private String generateDS() {
		char[] seq = new char[DSLength];
		
		for(int i = 0; i < seq.length; ++i) {
			seq[i] = (char) ('a' + ThreadLocalRandom.current().nextInt(0, 26));
		}
		
		return new String(seq);
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
